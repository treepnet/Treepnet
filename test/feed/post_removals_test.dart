import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:database_client/database_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insta_blocks/insta_blocks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:powersync_repository/powersync_repository.dart';
import 'package:treepnet/timeline/bloc/timeline_bloc.dart';

import '../helpers/powersync_test_db.dart';

class _MockPowerSyncRepository extends Mock implements PowerSyncRepository {}

class _MockPostsRepository extends Mock implements PostsRepository {}

PostSmallBlock _tile(String id, String authorId) => PostSmallBlock(
  id: id,
  author: PostAuthor(id: authorId, avatarUrl: '', username: authorId),
  createdAt: DateTime(2026),
  media: const [],
  caption: '',
);

void main() {
  group('PostRemoval', () {
    test('one post: only that post', () {
      const removal = PostRemoval.post('p1');
      expect(removal.removes(postId: 'p1', authorId: 'a'), isTrue);
      expect(removal.removes(postId: 'p2', authorId: 'a'), isFalse);
    });

    test('a blocked author: every post of theirs, no one else', () {
      const removal = PostRemoval.author('a');
      expect(removal.removes(postId: 'p1', authorId: 'a'), isTrue);
      expect(removal.removes(postId: 'p9', authorId: 'a'), isTrue);
      expect(removal.removes(postId: 'p1', authorId: 'b'), isFalse);
    });
  });

  group('PowerSyncDatabaseClient.postRemovals', () {
    late PowerSyncDatabaseClient client;

    // A real local database (an empty one, never connected): the client's
    // own SQL runs.
    setUp(() async {
      final db = await openTestPowerSyncDb();
      await db.execute("INSERT INTO posts (id) VALUES ('p1')");
      final repo = _MockPowerSyncRepository();
      when(repo.db).thenReturn(db);
      client = PowerSyncDatabaseClient(powerSyncRepository: repo);
    });

    test('a deleted post is announced', () async {
      final next = client.postRemovals.first;
      await client.deletePost(id: 'p1');
      expect(await next, const PostRemoval.post('p1'));
    });

    test('nothing deleted, nothing announced', () async {
      final seen = <PostRemoval>[];
      final sub = client.postRemovals.listen(seen.add);
      await client.deletePost(id: 'p9');
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty);
      await sub.cancel();
    });

    test('a block announces the author', () async {
      const me = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      const author = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      final next = client.postRemovals.first;
      await client.blockUser(userId: me, blockedId: author);
      expect(await next, const PostRemoval.author(author));
    });
  });

  group('TimelineBloc', () {
    late StreamController<PostRemoval> removals;
    late _MockPostsRepository repo;

    setUp(() {
      removals = StreamController<PostRemoval>.broadcast();
      repo = _MockPostsRepository();
      when(() => repo.postRemovals).thenAnswer((_) => removals.stream);
    });

    tearDown(() => removals.close());

    final grid = const TimelineState.initial().copyWith(
      status: TimelineStatus.populated,
      timeline: FeedPage(
        page: 1,
        hasMore: true,
        blocks: [_tile('p1', 'a'), _tile('p2', 'b'), _tile('p3', 'a')],
        totalBlocks: 3,
      ),
    );

    blocTest<TimelineBloc, TimelineState>(
      'a hidden or deleted post leaves the Trends grid',
      build: () => TimelineBloc(postsRepository: repo),
      seed: () => grid,
      act: (_) => removals.add(const PostRemoval.post('p2')),
      wait: Duration.zero,
      expect: () => [
        isA<TimelineState>().having(
          (s) => s.timeline.blocks.map((b) => (b as PostBlock).id),
          'ids',
          ['p1', 'p3'],
        ),
      ],
    );

    blocTest<TimelineBloc, TimelineState>(
      'a blocked author takes all their tiles with them',
      build: () => TimelineBloc(postsRepository: repo),
      seed: () => grid,
      act: (_) => removals.add(const PostRemoval.author('a')),
      wait: Duration.zero,
      expect: () => [
        isA<TimelineState>()
            .having(
              (s) => s.timeline.blocks.map((b) => (b as PostBlock).id),
              'ids',
              ['p2'],
            )
            .having((s) => s.timeline.totalBlocks, 'totalBlocks', 1),
      ],
    );

    blocTest<TimelineBloc, TimelineState>(
      'a post not in the grid changes nothing',
      build: () => TimelineBloc(postsRepository: repo),
      seed: () => grid,
      act: (_) => removals.add(const PostRemoval.post('elsewhere')),
      wait: Duration.zero,
      expect: () => <TimelineState>[],
    );
  });
}
