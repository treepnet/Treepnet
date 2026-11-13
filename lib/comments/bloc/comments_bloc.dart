import 'package:equatable/equatable.dart';
import 'package:bloc/bloc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';

part 'comments_bloc.g.dart';
part 'comments_event.dart';
part 'comments_state.dart';

class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  CommentsBloc({
    required String postId,
    required String postOwnerId,
    required PostsRepository postsRepository,
  }) : _postId = postId,
       _postsRepository = postsRepository,
       // The phone keeps no one's comments until they are open.
       _scope = postsRepository.postScope(postId: postId, ownerId: postOwnerId),
       super(const CommentsState.initial()) {
    on<CommentsSubscriptionRequested>(
      _onCommentsSubscriptionRequested,
      transformer: throttleDroppable(),
    );
    on<CommentsCommentCreateRequested>(_onCommentsCommentCreateRequested);
  }

  final String _postId;

  /// The post whose comments this bloc holds.
  String get id => _postId;

  final PostsRepository _postsRepository;
  final SyncScope _scope;

  @override
  Future<void> close() {
    _scope.close();
    return super.close();
  }

  /// How long the comments may take to arrive before the page says they will
  /// come once the phone is online.
  static const arrivalWait = Duration(seconds: 10);

  Future<void> _onCommentsSubscriptionRequested(
    CommentsSubscriptionRequested event,
    Emitter<CommentsState> emit,
  ) async {
    await Future.wait([
      emit.forEach(
        _postsRepository.commentsOf(postId: id),
        onData: (comments) => state.copyWith(comments: comments),
      ),
      // Whether they have arrived. The list is empty until they do, and the
      // page said "No comments" meanwhile, under a post showing "12
      // comments" — for good when offline.
      emit.forEach<CommentsStatus>(
        Stream.fromFutures([
          _scope.synced.then((_) => CommentsStatus.populated),
          Future.delayed(arrivalWait, () => CommentsStatus.unavailable),
        ]),
        onData: (status) =>
            status == CommentsStatus.unavailable &&
                state.status == CommentsStatus.populated
            ? state
            : state.copyWith(status: status),
      ),
    ]);
  }

  Future<void> _onCommentsCommentCreateRequested(
    CommentsCommentCreateRequested event,
    Emitter<CommentsState> emit,
  ) => _postsRepository.createComment(
    postId: id,
    userId: event.userId,
    content: event.content,
    repliedToCommentId: event.repliedToCommentId,
  );
}
