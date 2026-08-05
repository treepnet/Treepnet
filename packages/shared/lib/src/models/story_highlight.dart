// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:equatable/equatable.dart';

/// {@template story_highlight}
/// A named, permanent collection of a user's stories, shown as a circular
/// cover on their profile. Stories keep their rows after the 24h window, so a
/// highlight still plays once the story itself has expired.
/// {@endtemplate}
class StoryHighlight extends Equatable {
  /// {@macro story_highlight}
  const StoryHighlight({
    required this.id,
    required this.userId,
    required this.name,
    this.coverUrl,
    this.storyCount = 0,
  });

  factory StoryHighlight.fromRow(Map<String, dynamic> row) => StoryHighlight(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    name: row['name'] as String? ?? '',
    coverUrl: row['cover_url'] as String?,
    storyCount: (row['story_count'] as int?) ?? 0,
  );

  final String id;
  final String userId;
  final String name;

  /// Image shown in the circle — the first story's media when created.
  final String? coverUrl;

  /// How many stories the highlight holds.
  final int storyCount;

  @override
  List<Object?> get props => [id, userId, name, coverUrl, storyCount];
}
