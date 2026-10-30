import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared/shared.dart' as shared;
import 'package:treepnet/monitoring/crash_reporter.dart';

/// Task definition for a pending media upload.
class PendingUploadTask {
  PendingUploadTask({
    required this.id,
    required this.postId,
    required this.localPath,
    required this.remotePath,
    required this.bucket,
    required this.contentType,
    required this.mediaType,
    required this.index,
    required this.blurHash,
    this.firstFrameLocalPath,
    this.firstFrameRemotePath,
    this.createdAt,
    this.attempts = 0,
    this.nextAttemptAt,
  });

  factory PendingUploadTask.fromJson(Map<String, dynamic> json) {
    return PendingUploadTask(
      id: json['id'] as String,
      postId: json['postId'] as String,
      localPath: json['localPath'] as String,
      remotePath: json['remotePath'] as String,
      bucket: json['bucket'] as String,
      contentType: json['contentType'] as String,
      mediaType: json['mediaType'] as String,
      index: json['index'] as int,
      blurHash: json['blurHash'] as String,
      firstFrameLocalPath: json['firstFrameLocalPath'] as String?,
      firstFrameRemotePath: json['firstFrameRemotePath'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      attempts: json['attempts'] as int? ?? 0,
      nextAttemptAt: DateTime.tryParse(json['nextAttemptAt'] as String? ?? ''),
    );
  }

  final String id;
  final String postId;
  final String localPath;
  final String remotePath;
  final String bucket;
  final String contentType;
  final String mediaType;
  final int index;
  final String blurHash;
  final String? firstFrameLocalPath;
  final String? firstFrameRemotePath;

  /// When it was queued. Null for tasks queued by an older app version.
  final DateTime? createdAt;

  /// Failed upload attempts so far.
  final int attempts;

  /// Not retried before this (backoff after a failure).
  final DateTime? nextAttemptAt;

  PendingUploadTask retryLater({required int attempts, required DateTime at}) {
    return PendingUploadTask(
      id: id,
      postId: postId,
      localPath: localPath,
      remotePath: remotePath,
      bucket: bucket,
      contentType: contentType,
      mediaType: mediaType,
      index: index,
      blurHash: blurHash,
      firstFrameLocalPath: firstFrameLocalPath,
      firstFrameRemotePath: firstFrameRemotePath,
      createdAt: createdAt,
      attempts: attempts,
      nextAttemptAt: at,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'localPath': localPath,
      'remotePath': remotePath,
      'bucket': bucket,
      'contentType': contentType,
      'mediaType': mediaType,
      'index': index,
      'blurHash': blurHash,
      'firstFrameLocalPath': firstFrameLocalPath,
      'firstFrameRemotePath': firstFrameRemotePath,
      'createdAt': createdAt?.toIso8601String(),
      'attempts': attempts,
      'nextAttemptAt': nextAttemptAt?.toIso8601String(),
    };
  }
}

/// A post whose media didn't all upload right away.
///
/// It stays on this phone and is created only once every file is uploaded, so
/// nobody ever sees a post pointing at files that exist only on the author's
/// phone. [media] holds the post's media entries; an entry still uploading has
/// an empty `url` (and `null` once its file is lost).
class PendingPost {
  PendingPost({
    required this.postId,
    required this.userId,
    required this.caption,
    required this.media,
    this.location,
    this.locationCountry,
    this.locationRegion,
    this.locationName,
    this.locationLat,
    this.locationLng,
  });

  factory PendingPost.fromJson(Map<String, dynamic> json) {
    return PendingPost(
      postId: json['postId'] as String,
      userId: json['userId'] as String,
      caption: json['caption'] as String,
      media: List<Map<String, dynamic>>.from(
        (json['media'] as List<dynamic>).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      ),
      location: json['location'] as String?,
      locationCountry: json['locationCountry'] as String?,
      locationRegion: json['locationRegion'] as String?,
      locationName: json['locationName'] as String?,
      locationLat: (json['locationLat'] as num?)?.toDouble(),
      locationLng: (json['locationLng'] as num?)?.toDouble(),
    );
  }

  final String postId;

  /// Who wrote it: it is only ever created while this account is signed in.
  final String userId;
  final String caption;
  final List<Map<String, dynamic>> media;
  final String? location;
  final String? locationCountry;
  final String? locationRegion;
  final String? locationName;
  final double? locationLat;
  final double? locationLng;

