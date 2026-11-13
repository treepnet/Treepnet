// fake_async comes with flutter_test.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/comments/comments.dart';

class _MockPostsRepository extends Mock implements PostsRepository {}

class _MockScope extends Mock implements SyncScope {}

/// The phone keeps a post's comments only while (and for a while after) they
/// are open, so on a first open the list is empty until they arrive. The page
/// said "No comments" meanwhile — and for good when offline.
void main() {
  late _MockPostsRepository repository;
  late _MockScope scope;
  late Completer<void> arrived;

  setUp(() {
    repository = _MockPostsRepository();
    scope = _MockScope();
    when(
      () => repository.postScope(
        postId: any(named: 'postId'),
        ownerId: any(named: 'ownerId'),
      ),
    ).thenReturn(scope);
    // Nothing on the phone yet.
    when(
      () => repository.commentsOf(postId: any(named: 'postId')),
    ).thenAnswer((_) => Stream.value(const <Comment>[]));
  });

  /// Made inside the test's fake time, so what waits on it runs there too.
  CommentsBloc open() {
    arrived = Completer<void>();
    when(() => scope.synced).thenAnswer((_) => arrived.future);
    return CommentsBloc(
      postId: 'post',
      postOwnerId: 'owner',
      postsRepository: repository,
    )..add(const CommentsSubscriptionRequested());
  }

  test('still on their way: not "no comments" yet', () {
    fakeAsync((async) {
      final bloc = open();
      async.flushMicrotasks();
      expect(bloc.state.status, CommentsStatus.initial);
      expect(bloc.state.comments, isEmpty);
      unawaited(bloc.close());
      async.elapse(CommentsBloc.arrivalWait);
    });
  });

  test('arrived and there are none: "no comments"', () {
    fakeAsync((async) {
      final bloc = open();
      async.flushMicrotasks();
      arrived.complete();
      async.flushMicrotasks();
      expect(bloc.state.status, CommentsStatus.populated);
      // The wait running out later doesn't take it back.
      async.elapse(CommentsBloc.arrivalWait);
      expect(bloc.state.status, CommentsStatus.populated);
      unawaited(bloc.close());
      async.flushMicrotasks();
    });
  });

  test('not in time (offline): unavailable, until they come', () {
    fakeAsync((async) {
      final bloc = open();
      async.flushMicrotasks();
      async.elapse(CommentsBloc.arrivalWait);
      expect(bloc.state.status, CommentsStatus.unavailable);
      // Back online.
      arrived.complete();
      async.flushMicrotasks();
      expect(bloc.state.status, CommentsStatus.populated);
      unawaited(bloc.close());
      async.flushMicrotasks();
    });
  });
}
