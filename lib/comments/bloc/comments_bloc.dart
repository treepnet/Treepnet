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

  Future<void> _onCommentsSubscriptionRequested(
    CommentsSubscriptionRequested event,
    Emitter<CommentsState> emit,
  ) async {
    await emit.forEach(
      _postsRepository.commentsOf(postId: id),
      onData: (comments) => state.copyWith(comments: comments),
    );
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
