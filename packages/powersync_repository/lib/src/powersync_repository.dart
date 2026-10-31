import 'dart:async';
import 'dart:io';
import 'package:env/env.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:postgrest/postgrest.dart';
import 'package:powersync/powersync.dart';
import 'package:powersync_repository/src/fresh_token_client.dart';
import 'package:powersync_repository/src/sync_scope.dart';
import 'package:shared/shared.dart' as shared;
import 'package:token_storage/token_storage.dart';

/// Env value signature that can be used to get an environment value, base
/// on provided [Env].
typedef EnvValue = String Function(Env env);

/// Postgres Response codes that we cannot recover from by retrying.
final List<RegExp> fatalResponseCodes = [
  // Class 22 — Data Exception
  // Examples include data type mismatch.
  RegExp(r'^22...$'),
  // Class 23 — Integrity Constraint Violation.
  // Examples include NOT NULL, FOREIGN KEY and UNIQUE violations.
  RegExp(r'^23...$'),
  // INSUFFICIENT PRIVILEGE - typically a row-level security violation
  RegExp(r'^42501$'),
];

/// A local change the server refused for good (see [fatalResponseCodes]). It is
/// dropped — retrying can't make it succeed — so the app is told, to report it
/// and tell the user. Carries no row content: only where it was and why.
class RejectedUpload {
  /// Creates a [RejectedUpload].
  const RejectedUpload({
    required this.table,
    required this.op,
    required this.code,
    required this.message,
    required this.dropped,
  });

  /// The table the refused change was for.
  final String table;

  /// `put`, `patch` or `delete`.
  final String op;

  /// The Postgres error code, e.g. `23505` or `42501`.
  final String code;

  /// The server's message, with any quoted values removed.
  final String message;

  /// How many local changes were dropped with it (its whole transaction).
  final int dropped;

  @override
  String toString() =>
      'Server rejected a synced change: $op on $table ($code: $message); '
      '$dropped change(s) dropped';
}

final _rejectedUploads = StreamController<RejectedUpload>.broadcast();

/// Postgres messages can quote the offending value. Keep identifiers
/// (constraint, column and type names) and drop anything else in quotes, so a
/// report never carries user content.
String _withoutValues(String message) => message.replaceAllMapped(
  RegExp('"([^"]*)"'),
  (m) => RegExp(r'^[a-z_][a-z0-9_.]*$').hasMatch(m[1]!) ? m[0]! : '"…"',
);

/// Self-hosted PostgREST, served over HTTPS by Caddy on the OCI ARM server.
/// Replaces Supabase's auto REST API: reads come from PowerSync, writes and
/// RPCs go here, authorised with the Entra id token. (Old app versions still
/// point at the Azure Container Apps URL; this is the Oracle stack.)
// TODO(treepnet): move to env alongside the other endpoints.
const _postgrestUrl = 'https://api.treepnet.com';

class SupabaseConnector extends PowerSyncBackendConnector {
  /// {@macro supabase_connector}
  SupabaseConnector(this.db, {required this.env});

  /// PowerSync main database.
  final PowerSyncDatabase db;

  /// Environment values.
  final EnvValue env;

  Future<void>? _refreshFuture;

  /// Get an Entra id token to authenticate against the PowerSync instance.
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // Wait for a pending token refresh, if any.
    await _refreshFuture;

    var tokens = EntraSession.instance.current;
    if (tokens == null) {
      // Not logged in.
      return null;
    }

    // Refresh proactively if the id token is expired/near expiry.
    if (!tokens.isIdTokenValid) {
      await EntraSession.instance.refresh();
      tokens = EntraSession.instance.current;
      if (tokens == null) return null;
    }
    // The app opened before it had a token (offline) and none came yet:
    // PowerSync tries again shortly, and so fetches it once the connection is
    // back.
    if (tokens.idToken.isEmpty) throw StateError('No ID token yet');

