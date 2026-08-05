import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
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
    final capturedPath = await StoryCameraPage.push(context);
    if (capturedPath == null || !context.mounted) return;

    final discarded = await context.pushNamed<Object?>(
      AppRoutes.createStories.name,
      extra: CreateStoryProps(
        initialMediaPath: capturedPath,
        onDone: (String path) async {
          // Stories post straight away — no location step (posts still ask).
          if (!context.mounted) return;
          context.read<CreateStoriesBloc>().add(
            CreateStoriesStoryCreateRequested(
              author: author,
              contentType: StoryContentType.image,
              filePath: path,
              onError: (_, _) {
                toggleLoadingIndeterminate(enable: false);
                openSnackbar(
                  SnackbarMessage.error(
                    title: context.l10n.somethingWentWrongText,
                    description: context.l10n.failedToCreateStoryText,
                  ),
                );
              },
              onLoading: toggleLoadingIndeterminate,
              onStoryCreated: () {
                toggleLoadingIndeterminate(enable: false);
                openSnackbar(
                  SnackbarMessage.success(
                    title: context.l10n.successfullyCreatedStoryText,
                  ),
                  clearIfQueue: true,
                );
              },
            ),
          );
          if (context.canPop()) context.pop();
        },
      ),
    );
    if (discarded != true) return;
  }
}
