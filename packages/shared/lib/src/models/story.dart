// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:user_repository/user_repository.dart';

enum StoryContentType {
  image,
  video;

  String toJson() => name;
  static StoryContentType fromJson(Map<String, dynamic> json) =>
      values.byName(json['content_type'] as String);
}

/// {@template story}
/// The representation of the Instagram user's `story` model.
/// {@endtemplate}
@immutable
class Story extends Equatable {
  /// {@macro story}
  const Story({
    required this.id,
    required this.contentUrl,
    required this.createdAt,
    required this.expiresAt,
    this.contentType = StoryContentType.image,
    this.duration,
    this.author = User.anonymous,
    this.seen = false,
    this.locationName,
    this.locationLat,
    this.locationLng,
  });

  /// Converts the `Map<String, dynamic>` into a [Story] instance.
  factory Story.fromJson(Map<String, dynamic> json) => Story(
    id: json['id'] as String,
    contentType: StoryContentType.fromJson(json),
    contentUrl: json['content_url'] as String,
    author: json['user_id'] == null ? User.anonymous : User.fromJson(json),
    duration: json['duration'] as int?,
    createdAt: DateTime.parse(json['created_at'] as String),
    expiresAt: DateTime.parse(json['expires_at'] as String),
    seen: json['seen'] as bool? ?? false,
    locationName: json['location_name'] as String?,
    locationLat: (json['location_lat'] as num?)?.toDouble(),
    locationLng: (json['location_lng'] as num?)?.toDouble(),
  );

  /// Builds a story from the flattened `shared_story_*` columns a chat message
  /// carries when a story was shared into a DM (see database_client messagesOf).
  factory Story.fromShared(Map<String, dynamic> row) => Story.fromJson({
    'id': row['shared_story_id'],
    'content_type': row['shared_story_content_type'],
    'content_url': row['shared_story_content_url'],
    'duration': row['shared_story_duration'],
    'created_at': row['shared_story_created_at'],
    'expires_at': row['shared_story_expires_at'],
    'user_id': row['shared_story_author_id'],
    'username': row['shared_story_author_username'],
    'full_name': row['shared_story_author_full_name'],
    'avatar_url': row['shared_story_author_avatar_url'],
  });

  /// The identifier of the story.
  final String id;

  /// The author of the story.
  final User author;

  /// The content type of the story.
  final StoryContentType contentType;

  /// The url to the content of the story.
  final String contentUrl;

  /// The duration of the story in seconds.
  final int? duration;

  /// The date time when the story was created.
  final DateTime createdAt;

  /// The date time when the story expires, commonly 1 day from [createdAt].
  final DateTime expiresAt;

  /// Whether the story was seen by the user.
  final bool seen;

  /// The human-readable name of the place the story is pinned to, if any.
  final String? locationName;

  /// The latitude of the story's location, if any. Kept after the story
  /// expires so the pin stays on the map.
  final double? locationLat;

  /// The longitude of the story's location, if any.
  final double? locationLng;

  /// Whether this story carries a valid map location.
  bool get hasLocation => locationLat != null && locationLng != null;

  /// Converts the [Story] instance into a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() => {
    'id': id,
    'content_type': contentType.toJson(),
    'content_url': contentUrl,
    if (!author.isAnonymous) 'author': author,
    if (duration != null) 'duration': duration,
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    'seen': seen,
    if (locationName != null) 'location_name': locationName,
    if (locationLat != null) 'location_lat': locationLat,
    if (locationLng != null) 'location_lng': locationLng,
  };

  static Story empty = Story(
    id: '',
    contentUrl: '',
    createdAt: DateTime.now(),
    expiresAt: DateTime.now(),
  );

  Story copyWith({
    String? id,
    User? author,
    StoryContentType? contentType,
    String? contentUrl,
    int? duration,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? seen,
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) => Story(
    id: id ?? this.id,
    author: author ?? this.author,
    contentType: contentType ?? this.contentType,
    contentUrl: contentUrl ?? this.contentUrl,
    duration: duration ?? this.duration,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    seen: seen ?? this.seen,
    locationName: locationName ?? this.locationName,
    locationLat: locationLat ?? this.locationLat,
    locationLng: locationLng ?? this.locationLng,
  );

  Story merge({
    required Story other,
    bool? seen,
  }) => copyWith(
    id: other.id,
    author: other.author,
    contentType: other.contentType,
    contentUrl: other.contentUrl,
    createdAt: other.createdAt,
    expiresAt: other.expiresAt,
    seen: seen,
  );

  @override
  List<Object?> get props => [
    id,
    contentType,
    contentUrl,
    createdAt,
    expiresAt,
    seen,
    locationName,
    locationLat,
    locationLng,
  ];
}