    // The id token (aud == client id) is validated by PowerSync against
    // Entra's JWKS.
    return PowerSyncCredentials(
      endpoint: env(Env.powerSyncUrl),
      token: tokens.idToken,
      userId: tokens.userId,
      expiresAt: tokens.idTokenExpiry,
    );
  }

  @override
  void invalidateCredentials() {
    // Trigger a silent token refresh when PowerSync reports an auth failure.
    // Timeout to avoid blocking on long retries; errors surface as expired
    // tokens on the next fetch.
    _refreshFuture = EntraSession.instance
        .refresh()
        .timeout(5.seconds)
        .then((_) => null, onError: (Object _) => null);
  }

  // Upload pending changes to Supabase.
  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    // This function is called whenever there is data to upload, whether the
    // device is online or offline.
    // If this call throws an error, it is retried periodically.
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) {
      return;
    }

    // Upload writes to the self-hosted PostgREST. The Firebase ID token
    // authorises the request, fetched first if it expired or the app opened
    // before it had one. Without a token the upload is retried later: sent
    // unauthenticated, the server would refuse it as a row-level-security
    // violation and the changes would be dropped.
    final token = await EntraSession.instance.idToken();
    if (token == null) throw StateError('No ID token yet');
    final rest = PostgrestClient(
      _postgrestUrl,
      headers: {'Authorization': 'Bearer $token'},
    );
    CrudEntry? lastOp;
    try {
      // Note: If transactional consistency is important, use database functions
      // or edge functions to process the entire transaction in a single call.
      for (final op in transaction.crud) {
        lastOp = op;

        final table = rest.from(op.table);
        if (op.op == UpdateType.put) {
          final data = Map<String, dynamic>.of(op.opData!);
          data['id'] = op.id;
          await table.upsert(data);
        } else if (op.op == UpdateType.patch) {
          await table.update(op.opData!).eq('id', op.id);
        } else if (op.op == UpdateType.delete) {
          await table.delete().eq('id', op.id);
        }
      }

      // All operations successful.
      await transaction.complete();
    } on PostgrestException catch (e) {
      if (e.code != null &&
          fatalResponseCodes.any((re) => re.hasMatch(e.code!))) {
        /// Instead of blocking the queue with these errors,
        /// discard the (rest of the) transaction.
        ///
        /// These errors typically indicate a bug in the application, so the
        /// app is told ([PowerSyncRepository.rejectedUploads]): it reports
        /// the drop and tells the user, instead of the change silently
        /// vanishing on the next sync.
        shared.logE('Data upload error - discarding $lastOp', error: e);
        _rejectedUploads.add(
          RejectedUpload(
            table: lastOp?.table ?? '?',
            op: lastOp?.op.name ?? '?',
            code: e.code ?? '?',
            message: _withoutValues(e.message),
            dropped: transaction.crud.length,
          ),
        );
        await transaction.complete();
      } else {
        /// Error may be retryable - e.g. network error or temporary server
        /// error. Throwing an error here causes this call to be retried after
        /// a delay.
        rethrow;
      }
    }
  }
}

/// {@template power_sync_repository}
/// A package that manages connection to the PowerSync cloud service and
/// database.
///
/// The [PowerSyncRepository] class is responsible for managing the local
/// database and interacting with the Supabase client.
/// {@endtemplate}
class PowerSyncRepository {
  /// Initializes a new instance of the [PowerSyncRepository] class.
  PowerSyncRepository({required this.env});

  /// Environment values.
  final EnvValue env;

  bool _isInitialized = false;

  late final PowerSyncDatabase _db;

  /// Initializes the local database and opens a new instance of the database.
  Future<void> initialize({bool offlineMode = false}) async {
    if (!_isInitialized) {
      await _openDatabase();
      _isInitialized = true;
    }
  }

  /// Returns the PowerSync database instance.
  PowerSyncDatabase db() {
    if (!_isInitialized) {
      throw Exception(
        'PowerSyncDatabase not initialized. Call initialize() first.',
      );
    }
    return _db;
  }

  /// Local changes the server refused for good and that were dropped — one
  /// event per dropped transaction. See [RejectedUpload].
  Stream<RejectedUpload> get rejectedUploads => _rejectedUploads.stream;

  /// Keeps [userId]'s profile on the phone while it is open: their card and
  /// counts, and — if the account is public — their posts, stories,
  /// highlights and map. Someone the user follows already syncs.
  SyncScope profileScope(String userId) => SyncScope.open(
    db(),
    [
      ('profile', {'user_id': userId}),
      ('profile_card', {'user_id': userId}),
    ],
    ttl: const Duration(hours: 1),
  );

  /// Keeps a post, its counts and its comments on the phone while they are
  /// open. [ownerId] is the post's author; the server only matches it if it
  /// really is, and only for a post the user may see.
  SyncScope postScope({required String postId, required String ownerId}) =>
      SyncScope.open(
        db(),
        [
          ('post', {'post_id': postId, 'owner_id': ownerId}),
        ],
        ttl: const Duration(minutes: 30),
      );

  /// How many local changes haven't been uploaded to the server yet. Signing
  /// out wipes them along with the local database.
  Future<int> pendingUploads() async =>
      (await db().getUploadQueueStats()).count;

