import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared/shared.dart' as shared;

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
    };
  }
}

/// A service that manages the persistent queue of pending media uploads
/// for offline-first capabilities.
class MediaUploadQueue {
  MediaUploadQueue({
    required PowerSyncDatabase db,
    required SharedPreferences sharedPreferences,
  })  : _db = db,
        _prefs = sharedPreferences;

  static const String _storageKey = 'treepnet_pending_uploads_queue';

  final PowerSyncDatabase _db;
  final SharedPreferences _prefs;
  
  bool _isProcessing = false;
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
    );

    await _saveTask(task);
    shared.logI('MediaUploadQueue: Enqueued task $taskId for post $postId.');
    
    // Attempt processing immediately if online.
    triggerProcessing();
    
    return localFile.path;
  }

  /// Triggers the queue processing cycle asynchronously.
  void triggerProcessing() {
    if (_isProcessing) return;
    _isProcessing = true;
    _processQueue().then((_) {
      _isProcessing = false;
    }).catchError((Object e, StackTrace s) {
      _isProcessing = false;
      shared.logE(
        'MediaUploadQueue: Error processing queue',
        error: e,
        stackTrace: s,
      );
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

    for (final task in List<PendingUploadTask>.from(tasks)) {
      try {
        await _processTask(task);
      } catch (error, stackTrace) {
        shared.logE(
          'MediaUploadQueue: Failed to process task ${task.id}. Will retry later.',
          error: error,
          stackTrace: stackTrace,
        );
        // Break early if we hit an upload error (likely network instability).
        break;
      }
    }
  }

  Future<void> _processTask(PendingUploadTask task) async {
    final mediaFile = File(task.localPath);
    if (!mediaFile.existsSync()) {
      shared.logW('MediaUploadQueue: Local file does not exist for task ${task.id}. Removing from queue.');
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

    // Clean up local files and queue entries.
    try {
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

    await _removeTask(task.id);
    shared.logI('MediaUploadQueue: Task ${task.id} completed successfully.');
  }

  Future<void> _updateDatabaseRecord({
    required String postId,
    required int index,
    required String remoteUrl,
    String? remoteFirstFrameUrl,
  }) async {
    // Read the current post row from SQLite.
    final result = await _db.get('SELECT * FROM posts WHERE id = ?', [postId]);
    if (result.isEmpty) {
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
