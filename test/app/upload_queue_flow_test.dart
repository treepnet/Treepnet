// The app reaches PowerSync and path_provider through other packages; their
// types are only needed here to fake them.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase, SyncStatus;
import 'package:shared/shared.dart'
    show MediaBucket, MediaFileOptions, MediaUploadLink;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treepnet/app/services/media_upload_queue.dart';

class _MockDb extends Mock implements PowerSyncDatabase {}

class _Paths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _Paths(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

/// The media bucket: records what is uploaded, and fails or holds an upload
/// when a test says so.
class _Bucket extends Fake implements MediaBucket {
  final uploaded = <String>[];

  /// Remote paths whose upload throws.
  final failing = <String>{};

  /// Remote paths whose upload waits for this to complete.
  final held = <String, Completer<void>>{};

  /// The link each upload came with (null: it asked for its own).
  final linkUsed = <String, MediaUploadLink?>{};

  /// Uploads going at the same moment, now and at most.
  int inFlight = 0;
  int mostAtOnce = 0;

  @override
  Future<String> uploadBinary(
    String path,
    Uint8List bytes, {
    MediaFileOptions fileOptions = const MediaFileOptions(),
    MediaUploadLink? link,
  }) async {
    linkUsed[path] = link;
    inFlight++;
    mostAtOnce = inFlight > mostAtOnce ? inFlight : mostAtOnce;
    try {
      await held[path]?.future;
      if (failing.contains(path)) throw Exception('upload failed: $path');
      uploaded.add(path);
      return path;
    } finally {
      inFlight--;
    }
  }

  @override
  String getPublicUrl(String path) => 'https://media.test/$path';
}

const _me = 'me';

PendingPost _post(
  String id, {
  int files = 1,
  List<Map<String, dynamic>>? sources,
}) => PendingPost(
  postId: id,
  userId: _me,
  caption: 'caption of $id',
  media: [
    for (var i = 0; i < files; i++)
      {'url': '', 'type': '__image_media__', 'media_id': '$id-$i'},
  ],
  sources: sources ?? const [],
);

PendingStory _story(String id, {String? url}) => PendingStory(
  storyId: id,
  userId: _me,
  sourcePath: '/nowhere/$id.jpg',
  contentType: 'image',
  prepared: true,
  contentUrl: url,
);

void main() {
  late Directory root;
  late _MockDb db;
  late _Bucket bucket;

  /// The link calls made, each with the files it asked for; null makes the
  /// call fail (the backend refusing).
  late List<List<String>> linkCalls;
  bool linksRefused = false;
  late MediaUploadQueue queue;
  final created = <PendingPost>[];
  final createdStories = <String>[];

  setUp(() {
    root = Directory.systemTemp.createTempSync('upload_queue_test');
    PathProviderPlatform.instance = _Paths(root.path);
    created.clear();
    createdStories.clear();
    linkCalls = [];
    linksRefused = false;
  });

  tearDown(() {
    queue.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A file on this phone for a queued upload.
  String file(String name) {
    final f = File('${root.path}/$name')..writeAsBytesSync([1, 2, 3]);
    return f.path;
  }

  PendingUploadTask task(
    String postId,
    int index, {
    String? localPath,
    int attempts = 0,
    String bucket = 'posts',
  }) => PendingUploadTask(
    id: '${postId}_$index',
    postId: postId,
    localPath: localPath ?? file('${postId}_$index.jpg'),
    remotePath: '$postId/image_$index',
    bucket: bucket,
    contentType: 'image/jpeg',
    mediaType: '__image_media__',
    index: index,
    blurHash: '',
    createdAt: DateTime.now(),
    attempts: attempts,
  );

  Future<void> open({
    List<PendingPost> posts = const [],
    List<PendingStory> stories = const [],
    List<PendingUploadTask> tasks = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      'treepnet_pending_posts': [
        for (final p in posts) json.encode(p.toJson()),
      ],
      'treepnet_pending_stories': [
        for (final s in stories) json.encode(s.toJson()),
      ],
      'treepnet_pending_uploads_queue': [
        for (final t in tasks) json.encode(t.toJson()),
      ],
    });
    db = _MockDb();
    bucket = _Bucket();
    when(() => db.statusStream).thenAnswer((_) => const Stream.empty());
    when(() => db.currentStatus).thenReturn(const SyncStatus(connected: true));
    // Nothing is created on the server yet.
    when(() => db.getOptional(any(), any())).thenAnswer((_) async => null);
    queue =
        MediaUploadQueue(
            db: db,
            sharedPreferences: await SharedPreferences.getInstance(),
            storageFor: (_) => bucket,
            linksOf: (files) async {
              linkCalls.add([for (final f in files) '${f.bucket}/${f.path}']);
              if (linksRefused) throw Exception('refused');
              return [
                for (final f in files)
                  (url: 'https://link.test/${f.path}', path: f.path),
              ];
            },
          )
          ..attachUser(() => _me)
          ..attachPostCreator((post) async {
            created.add(post);
            return true;
          })
          ..attachStoryCreator((story) async {
            createdStories.add(story.storyId);
            return true;
          });
  }

  /// Runs the queue's cycle and lets it finish.
  Future<void> run() async {
    queue.triggerProcessing();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  test(
    'a post: its files upload, then it is created with their links',
    () async {
      final first = task('p1', 0);
      final second = task('p1', 1);
      await open(posts: [_post('p1', files: 2)], tasks: [first, second]);
      await run();

      // Uploaded together, in any order; the post keeps its photos' order.
      expect(bucket.uploaded, unorderedEquals(['p1/image_0', 'p1/image_1']));
      expect(created.single.postId, 'p1');
      expect(
        [for (final m in created.single.media) m['url']],
        ['https://media.test/p1/image_0', 'https://media.test/p1/image_1'],
      );
      expect(queue.pendingCountFor(_me), 0, reason: 'nothing left queued');
      expect(File(first.localPath).existsSync(), isFalse, reason: 'files go');
    },
  );

  test("a post isn't created while one of its files hasn't uploaded", () async {
    await open(
      posts: [_post('p1', files: 2)],
      tasks: [task('p1', 0), task('p1', 1)],
    );
    bucket.failing.add('p1/image_1');
    await run();

    expect(bucket.uploaded, [
      'p1/image_0',
    ], reason: 'one failure blocks no other');
    expect(created, isEmpty);
    expect(queue.pendingCountFor(_me), 1);
    expect(
      queue.status.value?.failed,
      isFalse,
      reason: 'it retries on its own',
    );
  });

  test('after 3 failed uploads it offers Retry, and Retry goes now', () async {
    await open(posts: [_post('p1')], tasks: [task('p1', 0, attempts: 2)]);
    bucket.failing.add('p1/image_0');
    await run();
    expect(queue.status.value?.failed, isTrue);
    expect(created, isEmpty);

    bucket.failing.clear();
    await queue.retry('p1');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(created.single.postId, 'p1');
  });

  test(
    'a file lost before upload: the post goes out with the others',
    () async {
      await open(
        posts: [_post('p1', files: 2)],
        tasks: [
          task('p1', 0, localPath: '${Directory.systemTemp.path}/gone.jpg'),
          task('p1', 1),
        ],
      );
      await run();

      expect(created.single.media, hasLength(1));
      expect(
        created.single.media.single['url'],
        'https://media.test/p1/image_1',
      );
    },
  );

  test(
    'a picked file lost before it was prepared: Retry or Cancel, not stuck',
    () async {
      await open(
        posts: [
          _post(
            'p1',
            sources: [
              {
                'index': 0,
                'path': '${root.path}/never-there.jpg',
                'isVideo': false,
              },
            ],
          ),
        ],
      );
      await run();

      expect(created, isEmpty);
      expect(queue.status.value?.failed, isTrue);
    },
  );

  test(
    'cancelled while a file is uploading: the post is not created',
    () async {
      await open(posts: [_post('p1')], tasks: [task('p1', 0)]);
      final upload = Completer<void>();
      bucket.held['p1/image_0'] = upload;
      queue.triggerProcessing();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await queue.cancel('p1');
      upload.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await run();

      expect(created, isEmpty);
      expect(queue.pendingCountFor(_me), 0);
    },
  );

  test('stories go out in the order they were shared', () async {
    await open(
      stories: [
        // Still uploading: the one shared after it waits.
        _story('s1'),
        _story('s2', url: 'https://media.test/stories/s2/image'),
      ],
      tasks: [task('s1', 0, bucket: 'stories')],
    );
    bucket.held['s1/image_0'] = Completer<void>();
    queue.triggerProcessing();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(createdStories, isEmpty, reason: 's2 waits for s1');

    bucket.held['s1/image_0']!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await run();
    expect(createdStories, ['s1', 's2']);
  });

  test('files go up three at a time', () async {
    final tasks = [for (var i = 0; i < 5; i++) task('p1', i)];
    await open(posts: [_post('p1', files: 5)], tasks: tasks);
    final release = Completer<void>();
    for (var i = 0; i < 5; i++) {
      bucket.held['p1/image_$i'] = release;
    }
    queue.triggerProcessing();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bucket.inFlight, 3, reason: 'they went one at a time');

    release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await run();
    expect(bucket.mostAtOnce, 3);
    expect(created.single.media, hasLength(5));
  });

  test(
    "a post's links come in one call, and each upload uses its own",
    () async {
      await open(
        posts: [_post('p1', files: 2)],
        tasks: [task('p1', 0), task('p1', 1)],
      );
      await run();

      expect(linkCalls, [
        ['posts/p1/image_0', 'posts/p1/image_1'],
      ]);
      expect(
        bucket.linkUsed['p1/image_1']?.url,
        'https://link.test/p1/image_1',
      );
      expect(created.single.postId, 'p1');
    },
  );

  test('links refused in one call: each upload asks for its own', () async {
    await open(posts: [_post('p1')], tasks: [task('p1', 0)]);
    linksRefused = true;
    await run();

    expect(bucket.linkUsed.containsKey('p1/image_0'), isTrue);
    expect(bucket.linkUsed['p1/image_0'], isNull);
    expect(created.single.postId, 'p1');
  });
}
