import 'dart:async';
import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/stories/bloc/create_stories_bloc.dart';
import 'package:treepnet/stories/view/story_camera_page.dart';
import 'package:user_repository/user_repository.dart';

/// What the editor route needs: where to start from, and what to do when done.
class CreateStoryProps {
  const CreateStoryProps({required this.onDone, this.initialMediaPath});

  /// Called with the rendered story's file path.
  final Future<void> Function(String) onDone;

  /// Picture the editor opens with, so it never shows the blank gradient.
  final String? initialMediaPath;
}

/// The "add a story" flow.
///
/// Every entry point — the Stories tab's Share button, the profile avatar, the
/// carousel ring — runs this, so they cannot drift apart.
///
/// Camera first, editor second: tapping "add a story" should show a viewfinder,
/// not an empty canvas.
Future<void> startStoryCreation(BuildContext context, User author) async {
  // Loops so that discarding in the editor returns to the viewfinder rather
  // than dumping the user back where they started.
  while (true) {
    final capture = await StoryCameraPage.push(context);
    if (capture == null) return;
    if (!context.mounted) {
      _forget(capture);
      return;
    }

    final Object? discarded;
    try {
      discarded = await _edit(context, author, capture.path);
    } finally {
      _forget(capture);
    }
    if (discarded != true) return;
  }
}

/// The camera's original (2-5 MB in the app's temporary folder) is not
/// needed once the editor is closed, posted or discarded: the editor exports
/// its own file. It was left there. A gallery photo is the user's: never.
void _forget(StoryCapture capture) {
  if (!capture.fromCamera) return;
  unawaited(File(capture.path).delete().then((_) {}, onError: (_) {}));
}

/// Opens the editor on [mediaPath]; completes with true when the user
/// discarded the story (back to the viewfinder).
Future<Object?> _edit(BuildContext context, User author, String mediaPath) =>
    context.pushNamed<Object?>(
      AppRoutes.createStories.name,
      extra: CreateStoryProps(
        initialMediaPath: mediaPath,
        onDone: (String path) async {
          // Stories post straight away — no location step (posts still ask).
          if (!context.mounted) return;
          context.read<CreateStoriesBloc>().add(
            CreateStoriesStoryCreateRequested(
              author: author,
              contentType: StoryContentType.image,
              filePath: path,
              onError: (_, _) {
                // This fires after the story request resolves — by then this
                // route has been popped (below) and `context` is deactivated,
                // so context.l10n would null-crash. Use the context-less
                // l10nGlobal, matching the global openSnackbar it feeds.
                openSnackbar(
                  SnackbarMessage.error(
                    title: l10nGlobal.somethingWentWrongText,
                    description: l10nGlobal.failedToCreateStoryText,
                  ),
                );
              },
            ),
          );
          if (context.canPop()) context.pop();
        },
      ),
    );
