import 'dart:async';

import 'package:database_client/src/server_snapshots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PendingLikes', () {
    test('shows a like at once, until the server counts it', () {
      final pending = PendingLikes()..record('p', base: 5, likedBefore: false);
      // The heart is on, the server still says 5.
      expect(pending.apply('p', count: 5, liked: true), 6);
      // The server caught up: its number from now on.
      expect(pending.apply('p', count: 6, liked: true), 6);
      expect(pending.apply('p', count: 6, liked: true), 6);
    });

    test('shows an unlike at once', () {
      final pending = PendingLikes()..record('p', base: 5, likedBefore: true);
      expect(pending.apply('p', count: 5, liked: false), 4);
      expect(pending.apply('p', count: 4, liked: false), 4);
    });

    test('liking and unliking before the server moves leaves the count', () {
      final pending = PendingLikes()
        ..record('p', base: 5, likedBefore: false)
        // The unlike, recorded with the heart still on.
        ..record('p', base: 5, likedBefore: true);
      expect(pending.apply('p', count: 5, liked: false), 5);
      // And liking once more.
      pending.record('p', base: 5, likedBefore: false);
      expect(pending.apply('p', count: 5, liked: true), 6);
    });

    test('never below zero', () {
      final pending = PendingLikes()..record('p', base: 0, likedBefore: true);
      expect(pending.apply('p', count: 0, liked: false), 0);
    });

    test('a post with nothing pending reads as the server has it', () {
      expect(PendingLikes().apply('p', count: 3, liked: true), 3);
    });
  });

  group('RemotePosts', () {
    Map<String, dynamic> row(String id, {int likes = 1}) => {
      'id': id,
      'user_id': 'author-$id',
      'likes_count': likes,
      'comments_count': 2,
      'liked_by_me': true,
      'referral_tier': 3,
      'referral_tier_expires_at': '2030-01-01T00:00:00Z',
      'author_places': 4,
    };

    test('keeps what a list said about each post', () {
      final remote = RemotePosts()..putAll([row('a', likes: 7)]);
      final stats = remote['a']!;
      expect(stats.authorId, 'author-a');
      expect(stats.likes, 7);
      expect(stats.comments, 2);
      expect(stats.likedByMe, isTrue);
      expect(stats.authorTier, 3);
      expect(stats.authorPlaces, 4);
      expect(remote['b'], isNull);
    });

    test('says when it changes', () async {
      final remote = RemotePosts();
      var changes = 0;
      final sub = remote.changes.listen((_) => changes++);
      remote
        ..putAll([row('a')])
        ..putAll(const []);
      await sub.cancel();
      expect(changes, 1);
    });

    test('forgets the oldest past its capacity', () {
      final remote = RemotePosts()
        ..putAll([for (var i = 0; i < 1001; i++) row('$i')]);
      expect(remote['0'], isNull);
      expect(remote['1000'], isNotNull);
    });
  });

  test('restartOn starts the stream again on each signal', () async {
    final restart = StreamController<void>.broadcast(sync: true);
    var builds = 0;
    final values = <int>[];
    final sub = restartOn(restart.stream, () {
      builds++;
      return Stream.value(builds);
    }).listen(values.add);
    await pumpEventQueue();
    restart.add(null);
    await pumpEventQueue();
    await sub.cancel();
    await restart.close();
    expect(values, [1, 2]);
  });
}