  PendingPost withMedia(List<Map<String, dynamic>> media) {
    return PendingPost(
      postId: postId,
      userId: userId,
      caption: caption,
      media: media,
      location: location,
      locationCountry: locationCountry,
      locationRegion: locationRegion,
      locationName: locationName,
      locationLat: locationLat,
      locationLng: locationLng,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'userId': userId,
      'caption': caption,
      'media': media,
      'location': location,
      'locationCountry': locationCountry,
      'locationRegion': locationRegion,
      'locationName': locationName,
      'locationLat': locationLat,
      'locationLng': locationLng,
    };
  }
}

/// A queued upload that keeps failing — reported once, so we hear about it.
/// No content: just which task, what kind of media and the error type.
class _MediaUploadStuck implements Exception {
  _MediaUploadStuck(this.task, this.error);

  final PendingUploadTask task;
  final Object error;

  @override
  String toString() =>
      'Media upload failed ${task.attempts} times '
      '(${task.mediaType} ${task.contentType}, task ${task.id}): '
      '${error.runtimeType}: $error';
}

/// A service that manages the persistent queue of pending media uploads
/// for offline-first capabilities.
///
/// Each task is tried on its own: one failing file no longer stops the queue.
/// A failure backs off (30 s, doubling, up to an hour) instead of re-uploading
/// on every reconnect, and is reported once it has failed
/// [_reportAfterAttempts] times. A task whose post is gone is cancelled.
///
/// A post whose media didn't all upload right away is queued as a
/// [PendingPost] and created by the post creator the app attaches
/// ([attachPostCreator]) once its last file is uploaded.
class MediaUploadQueue {
  MediaUploadQueue({
    required PowerSyncDatabase db,
    required SharedPreferences sharedPreferences,
  })  : _db = db,
        _prefs = sharedPreferences;

  static const String _storageKey = 'treepnet_pending_uploads_queue';
  static const String _postsKey = 'treepnet_pending_posts';

  /// Backoff after the first failure; doubles each time, up to [_maxBackoff].
  static const Duration _firstBackoff = Duration(seconds: 30);
  static const Duration _maxBackoff = Duration(hours: 1);
  static const int _reportAfterAttempts = 5;

  /// The post is created only after all its media are uploaded or queued, so a
  /// fresh task may run before its post exists. Within this window a missing
  /// post means "not yet"; after it, the post was deleted (or never made).
  static const Duration _postGrace = Duration(minutes: 10);

  final PowerSyncDatabase _db;
  final SharedPreferences _prefs;

  /// Creates a ready [PendingPost]; returns false when it can't yet (e.g.
  /// another account is signed in). Null until the app attaches one.
  Future<bool> Function(PendingPost post)? _postCreator;

  bool _isProcessing = false;

  /// A trigger arrived mid-cycle (e.g. a new task): run once more after it.
  bool _rerun = false;
  Timer? _retryTimer;
  StreamSubscription<SyncStatus>? _syncStatusSubscription;

  /// Starts the upload queue worker and registers network status change listeners.
  void start() {
    shared.logI('MediaUploadQueue: Starting background worker...');

    // Listen to PowerSync connection status changes.
    // When we transition to connected, trigger queue processing.
    _syncStatusSubscription = _db.statusStream.listen((status) {
      if (status.connected) {
        shared.logI('MediaUploadQueue: Database status changed to CONNECTED. Processing queue...');
        triggerProcessing();
      }
    });

    // Run initial processing trigger on startup.
    triggerProcessing();
  }

  /// Disposes resources.
  void dispose() {
    _syncStatusSubscription?.cancel();
    _retryTimer?.cancel();
  }

  /// Lets the queue create posts once their media are uploaded. Posts that
  /// became ready while no creator was attached are created now.
  void attachPostCreator(Future<bool> Function(PendingPost post) creator) {
    _postCreator = creator;
    triggerProcessing();
  }

  void detachPostCreator() => _postCreator = null;

  /// Queues [post] to be created once its media (queued with [enqueueTask])
  /// are all uploaded.
  Future<void> enqueuePost(PendingPost post) async {
    await _saveDraft(post);
    // Its tasks may have been put off while the post wasn't queued yet.
    final now = DateTime.now();
    for (final task in _loadTasks()) {
      if (task.postId == post.postId && task.attempts == 0) {
        await _saveTask(task.retryLater(attempts: 0, at: now));
      }
    }
    triggerProcessing();
  }

