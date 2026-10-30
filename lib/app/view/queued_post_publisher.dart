import 'dart:convert';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/app/services/media_upload_queue.dart';
import 'package:treepnet/feed/feed.dart';
import 'package:user_repository/user_repository.dart';

/// Invisible widget that creates the posts [MediaUploadQueue] publishes, once
/// all their media are uploaded (see [PendingPost]).
///
/// They go through the posts repository, so they land at the top of the feed
/// with the usual "posted" message.
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
    _queue = context.read<MediaUploadQueue>()..attachPostCreator(_create);
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

  @override
  void dispose() {
    _queue.detachPostCreator();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
