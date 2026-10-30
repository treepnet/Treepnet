part of 'create_stories_bloc.dart';

sealed class CreateStoriesEvent extends Equatable {
  const CreateStoriesEvent();

  @override
  List<Object?> get props => [];
}

final class CreateStoriesStoryCreateRequested extends CreateStoriesEvent {
  const CreateStoriesStoryCreateRequested({
    required this.author,
    required this.contentType,
    required this.filePath,
    this.onError,
    this.duration,
    this.locationName,
    this.locationLat,
    this.locationLng,
  });

  final User author;
  final StoryContentType contentType;
  final String filePath;
  final int? duration;

  /// Optional place the story is pinned to. Survives the story's 24h expiry so
  /// the pin remains on the map.
  final String? locationName;
  final double? locationLat;
  final double? locationLng;

  /// The story couldn't even be saved to the phone. Later failures show in
  /// the feed's "Posting…" banner, which offers Retry / Cancel.
  final void Function(Object?, StackTrace?)? onError;

  @override
  List<Object?> get props => [
    author,
    contentType,
    filePath,
    duration,
    locationName,
    locationLat,
    locationLng,
  ];
}
