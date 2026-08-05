import 'package:app_ui/app_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/stories/stories.dart';

/// {@template story_archive_page}
/// Every story the author has posted, newest first — including the ones still
/// live in the feed, which land here the moment they upload. Only the author
/// ever sees this screen.
/// {@endtemplate}
class StoryArchivePage extends StatelessWidget {
  /// {@macro story_archive_page}
  const StoryArchivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AppBloc bloc) => bloc.state.user);

    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: AppColors.transparent,
        appBar: AppBar(
          backgroundColor: AppColors.transparent,
          surfaceTintColor: AppColors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            context.l10n.archiveText,
            style: context.titleMedium?.copyWith(
              fontWeight: AppFontWeight.semiBold,
            ),
          ),
        ),
        body: StreamBuilder<List<Story>>(
          stream: context.read<StoriesRepository>().archivedStoriesOf(
            userId: user.id,
          ),
          builder: (context, snapshot) {
            final stories = snapshot.data;
            if (stories == null) {
              return const Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            if (stories.isEmpty) return const _EmptyArchive();

            return GridView.builder(
              padding: EdgeInsets.zero,
              // The Trends/profile tile — a story tile is the same object as a
              // post tile, so the two grids match down to the gaps.
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 133 / 170,
              ),
              itemCount: stories.length,
              itemBuilder: (context, index) {
                final story = stories[index];
                return Tappable.scaled(
                  // Replays from the tapped story onwards, like the viewer.
                  onTap: () => context.pushNamed(
                    AppRoutes.stories.name,
                    pathParameters: {'user_id': story.author.id},
                    extra: StoriesProps(
                      stories: stories.sublist(index),
                      author: story.author,
                    ),
                  ),
                  // Square corners, like every other grid in the app.
                  child: RepaintBoundary(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: story.contentUrl,
                          fit: BoxFit.cover,
                          memCacheHeight: 400,
                          placeholder: (_, _) =>
                              const ColoredBox(color: AppColors.dark),
                          errorWidget: (_, _, _) =>
                              const ColoredBox(color: AppColors.dark),
                        ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              _shortDate(story.createdAt),
                              style: context.bodySmall?.copyWith(
                                color: AppColors.white,
                                shadows: const [
                                  Shadow(color: AppColors.black, blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  static String _shortDate(DateTime? at) {
    if (at == null) return '';
    return '${at.day}.${at.month.toString().padLeft(2, '0')}.${at.year}';
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.glassBackgroundLight,
              ),
              child: const Icon(
                Icons.history_rounded,
                color: AppColors.textSecondary,
                size: 46,
              ),
            ),
            const Gap.v(AppSpacing.lg),
            Text(
              context.l10n.noArchivedStoriesText,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap.v(AppSpacing.sm),
            Text(
              context.l10n.archiveHintText,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
