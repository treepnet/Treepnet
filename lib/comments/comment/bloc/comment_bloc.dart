import 'package:equatable/equatable.dart';
import 'package:bloc/bloc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';

part 'comment_bloc.g.dart';
part 'comment_event.dart';
part 'comment_state.dart';

class CommentBloc extends Bloc<CommentEvent, CommentState> {
  CommentBloc({
    required String commentId,
    required PostsRepository postsRepository,
  }) : _commentId = commentId,
       _postsRepository = postsRepository,
       super(const CommentState.initial()) {
    on<CommentStatsSubscriptionRequested>(
      _onCommentStatsSubscriptionRequested,
      transformer: throttleDroppable(),
    );
    on<CommentsRepliedCommentsSubscriptionRequested>(
      _onCommentsRepliedCommentsSubscriptionRequested,
      transformer: throttleDroppable(),
    );
    on<CommentLikeRequested>(_onCommentLikeRequested);
    on<CommentDeleteRequested>(_onCommentDeleteRequested);
  }

  final String _commentId;
  final PostsRepository _postsRepository;

  /// The comment this bloc is for.
  String get id => _commentId;

  Future<void> _onCommentLikeRequested(
    CommentLikeRequested event,
    Emitter<CommentState> emit,
  ) async {
    try {
      await _postsRepository.like(id: id, post: false);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  Future<void> _onCommentDeleteRequested(
    CommentDeleteRequested event,
    Emitter<CommentState> emit,
  ) async {
    try {
      await _postsRepository.deleteComment(id: id);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  /// One shared query for every comment on screen (CommentStatsHub); each
  /// comment used to open three of its own.
  Future<void> _onCommentStatsSubscriptionRequested(
    CommentStatsSubscriptionRequested event,
    Emitter<CommentState> emit,
  ) async {
    await emit.forEach(
      _postsRepository.commentStatsOfComment(commentId: id),
      onData: (stats) => state.copyWith(
        likes: stats.likes,
        isLiked: stats.isLiked,
        isLikedByOwner: stats.isLikedByPostAuthor,
      ),
      onError: (error, stackTrace) {
        addError(error, stackTrace);
        return state.copyWith(status: CommentStatus.failure);
      },
    );
  }

  Future<void> _onCommentsRepliedCommentsSubscriptionRequested(
    CommentsRepliedCommentsSubscriptionRequested event,
    Emitter<CommentState> emit,
  ) async {
    await emit.forEach(
      _postsRepository.repliedCommentsOf(commentId: event.commentId),
      onData: (repliedComments) =>
          state.copyWith(repliedComments: repliedComments),
      onError: (error, stackTrace) {
        addError(error, stackTrace);
        return state.copyWith(status: CommentStatus.failure);
      },
    );
  }

}
