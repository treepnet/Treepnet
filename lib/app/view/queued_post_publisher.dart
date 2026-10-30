import 'dart:convert';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/app/services/media_upload_queue.dart';
import 'package:treepnet/feed/feed.dart';
import 'package:user_repository/user_repository.dart';

/// Invisible widget that creates the posts and stories [MediaUploadQueue]
/// publishes, once their media are uploaded (see [PendingPost] and
/// [PendingStory]).
///
/// They go through the posts and stories repositories, so a post lands at the
/// top of the feed, and both show the usual "created" message.
class QueuedPostPublisher extends StatefulWidget {
  const QueuedPostPublisher({super.key});

  @override
  State<QueuedPostPublisher> createState() => _QueuedPostPublisherState();
}

class _QueuedPostPublisherState extends State<QueuedPostPublisher> {
  late final MediaUploadQueue _queue;

  @override
  void initState() {
    super.initState();
    _queue = context.read<MediaUploadQueue>()
      ..attachPostCreator(_create)
      ..attachStoryCreator(_createStory);
  }

  Future<bool> _create(PendingPost post) async {
    if (!mounted) return false;
    // Only ever as its author: wait if another account is signed in.
    if (context.read<UserRepository>().currentUserId != post.userId) {
      return false;
    }
    final feedBloc = context.read<FeedBloc>();
    final created = await context.read<PostsRepository>().createPost(
      id: post.postId,
      caption: post.caption,
      media: json.encode(post.media),
      location: post.location,
      locationCountry: post.locationCountry,
      locationRegion: post.locationRegion,
      locationName: post.locationName,
      locationLat: post.locationLat,
      locationLng: post.locationLng,
    );
    if (created == null) return false;
    feedBloc.add(
      FeedUpdateRequested(
        update: FeedPageUpdate(newPost: created, type: PageUpdateType.create),
      ),
    );
    openSnackbar(
      SnackbarMessage.success(title: l10nGlobal.successfullyCreatedPostText),
    );
    return true;
  }

  Future<bool> _createStory(PendingStory story) async {
    if (!mounted) return false;
    final user = context.read<AppBloc>().state.user;
    // Only ever as its author: wait if another account is signed in.
    if (user.id != story.userId) return false;
    await context.read<StoriesRepository>().createStory(
      id: story.storyId,
      author: user,
      contentType: StoryContentType.values.byName(story.contentType),
      contentUrl: story.contentUrl!,
      duration: story.duration,
      locationName: story.locationName,
      locationLat: story.locationLat,
      locationLng: story.locationLng,
    );
    openSnackbar(
      SnackbarMessage.success(title: l10nGlobal.successfullyCreatedStoryText),
      clearIfQueue: true,
    );
    return true;
  }

  @override
  void dispose() {
    _queue
      ..detachPostCreator()
      ..detachStoryCreator();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
