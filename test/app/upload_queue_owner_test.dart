// The app reaches PowerSync through powersync_repository; the database type
// is only needed here to fake it.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase, SyncStatus;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treepnet/app/services/media_upload_queue.dart';

class _MockDb extends Mock implements PowerSyncDatabase {}

PendingPost _post(String id, String userId) => PendingPost(
  postId: id,
  userId: userId,
  caption: '',
  media: [
    {'url': 'https://example.com/$id.jpg', 'type': '__image_media__'},
  ],
);

PendingStory _story(String id, String userId, {String? url}) => PendingStory(
  storyId: id,
  userId: userId,
  sourcePath: '/nowhere/$id.jpg',
  contentType: 'image',
  prepared: true,
  contentUrl: url,
);

void main() {
  late _MockDb db;
  late MediaUploadQueue queue;
  String? me;
  final createdPosts = <String>[];
  final createdStories = <String>[];

  Future<void> setUpQueue({
    List<PendingPost> posts = const [],
    List<PendingStory> stories = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      'treepnet_pending_posts': [
        for (final p in posts) json.encode(p.toJson()),
      ],
      'treepnet_pending_stories': [
        for (final s in stories) json.encode(s.toJson()),
      ],
    });
    db = _MockDb();
    when(() => db.statusStream).thenAnswer((_) => const Stream.empty());
    when(() => db.currentStatus).thenReturn(const SyncStatus());
    when(() => db.getOptional(any(), any())).thenAnswer((_) async => null);
    queue =
        MediaUploadQueue(
            db: db,
            sharedPreferences: await SharedPreferences.getInstance(),
          )
          ..attachPostCreator((post) async {
            createdPosts.add(post.postId);
            return true;
          })
          ..attachStoryCreator((story) async {
            createdStories.add(story.storyId);
            return true;
          });
  }

  /// Lets the queue's processing cycle run.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  setUp(() {
    me = null;
    createdPosts.clear();
    createdStories.clear();
  });

  test("another account's post is neither shown nor created", () async {
    await setUpQueue(posts: [_post('a1', 'A')]);
    me = 'B';
    queue.attachUser(() => me);
    await settle();
    expect(queue.status.value, isNull);
    expect(createdPosts, isEmpty);
  });

  test('its owner, signed in again, sees it and gets it created', () async {
    await setUpQueue(posts: [_post('a1', 'A')]);
    me = 'B';
    queue.attachUser(() => me);
    await settle();
    me = 'A';
    queue.userChanged();
    await settle();
    expect(createdPosts, ['a1']);
  });

  test("another account's unfinished story doesn't hold back mine", () async {
    await setUpQueue(
      stories: [
        _story('a1', 'A'),
        _story('b1', 'B', url: 'https://x/b1'),
      ],
    );
    me = 'B';
    queue.attachUser(() => me);
    await settle();
    expect(createdStories, ['b1']);
  });

  test('counts what an account is still publishing', () async {
    await setUpQueue(
      posts: [_post('a1', 'A'), _post('b1', 'B')],
      stories: [_story('a2', 'A')],
    );
    expect(queue.pendingCountFor('A'), 2);
    expect(queue.pendingCountFor('B'), 1);
    expect(queue.pendingCountFor('C'), 0);
  });

  test("a deleted account's items go, the others stay", () async {
    await setUpQueue(
      posts: [_post('a1', 'A'), _post('b1', 'B')],
      stories: [_story('a2', 'A')],
    );
    await queue.cancelAllOf('A');
    expect(queue.pendingCountFor('A'), 0);
    expect(queue.pendingCountFor('B'), 1);
  });

  test('signed out: nothing is shown', () async {
    await setUpQueue(posts: [_post('a1', 'A')]);
    me = 'A';
    queue.attachUser(() => me);
    await settle();
    queue.detachUser();
    await settle();
    expect(queue.status.value, isNull);
  });
}
