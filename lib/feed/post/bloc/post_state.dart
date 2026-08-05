part of 'post_bloc.dart';

enum PostStatus { initial, loading, success, failure }

@JsonSerializable()
class PostState extends Equatable {
  const PostState({
    required this.status,
    required this.likes,
    required this.likers,
    required this.commentsCount,
    required this.isLiked,
    required this.isOwner,
    this.isBookmarked = false,
    this.likersInFollowings,
    this.isFollowed,
  });

  factory PostState.fromJson(Map<String, dynamic> json) =>
      _$PostStateFromJson(json);

  const PostState.initial()
    : this(
        status: PostStatus.initial,
        likes: 0,
        likers: const [],
        commentsCount: 0,
        isLiked: false,
        isOwner: false,
      );

  final PostStatus status;
  final int likes;
  final List<User> likers;
  final List<User>? likersInFollowings;
  final int commentsCount;
  final bool isLiked;
  final bool isOwner;
  final bool isBookmarked;
  final bool? isFollowed;

  Map<String, dynamic> toJson() => _$PostStateToJson(this);

  @override
  List<Object?> get props => [
    status,
    likes,
    isLiked,
    likers,
    likersInFollowings,
    commentsCount,
    isOwner,
    isBookmarked,
    isFollowed,
  ];

  PostState copyWith({
    PostStatus? status,
    int? likes,
    List<User>? likers,
    List<User>? likersInFollowings,
    int? commentsCount,
    bool? isLiked,
    bool? isOwner,
    bool? isBookmarked,
    bool? isFollowed,
  }) {
    return PostState(
      status: status ?? this.status,
      likes: likes ?? this.likes,
      likers: likers ?? this.likers,
      likersInFollowings: likersInFollowings ?? this.likersInFollowings,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isOwner: isOwner ?? this.isOwner,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isFollowed: isFollowed ?? this.isFollowed,
    );
  }
}
