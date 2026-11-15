import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'post_author.g.dart';

/// {@template post_author}
/// The representation of post author.
/// {@endtemplate}
@immutable
@JsonSerializable()
class PostAuthor {
  /// {@macro post_author}
  const PostAuthor({
    required this.id,
    required this.avatarUrl,
    required this.username,
    this.isConfirmed = false,
  });

  /// {@macro post_author.confirmed}
  const PostAuthor.confirmed({
    required String id,
    String? avatarUrl,
    String? username,
  }) : this(
         id: id,
         avatarUrl: avatarUrl ?? '',
         username: username ?? '',
         isConfirmed: true,
       );

  /// Deserialize [json] into a [PostAuthor] instance.
  factory PostAuthor.fromJson(Map<String, dynamic> json) =>
      _$PostAuthorFromJson(json);

  /// Deserialize [shared] into a [PostAuthor] instance.
  factory PostAuthor.fromShared(Map<String, dynamic> shared) => PostAuthor(
    id: shared['shared_post_author_id'] as String? ?? '',
    avatarUrl: shared['shared_post_author_avatar_url'] as String? ?? '',
    username:
        shared['shared_post_author_username'] as String? ??
        shared['shared_post_author_full_name'] as String? ??
        '',
  );

  /// The empty instance of the [PostAuthor].
  static const PostAuthor empty = PostAuthor(
    id: '',
    avatarUrl: '',
    username: '',
  );

  /// The identifier of the author.
  final String id;

  /// The author username.
  final String username;

  /// The author avatar url.
  final String avatarUrl;

  /// Whether the user is confirmed by the Instagram clone staff.
  final bool isConfirmed;

  /// Convert current instance to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() => _$PostAuthorToJson(this);
}