  /// Saves a media file to the local pending directory and registers a task.
  Future<String> enqueueTask({
    required String postId,
    required Uint8List bytes,
    required String remotePath,
    required String bucket,
    required String contentType,
    required String mediaType,
    required int index,
    required String blurHash,
    Uint8List? firstFrameBytes,
    String? firstFrameRemotePath,
  }) async {
    final docDir = await getApplicationDocumentsDirectory();
    final queueDir = Directory(p.join(docDir.path, 'pending_uploads', postId));
    if (!queueDir.existsSync()) {
      queueDir.createSync(recursive: true);
    }

    final taskId = '${postId}_$index';
    final extension = contentType.split('/').last;
    final localFile = File(p.join(queueDir.path, 'media_$index.$extension'));
    await localFile.writeAsBytes(bytes);

    String? firstFrameLocalPath;
    if (firstFrameBytes != null && firstFrameRemotePath != null) {
      final firstFrameFile = File(p.join(queueDir.path, 'first_frame_$index.jpg'));
      await firstFrameFile.writeAsBytes(firstFrameBytes);
      firstFrameLocalPath = firstFrameFile.path;
    }

    final task = PendingUploadTask(
      id: taskId,
      postId: postId,
      localPath: localFile.path,
      remotePath: remotePath,
      bucket: bucket,
      contentType: contentType,
      mediaType: mediaType,
      index: index,
      blurHash: blurHash,
      firstFrameLocalPath: firstFrameLocalPath,
      firstFrameRemotePath: firstFrameRemotePath,
      createdAt: DateTime.now(),
    );

    await _saveTask(task);
    shared.logI('MediaUploadQueue: Enqueued task $taskId for post $postId.');

    // Attempt processing immediately if online.
    triggerProcessing();

    return localFile.path;
  }

  /// Triggers the queue processing cycle asynchronously.
  void triggerProcessing() {
    if (_isProcessing) {
      _rerun = true;
      return;
    }
    _isProcessing = true;
    _processQueue()
        .catchError((Object e, StackTrace s) {
          shared.logE(
            'MediaUploadQueue: Error processing queue',
            error: e,
            stackTrace: s,
          );
        })
        .whenComplete(() {
          _isProcessing = false;
          if (_rerun) {
            _rerun = false;
            triggerProcessing();
          }
        });
  }

  Future<void> _processQueue() async {
    await _uploadDueTasks();
    await _createReadyPosts();
  }

  Future<void> _uploadDueTasks() async {
    final tasks = _loadTasks();
    if (tasks.isEmpty) return;

    shared.logI('MediaUploadQueue: Found ${tasks.length} pending upload tasks.');

    // Verify online connectivity before starting.
    final isOnline = _db.currentStatus.connected;
    if (!isOnline) {
      shared.logW('MediaUploadQueue: PowerSync is not connected. Skipping upload cycle.');
      return;
    }

    // Every due task gets its own try: one failing file no longer blocks the
    // ones queued after it.
    final now = DateTime.now();
    for (final task in tasks) {
      final due = task.nextAttemptAt;
      if (due != null && due.isAfter(now)) continue;
      try {
        await _processTask(task);
      } catch (error, stackTrace) {
        await _recordFailure(task, error, stackTrace);
      }
    }
    _scheduleRetry();
  }

