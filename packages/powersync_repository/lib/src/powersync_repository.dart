import 'dart:async';
import 'package:env/env.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:postgrest/postgrest.dart';
import 'package:powersync/powersync.dart';
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

/// Self-hosted PostgREST (in front of Azure Postgres), served over HTTPS by
/// Azure Container Apps. Replaces Supabase's auto REST API: reads come from
/// PowerSync, writes and RPCs go here, authorised with the Entra id token.
// TODO(treepnet): move to env alongside the other endpoints.
const _postgrestUrl =
    'https://treepnet-postgrest-https.delightfulpebble-1e3b7a49.polandcentral.azurecontainerapps.io';

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

    // Upload writes to the self-hosted PostgREST (Azure). The Entra id token
    // authorises the request; PostgREST validates it against Entra's JWKS.
    final tokens = EntraSession.instance.current;
    final rest = PostgrestClient(
      _postgrestUrl,
      headers: {
        if (tokens != null) 'Authorization': 'Bearer ${tokens.idToken}',
      },
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
        /// Note that these errors typically indicate a bug in the application.
        /// If protecting against data loss is important, save the failing
        /// records
        /// elsewhere instead of discarding, and/or notify the user.
        shared.logE('Data upload error - discarding $lastOp', error: e);
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
  /// direct writes outside the PowerSync upload path.
  PostgrestClient postgrest() {
    final tokens = EntraSession.instance.current;
    return PostgrestClient(
      _postgrestUrl,
      headers: {
        if (tokens != null) 'Authorization': 'Bearer ${tokens.idToken}',
      },
    );
  }

  /// Opens the local database and connects to PowerSync if the user is
  /// logged in (via the Entra session).
  Future<void> _openDatabase() async {
    _db = PowerSyncDatabase(
      schema: shared.schema,
      path: await getDatabasePath(),
    );
    await _db.initialize();

    SupabaseConnector? currentConnector;

    if (isLoggedIn()) {
      currentConnector = SupabaseConnector(_db, env: env);
      unawaited(
        _db.connect(connector: currentConnector).catchError((Object e) {
          shared.logE('PowerSync startup connection failed', error: e);
        }),
      );
    }

    // Connect/disconnect PowerSync as the Entra session comes and goes.
    EntraSession.instance.changes.listen((tokens) async {
      if (tokens != null) {
        try {
          currentConnector = SupabaseConnector(_db, env: env);
          await _db.connect(connector: currentConnector!);
        } catch (e, stack) {
          shared.logE(
            'PowerSyncRepository connection failed',
            error: e,
            stackTrace: stack,
          );
        }
      } else {
        currentConnector = null;
        await _db.disconnect();
      }
    });
  }
}
