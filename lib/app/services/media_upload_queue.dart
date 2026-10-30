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
class MediaUploadQueue {
  MediaUploadQueue({
    required PowerSyncDatabase db,
    required SharedPreferences sharedPreferences,
  })  : _db = db,
        _prefs = sharedPreferences;

  static const String _storageKey = 'treepnet_pending_uploads_queue';

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
      await _removeTask(task.id);
      return;
    }

    // Check the post first, so a deleted post's media isn't uploaded (again).
    final postExists = await _db.getOptional(
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

    // Update the database record with the remote public URLs.
    await _updateDatabaseRecord(
      postId: task.postId,
      index: task.index,
      remoteUrl: mediaUrl,
      remoteFirstFrameUrl: firstFrameUrl,
    );

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
