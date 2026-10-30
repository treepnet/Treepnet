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

/// A file picked for a new post, as handed to [MediaUploadQueue.startPost].
class PostSourceFile {
  const PostSourceFile({
    required this.bytes,
    required this.path,
    required this.isVideo,
  });

  /// The picked image's bytes (unused for a video, which is copied by [path]).
  final Uint8List bytes;
  final String path;
  final bool isVideo;
}

/// A post being published from this phone.
///
/// It is saved the moment the user shares it, then prepared (compressed),
/// uploaded and only then created — so it survives the app being closed, and
/// nobody ever sees a post pointing at files that exist only on the author's
/// phone. [media] holds the post's media entries; an entry not uploaded yet
/// has an empty `url` (and `null` once its file is lost). [sources] are the
/// picked files still waiting to be prepared.
class PendingPost {
  PendingPost({
    required this.postId,
    required this.userId,
    required this.caption,
    required this.media,
    this.sources = const [],
    this.error,
    this.thumbnailPath,
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
      sources: List<Map<String, dynamic>>.from(
        ((json['sources'] as List<dynamic>?) ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      ),
      error: json['error'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
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

  /// `{index, path, isVideo}` of each picked file not prepared yet.
  final List<Map<String, dynamic>> sources;

  /// Why preparing failed; the post waits for [MediaUploadQueue.retryPost].
  final String? error;

  /// The first picked image, shown in the "Posting…" banner.
  final String? thumbnailPath;
  final String? location;
  final String? locationCountry;
  final String? locationRegion;
  final String? locationName;
  final double? locationLat;
  final double? locationLng;

  PendingPost withMedia(List<Map<String, dynamic>> media) =>
      copyWith(media: media);

  PendingPost copyWith({
    List<Map<String, dynamic>>? media,
    List<Map<String, dynamic>>? sources,
    String? error,
    bool clearError = false,
  }) {
    return PendingPost(
      postId: postId,
      userId: userId,
      caption: caption,
      media: media ?? this.media,
      sources: sources ?? this.sources,
      error: clearError ? null : error ?? this.error,
      thumbnailPath: thumbnailPath,
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
      'sources': sources,
      'error': error,
      'thumbnailPath': thumbnailPath,
      'location': location,
      'locationCountry': locationCountry,
      'locationRegion': locationRegion,
      'locationName': locationName,
      'locationLat': locationLat,
      'locationLng': locationLng,
    };
  }
}

/// A story being published from this phone: saved when shared, then
/// compressed, uploaded and only then created, like a [PendingPost].
class PendingStory {
  PendingStory({
    required this.storyId,
    required this.userId,
    required this.sourcePath,
    required this.contentType,
    this.duration,
    this.locationName,
    this.locationLat,
    this.locationLng,
    this.prepared = false,
    this.contentUrl,
    this.error,
  });

  factory PendingStory.fromJson(Map<String, dynamic> json) {
    return PendingStory(
      storyId: json['storyId'] as String,
      userId: json['userId'] as String,
      sourcePath: json['sourcePath'] as String,
      contentType: json['contentType'] as String,
      duration: json['duration'] as int?,
      locationName: json['locationName'] as String?,
      locationLat: (json['locationLat'] as num?)?.toDouble(),
      locationLng: (json['locationLng'] as num?)?.toDouble(),
      prepared: json['prepared'] as bool? ?? false,
      contentUrl: json['contentUrl'] as String?,
      error: json['error'] as String?,
    );
  }

  final String storyId;

  /// Who made it: it is only ever created while this account is signed in.
  final String userId;

  /// The edited story image (also the banner's thumbnail).
  final String sourcePath;

  /// A `StoryContentType` name.
  final String contentType;
  final int? duration;
  final String? locationName;
  final double? locationLat;
  final double? locationLng;

  /// Compressed and queued for upload.
  final bool prepared;

  /// Set once uploaded.
  final String? contentUrl;

  /// Why preparing failed (or its file was lost); waits for a retry.
  final String? error;

  PendingStory copyWith({
    bool? prepared,
    String? contentUrl,
    String? error,
    bool clearError = false,
  }) {
    return PendingStory(
      storyId: storyId,
      userId: userId,
      sourcePath: sourcePath,
      contentType: contentType,
      duration: duration,
      locationName: locationName,
      locationLat: locationLat,
      locationLng: locationLng,
      prepared: prepared ?? this.prepared,
      contentUrl: contentUrl ?? this.contentUrl,
      error: clearError ? null : error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'storyId': storyId,
      'userId': userId,
      'sourcePath': sourcePath,
      'contentType': contentType,
      'duration': duration,
      'locationName': locationName,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'prepared': prepared,
      'contentUrl': contentUrl,
      'error': error,
    };
  }
}

/// What the "Posting…" banner shows: the oldest post (or else story) being
/// published.
class PostPublishStatus {
  const PostPublishStatus({
    required this.id,
    required this.progress,
    this.thumbnail,
    this.failed = false,
    this.posted = false,
  });

  /// The post's or story's id.
  final String id;

  /// 0.0 – 1.0: files prepared and uploaded so far.
  final double progress;
  final Uint8List? thumbnail;

  /// Preparing failed or an upload keeps failing: offer Retry / Cancel. The
  /// queue still retries uploads on its own.
  final bool failed;

  /// Just created; shown for a moment, then the banner hides.
  final bool posted;
}

/// Preparing a shared post's or story's files failed — reported so we hear
/// about it.
class _PrepareFailed implements Exception {
  _PrepareFailed(this.kind, this.id, this.error);

  final String kind;
  final String id;
  final Object error;

  @override
  String toString() =>
      'Preparing $kind $id failed: ${error.runtimeType}: $error';
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
/// A shared post is queued whole as a [PendingPost] ([startPost]): its files
/// are prepared and uploaded here, and the post is created by the post creator
/// the app attaches ([attachPostCreator]) once its last file is uploaded.
/// A shared story goes the same way ([startStory], [attachStoryCreator]),
/// one at a time. [status] drives the "Posting…" banner.
class MediaUploadQueue {
  MediaUploadQueue({
    required PowerSyncDatabase db,
    required SharedPreferences sharedPreferences,
  })  : _db = db,
        _prefs = sharedPreferences;

  static const String _storageKey = 'treepnet_pending_uploads_queue';
  static const String _postsKey = 'treepnet_pending_posts';
  static const String _storiesKey = 'treepnet_pending_stories';

  /// Backoff after the first failure; doubles each time, up to [_maxBackoff].
  static const Duration _firstBackoff = Duration(seconds: 30);
  static const Duration _maxBackoff = Duration(hours: 1);
  static const int _reportAfterAttempts = 5;

  /// After this many failed uploads the banner offers Retry / Cancel.
  static const int _failAfterAttempts = 3;

  /// The post is created only after all its media are uploaded or queued, so a
  /// fresh task may run before its post exists. Within this window a missing
  /// post means "not yet"; after it, the post was deleted (or never made).
  static const Duration _postGrace = Duration(minutes: 10);

  final PowerSyncDatabase _db;
  final SharedPreferences _prefs;

  /// Creates a ready [PendingPost]; returns false when it can't yet (e.g.
  /// another account is signed in). Null until the app attaches one.
  Future<bool> Function(PendingPost post)? _postCreator;

  /// Like [_postCreator], for stories.
  Future<bool> Function(PendingStory story)? _storyCreator;

  final ValueNotifier<PostPublishStatus?> _status = ValueNotifier(null);
  final Map<String, Uint8List?> _thumbnails = {};
  PostPublishStatus? _posted;
  Timer? _postedTimer;

  /// The oldest post being published, or null when there is none.
  ValueListenable<PostPublishStatus?> get status => _status;

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
    unawaited(_refreshStatus());
  }

  /// Disposes resources.
  void dispose() {
    _syncStatusSubscription?.cancel();
    _retryTimer?.cancel();
    _postedTimer?.cancel();
  }

  /// Lets the queue create posts once their media are uploaded. Posts that
  /// became ready while no creator was attached are created now.
  void attachPostCreator(Future<bool> Function(PendingPost post) creator) {
    _postCreator = creator;
    triggerProcessing();
  }

  void detachPostCreator() => _postCreator = null;

  /// Lets the queue create stories once uploaded (see [attachPostCreator]).
  void attachStoryCreator(Future<bool> Function(PendingStory story) creator) {
    _storyCreator = creator;
    triggerProcessing();
  }

  void detachStoryCreator() => _storyCreator = null;

  /// Publishes a new story: saves the edited image to this phone first, then
  /// compresses, uploads and creates it in the background, after any story
  /// shared before it.
  Future<void> startStory({
    required String storyId,
    required String userId,
    required String filePath,
    required String contentType,
    int? duration,
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) async {
    final dir = await _postDir(storyId);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final extension = p.extension(filePath).replaceFirst('.', '');
    final sourcePath = p.join(
      dir.path,
      'source.${extension.isEmpty ? 'jpg' : extension.toLowerCase()}',
    );
    await File(filePath).copy(sourcePath);
    await _saveStory(
      PendingStory(
        storyId: storyId,
        userId: userId,
        sourcePath: sourcePath,
        contentType: contentType,
        duration: duration,
        locationName: locationName,
        locationLat: locationLat,
        locationLng: locationLng,
      ),
    );
    shared.logI('MediaUploadQueue: Queued story $storyId.');
    await _refreshStatus();
    triggerProcessing();
  }

  /// Publishes a new post: saves the picked [files] and the post to this
  /// phone first, then prepares, uploads and creates it in the background —
  /// also after the app is closed and opened again.
  Future<void> startPost({
    required String postId,
    required String userId,
    required String caption,
    required List<PostSourceFile> files,
    String? location,
    String? locationCountry,
    String? locationRegion,
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) async {
    final dir = await _postDir(postId);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final sources = <Map<String, dynamic>>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final extension = p.extension(file.path).replaceFirst('.', '');
      final path = p.join(
        dir.path,
        'source_$i.${extension.isEmpty ? 'jpg' : extension.toLowerCase()}',
      );
      if (file.isVideo) {
        await File(file.path).copy(path);
      } else {
        await File(path).writeAsBytes(file.bytes);
      }
      sources.add({'index': i, 'path': path, 'isVideo': file.isVideo});
    }
    final firstIsImage = files.isNotEmpty && !files.first.isVideo;
    await _saveDraft(
      PendingPost(
        postId: postId,
        userId: userId,
        caption: caption,
        media: [
          for (var i = 0; i < files.length; i++) <String, dynamic>{'url': ''},
        ],
        sources: sources,
        thumbnailPath: firstIsImage ? sources.first['path'] as String : null,
        location: location,
        locationCountry: locationCountry,
        locationRegion: locationRegion,
        locationName: locationName,
        locationLat: locationLat,
        locationLng: locationLng,
      ),
    );
    shared.logI('MediaUploadQueue: Queued post $postId (${files.length} files).');
    await _refreshStatus();
    triggerProcessing();
  }

  /// Tries a failed post or story ([id]) again now (its uploads also retry
  /// on their own).
  Future<void> retry(String id) async {
    final draft = _loadDrafts()[id];
    if (draft != null) await _saveDraft(draft.copyWith(clearError: true));
    final story = _loadStories()[id];
    if (story != null) await _saveStory(story.copyWith(clearError: true));
    final now = DateTime.now();
    for (final task in _loadTasks()) {
      if (task.postId == id) {
        await _saveTask(task.retryLater(attempts: 0, at: now));
      }
    }
    await _refreshStatus();
    triggerProcessing();
  }

  /// Drops a post or story ([id]) being published, with its files.
  Future<void> cancel(String id) async {
    for (final task in _loadTasks()) {
      if (task.postId == id) await _removeTask(task.id);
    }
    await _removeDraft(id);
    await _removeStory(id);
    shared.logI('MediaUploadQueue: Cancelled $id.');
    await _refreshStatus();
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
    await _prepareDrafts();
    await _prepareStories();
    await _uploadDueTasks();
    await _createReadyPosts();
    await _createReadyStories();
    await _refreshStatus();
  }

  /// Compresses shared stories and queues their uploads (bucket `stories`,
  /// `<storyId>/image`, as the app always stored them).
  Future<void> _prepareStories() async {
    for (final story in _loadStories().values) {
      if (story.prepared || story.error != null) continue;
      try {
        final source = File(story.sourcePath);
        final compressed = await shared.ImageCompress.compressStory(source);
        // If re-encoding fails, upload the original rather than lose it.
        final file = compressed == null ? source : File(compressed.path);
        final extension = p.extension(file.path).replaceFirst('.', '');
        final mime = extension == 'jpg' || extension.isEmpty
            ? 'jpeg'
            : extension.toLowerCase();
        await enqueueTask(
          postId: story.storyId,
          bytes: await file.readAsBytes(),
          remotePath: '${story.storyId}/image',
          bucket: 'stories',
          contentType: 'image/$mime',
          mediaType: shared.ImageMedia.identifier,
          index: 0,
          blurHash: '',
        );
        if (compressed != null) {
          try {
            File(compressed.path).deleteSync();
          } catch (_) {}
        }
        if (!_loadStories().containsKey(story.storyId)) {
          await cancel(story.storyId);
          continue;
        }
        await _saveStory(story.copyWith(prepared: true));
      } catch (error, stackTrace) {
        shared.logE(
          'MediaUploadQueue: Preparing story ${story.storyId} failed',
          error: error,
          stackTrace: stackTrace,
        );
        CrashReporter.instance.report(
          _PrepareFailed('story', story.storyId, error),
          stackTrace,
          kind: 'story-prepare',
        );
        if (_loadStories().containsKey(story.storyId)) {
          await _saveStory(story.copyWith(error: '${error.runtimeType}'));
        }
      }
    }
  }

  /// Creates every queued story whose image is uploaded, oldest first.
  Future<void> _createReadyStories() async {
    final creator = _storyCreator;
    if (creator == null) return;
    for (final story in _loadStories().values) {
      // In the order they were shared: a story still uploading (or failed)
      // holds back the ones after it.
      if (story.contentUrl == null) break;
      final exists =
          await _db.getOptional(
            'SELECT id FROM stories WHERE id = ?',
            [story.storyId],
          ) !=
          null;
      if (exists) {
        await _removeStory(story.storyId);
        continue;
      }
      try {
        if (await creator(story)) {
          _showPosted(story.storyId);
          await _removeStory(story.storyId);
          shared.logI('MediaUploadQueue: Created queued story ${story.storyId}.');
        }
      } catch (error, stackTrace) {
        shared.logE(
          'MediaUploadQueue: Creating queued story ${story.storyId} failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Compresses the files of shared posts (also of one the app was closed in
  /// the middle of) and queues their uploads. A failure marks the post failed
  /// until the user retries it.
  Future<void> _prepareDrafts() async {
    for (final draft in _loadDrafts().values) {
      if (draft.sources.isEmpty || draft.error != null) continue;
      var current = draft;
      try {
        for (final source in draft.sources) {
          current = await _prepareSource(current, source);
          // Cancelled meanwhile: don't bring it back.
          if (!_loadDrafts().containsKey(draft.postId)) {
            await cancel(draft.postId);
            break;
          }
          await _saveDraft(current);
          // Only now that the post no longer lists it (so an app closed in
          // between can't come back to a missing file). The banner's
          // thumbnail stays until the post is done.
          final path = source['path'] as String;
          if (path != draft.thumbnailPath) {
            try {
              File(path).deleteSync();
            } catch (_) {}
          }
          await _refreshStatus();
        }
      } catch (error, stackTrace) {
        shared.logE(
          'MediaUploadQueue: Preparing post ${draft.postId} failed',
          error: error,
          stackTrace: stackTrace,
        );
        CrashReporter.instance.report(
          _PrepareFailed('post', draft.postId, error),
          stackTrace,
          kind: 'post-prepare',
        );
        if (_loadDrafts().containsKey(draft.postId)) {
          await _saveDraft(current.copyWith(error: '${error.runtimeType}'));
        }
      }
    }
  }

  /// Compresses one picked file, queues its upload and fills in its media
  /// entry (still without a URL).
  Future<PendingPost> _prepareSource(
    PendingPost draft,
    Map<String, dynamic> source,
  ) async {
    final index = source['index'] as int;
    final path = source['path'] as String;
    final isVideo = source['isVideo'] == true;
    final file = File(path);
    final extension = p.extension(path).replaceFirst('.', '');
    final postId = draft.postId;

    Map<String, dynamic> entry;
    if (isVideo) {
      final firstFrame = await shared.VideoPlus.getVideoThumbnail(file);
      final blurHash = firstFrame == null
          ? ''
          : await shared.BlurHashPlus.blurHashEncode(firstFrame);
      Uint8List bytes;
      try {
        final compressed = await shared.VideoPlus.compressVideo(file);
        bytes = await shared.PickImage().imageBytes(file: compressed!.file!);
      } catch (_) {
        bytes = await file.readAsBytes();
      }
      await enqueueTask(
        postId: postId,
        bytes: bytes,
        remotePath: '$postId/video_$index',
        bucket: 'posts',
        contentType: 'video/$extension',
        mediaType: shared.VideoMedia.identifier,
        index: index,
        blurHash: blurHash,
        firstFrameBytes: firstFrame,
        firstFrameRemotePath: '$postId/video_first_frame_$index',
      );
      entry = {
        'media_id': shared.uuid.v4(),
        'url': '',
        'type': shared.VideoMedia.identifier,
        'blur_hash': blurHash,
        'first_frame_url': null,
      };
    } else {
      final bytes = await shared.ImageCompress.compressByte(
        await file.readAsBytes(),
      );
      final blurHash = await shared.BlurHashPlus.blurHashEncode(bytes);
      await enqueueTask(
        postId: postId,
        bytes: bytes,
        remotePath: '$postId/image_$index',
        bucket: 'posts',
        contentType: 'image/$extension',
        mediaType: shared.ImageMedia.identifier,
        index: index,
        blurHash: blurHash,
      );
      entry = {
        'media_id': shared.uuid.v4(),
        'url': '',
        'type': shared.ImageMedia.identifier,
        'blur_hash': blurHash,
      };
    }

    final media = [for (final m in draft.media) Map<String, dynamic>.from(m)];
    if (index >= 0 && index < media.length) media[index] = entry;
    return draft.copyWith(
      media: media,
      sources: [
        for (final s in draft.sources)
          if (s['index'] != index) s,
      ],
    );
  }

  /// Recomputes [status] from the queued posts and their uploads.
  Future<void> _refreshStatus() async {
    final drafts = _loadDrafts().values.toList();
    if (drafts.isEmpty) {
      final stories = _loadStories().values.toList();
      if (stories.isEmpty) {
        _status.value = _posted;
        return;
      }
      final story = stories.first;
      final tasks = _loadTasks().where((t) => t.postId == story.storyId);
      _status.value = PostPublishStatus(
        id: story.storyId,
        progress: story.contentUrl != null
            ? 0.95
            : story.prepared
            ? 0.3
            : 0.03,
        thumbnail: await _thumbnailFor(story.storyId, story.sourcePath),
        failed:
            story.error != null ||
            tasks.any((t) => t.attempts >= _failAfterAttempts),
      );
      return;
    }
    final draft = drafts.first;
    final tasks = _loadTasks().where((t) => t.postId == draft.postId);
    final total = draft.media.length;
    final prepared = total - draft.sources.length;
    final uploaded = draft.media
        .where((m) => (m['url'] as String?)?.isNotEmpty ?? false)
        .length;
    final progress = total == 0
        ? 0.0
        : (prepared * 0.3 + uploaded * 0.7) / total;
    _status.value = PostPublishStatus(
      id: draft.postId,
      // Never shows 0 % (it has started) or 100 % (that means posted).
      progress: progress.clamp(0.03, 0.95),
      thumbnail: await _thumbnailFor(draft.postId, draft.thumbnailPath),
      failed:
          draft.error != null ||
          tasks.any((t) => t.attempts >= _failAfterAttempts),
    );
  }

  Future<Uint8List?> _thumbnailFor(String id, String? path) async {
    if (_thumbnails.containsKey(id)) return _thumbnails[id];
    Uint8List? bytes;
    try {
      if (path != null && File(path).existsSync()) {
        bytes = await File(path).readAsBytes();
      }
    } catch (_) {}
    return _thumbnails[id] = bytes;
  }

  /// Shows "Posted" for the post or story [id] for a moment.
  void _showPosted(String id) {
    _posted = PostPublishStatus(
      id: id,
      progress: 1,
      thumbnail: _thumbnails[id],
      posted: true,
    );
    _postedTimer?.cancel();
    _postedTimer = Timer(const Duration(milliseconds: 1500), () {
      _posted = null;
      unawaited(_refreshStatus());
    });
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
      if (draft.sources.isNotEmpty || draft.error != null) continue;

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
          _showPosted(draft.postId);
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
      final story = _loadStories()[task.postId];
      if (story != null) {
        await _saveStory(story.copyWith(prepared: false, error: 'file lost'));
      }
      await _removeTask(task.id);
      return;
    }

    // A queued post or story doesn't exist yet by design; otherwise check the
    // post first, so a deleted post's media isn't uploaded (again).
    final queuedPost = _loadDrafts().containsKey(task.postId);
    final queuedStory = _loadStories().containsKey(task.postId);
    final postExists = queuedPost ||
        queuedStory ||
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
    final storedPath = await storage.uploadBinary(
      task.remotePath,
      bytes,
      fileOptions: shared.MediaFileOptions(
        contentType: task.contentType,
        cacheControl: '9000000',
      ),
    );
    final mediaUrl = storage.getPublicUrl(storedPath);

    String? firstFrameUrl;
    if (task.firstFrameLocalPath != null && task.firstFrameRemotePath != null) {
      final firstFrameFile = File(task.firstFrameLocalPath!);
      if (firstFrameFile.existsSync()) {
        shared.logI('MediaUploadQueue: Uploading first frame for task ${task.id}...');
        final firstFrameBytes = await firstFrameFile.readAsBytes();
        final storedFramePath = await storage.uploadBinary(
          task.firstFrameRemotePath!,
          firstFrameBytes,
          fileOptions: const shared.MediaFileOptions(
            contentType: 'image/jpeg',
            cacheControl: '9000000',
          ),
        );
        firstFrameUrl = storage.getPublicUrl(storedFramePath);
      }
    }

    // Point the queued story or post (or, for a post an older version already
    // created, its database row) at the uploaded file.
    final story = _loadStories()[task.postId];
    if (story != null) {
      await _saveStory(story.copyWith(contentUrl: mediaUrl));
    } else if (queuedPost) {
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
    _thumbnails.remove(postId);
    // Its picked files, thumbnail and any upload left over.
    try {
      final dir = await _postDir(postId);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (e) {
      shared.logW('MediaUploadQueue: Minor error clearing post files: $e');
    }
  }

  Map<String, PendingStory> _loadStories() {
    final raw = _prefs.getStringList(_storiesKey) ?? [];
    final stories = raw.map(
      (e) => PendingStory.fromJson(json.decode(e) as Map<String, dynamic>),
    );
    return {for (final s in stories) s.storyId: s};
  }

  Future<void> _saveStory(PendingStory story) async {
    final stories = _loadStories()..[story.storyId] = story;
    await _prefs.setStringList(
      _storiesKey,
      stories.values.map((s) => json.encode(s.toJson())).toList(),
    );
  }

  Future<void> _removeStory(String storyId) async {
    final stories = _loadStories();
    if (stories.remove(storyId) == null) return;
    await _prefs.setStringList(
      _storiesKey,
      stories.values.map((s) => json.encode(s.toJson())).toList(),
    );
    _thumbnails.remove(storyId);
    try {
      final dir = await _postDir(storyId);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (e) {
      shared.logW('MediaUploadQueue: Minor error clearing story files: $e');
    }
  }

  Future<Directory> _postDir(String postId) async {
    final docDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(docDir.path, 'pending_uploads', postId));
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
