import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/app/services/media_upload_queue.dart';
import 'package:user_repository/user_repository.dart';

part 'create_stories_event.dart';
part 'create_stories_state.dart';

class CreateStoriesBloc extends Bloc<CreateStoriesEvent, CreateStoriesState> {
  CreateStoriesBloc({required MediaUploadQueue mediaUploadQueue})
    : _mediaUploadQueue = mediaUploadQueue,
      super(const CreateStoriesState.initial()) {
    on<CreateStoriesStoryCreateRequested>(
      _onStoryCreateRequested,
      // One after another: a story shared while the previous one is still
      // being saved waits its turn instead of being dropped. (The editor
      // reports each story once, however often its button is tapped.)
      transformer: sequential(),
    );
  }

  final MediaUploadQueue _mediaUploadQueue;

  Future<void> _onStoryCreateRequested(
    CreateStoriesStoryCreateRequested event,
    Emitter<CreateStoriesState> emit,
  ) async {
    try {
      // Saved to the phone before anything is compressed or uploaded, so the
      // story survives the app being closed. The queue compresses, uploads
      // and creates it; the feed's banner shows its progress.
      await _mediaUploadQueue.startStory(
        storyId: uuid.v4(),
        userId: event.author.id,
        filePath: event.filePath,
        contentType: event.contentType.toJson(),
        duration: event.duration,
        locationName: event.locationName,
        locationLat: event.locationLat,
        locationLng: event.locationLng,
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      event.onError?.call(error, stackTrace);
    }
  }
}
