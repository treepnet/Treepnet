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
    this.onStoryCreated,
    this.onError,
    this.onLoading,
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

  final VoidCallback? onStoryCreated;
  final VoidCallback? onLoading;
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
