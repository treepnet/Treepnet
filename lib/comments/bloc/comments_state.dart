part of 'comments_bloc.dart';

/// [initial]: the post's comments haven't arrived yet (the phone keeps them
/// only while, and for a while after, they are open). [populated]: they have.
/// [unavailable]: they didn't come in time — offline, or a very slow network;
/// they still show once they do.
enum CommentsStatus { initial, populated, unavailable, error }

@JsonSerializable()
class CommentsState extends Equatable {
  const CommentsState({required this.status, required this.comments});

  factory CommentsState.fromJson(Map<String, dynamic> json) =>
      _$CommentsStateFromJson(json);

  const CommentsState.initial()
    : this(status: CommentsStatus.initial, comments: const []);

  Map<String, dynamic> toJson() => _$CommentsStateToJson(this);

  final CommentsStatus status;
  final List<Comment> comments;

  @override
  List<Object> get props => [status, comments];

  CommentsState copyWith({CommentsStatus? status, List<Comment>? comments}) {
    return CommentsState(
      status: status ?? this.status,
      comments: comments ?? this.comments,
    );
  }
}