  /// Creates every queued post whose media are all uploaded. A post that
  /// can't be created now stays queued for the next cycle.
  Future<void> _createReadyPosts() async {
    final creator = _postCreator;
    if (creator == null) return;
    final uploading = _loadTasks().map((t) => t.postId).toSet();
    for (final draft in _loadDrafts().values) {
      if (uploading.contains(draft.postId)) continue;

      // Already created (e.g. the app stopped right after creating it).
      final exists =
          await _db.getOptional(
            'SELECT id FROM posts WHERE id = ?',
            [draft.postId],
          ) !=
          null;
      if (exists) {
        await _removeDraft(draft.postId);
        continue;
      }

      final media = draft.media
          .where((m) => (m['url'] as String?)?.isNotEmpty ?? false)
          .toList();
      if (media.isEmpty) {
        shared.logW(
          'MediaUploadQueue: Post ${draft.postId} lost all its media. '
          'Dropping it.',
        );
        await _removeDraft(draft.postId);
        continue;
      }

      try {
        if (await creator(draft.withMedia(media))) {
          await _removeDraft(draft.postId);
          shared.logI('MediaUploadQueue: Created queued post ${draft.postId}.');
        }
      } catch (error, stackTrace) {
        shared.logE(
          'MediaUploadQueue: Creating queued post ${draft.postId} failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Backs the task off (30 s, doubling, up to an hour) and reports it once it
  /// has failed [_reportAfterAttempts] times.
  Future<void> _recordFailure(
    PendingUploadTask task,
    Object error,
    StackTrace stackTrace,
  ) async {
    final attempts = task.attempts + 1;
    final backoff = Duration(
      milliseconds: math.min(
        _firstBackoff.inMilliseconds * math.pow(2, attempts - 1),
        _maxBackoff.inMilliseconds.toDouble(),
      ).round(),
    );
    final updated = task.retryLater(
      attempts: attempts,
      at: DateTime.now().add(backoff),
    );
    await _saveTask(updated);
    shared.logE(
      'MediaUploadQueue: Task ${task.id} failed (attempt $attempts); '
      'retrying in ${backoff.inSeconds}s.',
      error: error,
      stackTrace: stackTrace,
    );
    if (attempts == _reportAfterAttempts) {
      CrashReporter.instance.report(
        _MediaUploadStuck(updated, error),
        stackTrace,
        kind: 'media-upload',
      );
    }
  }

  /// Wakes the queue when the next backed-off task is due, so a retry doesn't
  /// have to wait for the next reconnect.
  void _scheduleRetry() {
    _retryTimer?.cancel();
    final pending = _loadTasks()
        .map((t) => t.nextAttemptAt)
        .whereType<DateTime>()
        .toList();
    if (pending.isEmpty) return;
    final next = pending.reduce((a, b) => a.isBefore(b) ? a : b);
    final wait = next.difference(DateTime.now());
    _retryTimer = Timer(
      wait.isNegative ? Duration.zero : wait,
      triggerProcessing,
    );
  }

  Future<void> _processTask(PendingUploadTask task) async {
    final mediaFile = File(task.localPath);
    if (!mediaFile.existsSync()) {
      shared.logW('MediaUploadQueue: Local file does not exist for task ${task.id}. Removing from queue.');
      await _setDraftMedia(task.postId, task.index, url: null);
      await _removeTask(task.id);
      return;
    }

    // A queued post doesn't exist yet by design; otherwise check the post
    // first, so a deleted post's media isn't uploaded (again).
    final queuedPost = _loadDrafts().containsKey(task.postId);
    final postExists = queuedPost ||
        await _db.getOptional(
              'SELECT id FROM posts WHERE id = ?',
              [task.postId],
            ) !=
            null;
    if (!postExists) {
      final createdAt = task.createdAt;
      final fresh = createdAt != null &&
          DateTime.now().difference(createdAt) < _postGrace;
      if (fresh) {
        // Its post is created right after the media; not a failure.
        await _saveTask(
          task.retryLater(
            attempts: task.attempts,
            at: DateTime.now().add(_firstBackoff),
          ),
        );
        return;
      }
      shared.logW('MediaUploadQueue: Post ${task.postId} is gone. Cancelling task ${task.id}.');
      _deleteLocalFiles(task);
      await _removeTask(task.id);
      return;
    }

    final storage = shared.MediaStorage.instance.from(task.bucket);
    final bytes = await mediaFile.readAsBytes();

    shared.logI('MediaUploadQueue: Uploading media for task ${task.id}...');
    await storage.uploadBinary(
      task.remotePath,
      bytes,
      fileOptions: shared.MediaFileOptions(
        contentType: task.contentType,
        cacheControl: '9000000',
      ),
    );
    final mediaUrl = storage.getPublicUrl(task.remotePath);

    String? firstFrameUrl;
    if (task.firstFrameLocalPath != null && task.firstFrameRemotePath != null) {
      final firstFrameFile = File(task.firstFrameLocalPath!);
      if (firstFrameFile.existsSync()) {
        shared.logI('MediaUploadQueue: Uploading first frame for task ${task.id}...');
        final firstFrameBytes = await firstFrameFile.readAsBytes();
        await storage.uploadBinary(
          task.firstFrameRemotePath!,
          firstFrameBytes,
          fileOptions: const shared.MediaFileOptions(
            contentType: 'image/jpeg',
            cacheControl: '9000000',
          ),
        );
        firstFrameUrl = storage.getPublicUrl(task.firstFrameRemotePath!);
      }
    }

    // Point the queued post (or, for a post an older version already created,
    // its database row) at the uploaded file.
    if (queuedPost) {
      await _setDraftMedia(
        task.postId,
        task.index,
        url: mediaUrl,
        firstFrameUrl: firstFrameUrl,
      );
    } else {
      await _updateDatabaseRecord(
        postId: task.postId,
        index: task.index,
        remoteUrl: mediaUrl,
        remoteFirstFrameUrl: firstFrameUrl,
      );
    }

    _deleteLocalFiles(task);
    await _removeTask(task.id);
    shared.logI('MediaUploadQueue: Task ${task.id} completed successfully.');
  }

  /// Removes the task's queued files, and its post folder once empty.
  void _deleteLocalFiles(PendingUploadTask task) {
    try {
      final mediaFile = File(task.localPath);
      if (mediaFile.existsSync()) mediaFile.deleteSync();
      if (task.firstFrameLocalPath != null) {
        final f = File(task.firstFrameLocalPath!);
        if (f.existsSync()) f.deleteSync();
      }

      // Try to delete parent dir if empty.
      final parentDir = mediaFile.parent;
      if (parentDir.existsSync() && parentDir.listSync().isEmpty) {
        parentDir.deleteSync();
      }
    } catch (e) {
      shared.logW('MediaUploadQueue: Minor error clearing local files: $e');
    }
  }

  Future<void> _updateDatabaseRecord({
    required String postId,
    required int index,
    required String remoteUrl,
    String? remoteFirstFrameUrl,
  }) async {
    // Read the current post row from SQLite. (`get` throws when the row is
    // missing, which used to fail — and retry — the task forever.)
    final result = await _db.getOptional(
      'SELECT * FROM posts WHERE id = ?',
      [postId],
    );
    if (result == null) {
      shared.logW('MediaUploadQueue: Target post $postId not found in database.');
      return;
    }

    final post = Map<String, dynamic>.from(result);
    final mediaJson = post['media'] as String?;
    if (mediaJson == null) return;

    final mediaList = List<Map<String, dynamic>>.from(
      (json.decode(mediaJson) as List<dynamic>).map((e) => e as Map<String, dynamic>),
    );

    if (index >= 0 && index < mediaList.length) {
      mediaList[index]['url'] = remoteUrl;
      if (remoteFirstFrameUrl != null) {
        mediaList[index]['first_frame_url'] = remoteFirstFrameUrl;
      }

      await _db.execute(
        'UPDATE posts SET media = ? WHERE id = ?',
        [json.encode(mediaList), postId],
      );
      shared.logI('MediaUploadQueue: Updated database row for post $postId index $index.');
    }
  }

  /// Sets media entry [index] of queued post [postId]; a null [url] marks the
  /// file as lost. No-op when the post isn't queued.
  Future<void> _setDraftMedia(
    String postId,
    int index, {
    required String? url,
    String? firstFrameUrl,
  }) async {
    final draft = _loadDrafts()[postId];
    if (draft == null || index < 0 || index >= draft.media.length) return;
    final media = [for (final m in draft.media) Map<String, dynamic>.from(m)];
    media[index]['url'] = url;
    if (firstFrameUrl != null) media[index]['first_frame_url'] = firstFrameUrl;
    await _saveDraft(draft.withMedia(media));
  }

  Map<String, PendingPost> _loadDrafts() {
    final raw = _prefs.getStringList(_postsKey) ?? [];
    final drafts = raw.map(
      (e) => PendingPost.fromJson(json.decode(e) as Map<String, dynamic>),
    );
    return {for (final d in drafts) d.postId: d};
  }

  Future<void> _saveDraft(PendingPost draft) async {
    final drafts = _loadDrafts()..[draft.postId] = draft;
    await _prefs.setStringList(
      _postsKey,
      drafts.values.map((d) => json.encode(d.toJson())).toList(),
    );
  }

  Future<void> _removeDraft(String postId) async {
    final drafts = _loadDrafts()..remove(postId);
    await _prefs.setStringList(
      _postsKey,
      drafts.values.map((d) => json.encode(d.toJson())).toList(),
    );
  }

  List<PendingUploadTask> _loadTasks() {
    final raw = _prefs.getStringList(_storageKey) ?? [];
    return raw
        .map((e) => PendingUploadTask.fromJson(json.decode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveTask(PendingUploadTask task) async {
    final tasks = _loadTasks();
    tasks.removeWhere((t) => t.id == task.id);
    tasks.add(task);
    final list = tasks.map((e) => json.encode(e.toJson())).toList();
    await _prefs.setStringList(_storageKey, list);
  }

  Future<void> _removeTask(String taskId) async {
    final tasks = _loadTasks();
    tasks.removeWhere((t) => t.id == taskId);
    final list = tasks.map((e) => json.encode(e.toJson())).toList();
    await _prefs.setStringList(_storageKey, list);
  }
}
