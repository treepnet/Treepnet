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

/// The circular highlight covers under a profile's bio.
///
/// The owner's "New" tile used to lead the row; it was removed by request, so
/// nothing currently opens [showCreateHighlightSheet] — that entry point is
/// coming back somewhere else. The sheet itself is kept for it.
class StoryHighlightsRow extends StatelessWidget {
  const StoryHighlightsRow({required this.userId, required this.isOwner, super.key});

  final String userId;
  final bool isOwner;

  static const _size = 66.0;

  @override
  Widget build(BuildContext context) {
    final stories = context.read<StoriesRepository>();

    return StreamBuilder<List<StoryHighlight>>(
      stream: stories.storyHighlightsOf(userId: userId),
      builder: (context, snapshot) {
        // Only highlights that still hold at least one story. A highlight whose
        // last story was unpinned keeps its row in the DB but has no items, so
        // it must vanish from the profile rather than show an empty, dead cover.
        final highlights = (snapshot.data ?? const <StoryHighlight>[])
            .where((h) => h.storyCount > 0)
            .toList(growable: false);
        // Nothing to show: keep the profile compact. With the "New" tile gone
        // this now applies to the owner too — an empty row would be a blank
        // gap under the bio.
        if (highlights.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                for (final (index, highlight) in highlights.indexed) ...[
                  _HighlightCircle(
                    highlight: highlight,
                    isOwner: isOwner,
                    highlights: highlights,
                    index: index,
                  ),
                  const Gap.h(AppSpacing.md),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HighlightCircle extends StatelessWidget {
  const _HighlightCircle({
    required this.highlight,
    required this.isOwner,
    required this.highlights,
    required this.index,
  });

  final StoryHighlight highlight;
  final bool isOwner;

  /// The whole row, so the viewer can play on into the next cover.
  final List<StoryHighlight> highlights;
  final int index;

  @override
  Widget build(BuildContext context) {
    final stories = context.read<StoriesRepository>();
    final cover = highlight.coverUrl;

    return Tappable.scaled(
      onTap: () async {
        // Highlights play through the normal story viewer.
        final items = await stories
            .highlightStoriesOf(highlightId: highlight.id)
            .first;
        if (items.isEmpty || !context.mounted) return;
        await context.pushNamed(
          AppRoutes.stories.name,
          pathParameters: {'user_id': highlight.userId},
          extra: StoriesProps(
            stories: items,
            author: items.first.author,
            continuation: nextHighlightContinuation(
              storiesRepository: stories,
              highlights: highlights,
              fromIndex: index,
            ),
          ),
        );
      },
      onLongPress: !isOwner
          ? null
          : () => context.confirmAction(
              title: context.l10n.highlightDeleteTitle,
              yesText: context.l10n.deleteText,
              noText: context.l10n.cancelText,
              yesTextStyle: const TextStyle(color: AppColors.red),
              fn: () => stories.deleteStoryHighlight(highlightId: highlight.id),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: StoryHighlightsRow._size,
            height: StoryHighlightsRow._size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderOutline),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: cover == null || cover.isEmpty
                  ? const ColoredBox(color: AppColors.dark)
                  : CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      memCacheHeight: 200,
                      placeholder: (_, _) =>
                          const ColoredBox(color: AppColors.dark),
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: AppColors.dark),
                    ),
            ),
          ),
          const Gap.v(AppSpacing.xs),
          SizedBox(
            width: StoryHighlightsRow._size + 8,
            child: Text(
              highlight.name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.bodySmall?.copyWith(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet that names a highlight and picks which of your stories go into it.
Future<void> showCreateHighlightSheet(
  BuildContext context, {
  required String userId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _CreateHighlightSheet(userId: userId),
);

class _CreateHighlightSheet extends StatefulWidget {
  const _CreateHighlightSheet({required this.userId});

  final String userId;

  @override
  State<_CreateHighlightSheet> createState() => _CreateHighlightSheetState();
}

class _CreateHighlightSheetState extends State<_CreateHighlightSheet> {
  final _name = TextEditingController();
  final _picked = <String>{};
  List<Story>? _stories;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Highlights can include expired stories, so this reads the live set *and*
    // the archive — `getStories` filters on `expires_at` and would otherwise
    // hide everything older than 24h.
    final repo = context.read<StoriesRepository>();
    final live = await repo.getStories(userId: widget.userId).first;
    final archived = await repo.archivedStoriesOf(userId: widget.userId).first;
    final all = [...live, ...archived]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) setState(() => _stories = all);
  }

  static String _shortDate(DateTime at) =>
      '${at.day}.${at.month.toString().padLeft(2, '0')}.${at.year}';

  Future<void> _save() async {
    final all = _stories ?? const <Story>[];
    final ordered = [
      for (final s in all)
        if (_picked.contains(s.id)) s,
    ];
    if (ordered.isEmpty) return;
    await context.read<StoriesRepository>().createStoryHighlight(
      userId: widget.userId,
      name: _name.text.trim().isEmpty
          ? context.l10n.highlightNewText
          : _name.text.trim(),
      storyIds: [for (final s in ordered) s.id],
      coverUrl: ordered.first.contentUrl,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final stories = _stories;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                context.l10n.highlightCreateTitle,
                style: context.titleLarge?.copyWith(color: AppColors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: AppTextField(
                textController: _name,
                filled: true,
                hintText: context.l10n.highlightNameHint,
                border: outlinedBorder(borderRadius: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.highlightPickStories,
                  style: context.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: switch (stories) {
                null => const Center(child: CircularProgressIndicator()),
                [] => Center(
                  child: Text(
                    context.l10n.highlightNoStories,
                    style: context.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                _ => GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        childAspectRatio: 0.7,
                      ),
                  itemCount: stories.length,
                  itemBuilder: (context, i) {
                    final story = stories[i];
                    final picked = _picked.contains(story.id);
                    return Tappable.scaled(
                      onTap: () => setState(() {
                        if (!_picked.remove(story.id)) _picked.add(story.id);
                      }),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: story.contentUrl,
                              fit: BoxFit.cover,
                              memCacheHeight: 300,
                              placeholder: (_, _) =>
                                  const ColoredBox(color: AppColors.dark),
                              errorWidget: (_, _, _) =>
                                  const ColoredBox(color: AppColors.dark),
                            ),
                          ),
                          if (picked)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.blue,
                                  width: 3,
                                ),
                              ),
                              child: const Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: AppColors.blue,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                _shortDate(story.createdAt),
                                style: context.labelSmall?.copyWith(
                                  color: AppColors.white,
                                  fontSize: 9,
                                  shadows: const [
                                    Shadow(
                                      color: AppColors.black,
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              },
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: Tappable.scaled(
                  onTap: _picked.isEmpty ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: _picked.isEmpty
                          ? AppColors.inputSpace
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                    ),
                    child: Center(
                      child: Text(
                        context.l10n.highlightSave,
                        style: context.labelLarge?.copyWith(
                          color: _picked.isEmpty
                              ? AppColors.textSecondary
                              : AppColors.black,
                          fontWeight: AppFontWeight.semiBold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