  /// Checks if a user is logged in.
  bool isLoggedIn() {
    return EntraSession.instance.isAuthenticated;
  }

  /// Returns the relative directory of the local database.
  Future<String> getDatabasePath() async {
    final dir = await getApplicationSupportDirectory();
    return join(dir.path, 'flutter-instagram-offline-first.db');
  }

  /// Returns a PostgREST client pointed at the self-hosted PostgREST (Azure),
  /// authorised with the current Entra id token. Used for RPC calls and any
  /// direct writes outside the PowerSync upload path. The token is checked
  /// (and refreshed if needed) per request — see [FreshTokenClient].
  PostgrestClient postgrest() =>
      PostgrestClient(_postgrestUrl, httpClient: _restHttpClient);

  /// One shared client for every [postgrest] call.
  final _restHttpClient = FreshTokenClient();

  /// The sync client written in Rust: the only one that speaks sync streams
  /// (sync-config.yaml), which is what keeps the phone to its own data and
  /// the people it follows. Default from powersync 1.17, which needs a newer
  /// Dart than this app builds with.
  // ignore: experimental_member_use
  static const _syncOptions = SyncOptions(
    syncImplementation: SyncClientImplementation.rust,
  );

  /// Opens the local database and connects to PowerSync if the user is
  /// logged in (via the Entra session).
  Future<void> _openDatabase() async {
    _db = await _openResilient(await getDatabasePath());

    SupabaseConnector? currentConnector;
    // Whose data the sync connection is for; null while signed out.
    String? connectedUserId;

    if (isLoggedIn()) {
      connectedUserId = EntraSession.instance.current?.userId;
      currentConnector = SupabaseConnector(_db, env: env);
      unawaited(
        _db
            .connect(connector: currentConnector, options: _syncOptions)
            .catchError((Object e) {
              shared.logE('PowerSync startup connection failed', error: e);
            }),
      );
    }

    // Connect/disconnect PowerSync as the user signs in and out. A refreshed
    // token for the same user needs nothing: PowerSync asks fetchCredentials
    // for a new one itself before the old one expires. Reconnecting on every
    // session update restarted the sync each hour, on PowerSync's own
    // refreshes, and two or three times at startup.
    EntraSession.instance.changes.listen((tokens) async {
      if (tokens != null) {
        if (tokens.userId == connectedUserId) return;
        connectedUserId = tokens.userId;
        try {
          currentConnector = SupabaseConnector(_db, env: env);
          await _db.connect(
            connector: currentConnector!,
            options: _syncOptions,
          );
        } catch (e, stack) {
          shared.logE(
            'PowerSyncRepository connection failed',
            error: e,
            stackTrace: stack,
          );
        }
      } else {
        connectedUserId = null;
        currentConnector = null;
        await _db.disconnect();
      }
    });
  }

  /// Opens the PowerSync database, recovering from an old on-disk DB the new
  /// build cannot open.
  ///
  /// The database path is stable across releases, so after a store update the
  /// PREVIOUS version's local `.db` is reused. If its on-disk/native format or a
  /// resumed sync checkpoint is incompatible with the new build, `initialize()`
  /// throws — and because boot awaits this unguarded, that would abort startup
  /// and leave the app broken (nothing loads, posts don't open) until the user
  /// manually deletes and reinstalls. Instead, clear the local DB once and
  /// re-open; PowerSync re-downloads everything from the server. This turns the
  /// "delete + reinstall" workaround into an automatic, invisible recovery.
  Future<PowerSyncDatabase> _openResilient(String path) async {
    var db = PowerSyncDatabase(schema: shared.schema, path: path);
    try {
      await db.initialize();
      return db;
    } catch (e, stackTrace) {
      shared.logE(
        'PowerSync open failed; clearing the local DB and retrying once',
        error: e,
        stackTrace: stackTrace,
      );
      try {
        await db.close();
      } catch (_) {
        // The half-open handle may already be unusable; ignore.
      }
      await _deleteDatabaseFiles(path);
      db = PowerSyncDatabase(schema: shared.schema, path: path);
      await db.initialize();
      return db;
    }
  }

  /// Deletes the SQLite database and its sidecar files so a clean one is built.
  Future<void> _deleteDatabaseFiles(String path) async {
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final file = File('$path$suffix');
      try {
        if (file.existsSync()) await file.delete();
      } catch (_) {
        // Best-effort; a locked sidecar shouldn't stop the fresh open.
      }
    }
  }
}
