import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/feed/new_feed/feed_post_globe.dart';
import 'package:treepnet/feed/post/post.dart';
import 'package:treepnet/feed/widgets/widgets.dart';
import 'package:treepnet/timeline/timeline.dart';

/// Trends' Maps tab (a prototype): Trends' posts, each on its author's
/// globe as in the new feed (the photos on the pins, the arrows to the next
/// post and the one before under it) — not in Trends' rating order but
/// mixed, as recommendations: the same person's posts never one after
/// another while someone else's can come between. Scrolled by the arrows
/// only, so a drag is always the globe's; the next page comes in as the
/// last post's down arrow reaches the end, mixed in after the posts already
/// there (which keep their places).
class TimelineMapsView extends StatefulWidget {
  const TimelineMapsView({
    required this.scrollController,
    @visibleForTesting this.random,
    super.key,
  });

  /// Back to the top when the Trends tab is tapped again.
  final ScrollController scrollController;

  /// The mix's dice (a fixed one in tests).
  final math.Random? random;

  /// How many of the last posts' people a new post avoids, when it can.
  @visibleForTesting
  static const spread = 3;

  @override
  State<TimelineMapsView> createState() => _TimelineMapsViewState();
}

class _TimelineMapsViewState extends State<TimelineMapsView> {
  late final _random = widget.random ?? math.Random();

  /// The posts' order on this tab, by id: kept as more pages come (a post
  /// already shown never moves), one gone from Trends dropped.
  final _order = <String>[];

  /// [blocks] (Trends' posts, its order) in this tab's order: the ones
  /// already placed where they are, the new ones after them — shuffled, then
  /// placed one by one, each by someone none of the last
  /// [TimelineMapsView.spread] posts are by (or as few as can be); of those,
  /// someone with the most posts still to place, so a person with many isn't
  /// left with them all together at the end.
  List<PostBlock> _mixed(List<PostBlock> blocks) {
    final byId = {for (final block in blocks) block.id: block};
    _order.removeWhere((id) => !byId.containsKey(id));
    final placed = _order.toSet();
    final fresh = [
      for (final block in blocks)
        if (!placed.contains(block.id)) block,
    ]..shuffle(_random);
    final recent = [
      for (final id in _order.reversed.take(TimelineMapsView.spread))
        byId[id]!.author.id,
    ];
    final left = <String, int>{};
    for (final block in fresh) {
      left[block.author.id] = (left[block.author.id] ?? 0) + 1;
    }

    /// Of [fresh], the first by whoever has the most left, not by [avoid].
    int pickAvoiding(Set<String> avoid) {
      var best = -1;
      for (var i = 0; i < fresh.length; i++) {
        final author = fresh[i].author.id;
        if (avoid.contains(author)) continue;
        if (best < 0 || left[author]! > left[fresh[best].author.id]!) best = i;
      }
      return best;
    }

    while (fresh.isNotEmpty) {
      var pick = -1;
      for (var window = recent.length; window > 0 && pick < 0; window--) {
        pick = pickAvoiding(recent.take(window).toSet());
      }
      if (pick < 0) pick = pickAvoiding(const {});
      final block = fresh.removeAt(pick);
      left[block.author.id] = left[block.author.id]! - 1;
      _order.add(block.id);
      recent.insert(0, block.author.id);
      if (recent.length > TimelineMapsView.spread) recent.removeLast();
    }
    return [for (final id in _order) byId[id]!];
  }

  @override
  Widget build(BuildContext context) {
    return FeedGlobeMode(
      // The arrows alone under each post: no place line, no description
      // (the grid's posts keep theirs).
      showPlace: false,
      showCaption: false,
      child: CustomScrollView(
        controller: widget.scrollController,
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          BlocBuilder<TimelineBloc, TimelineState>(
            buildWhen: (previous, current) =>
                previous.status != current.status ||
                previous.timeline.hasMore != current.timeline.hasMore ||
                !const ListEquality<InstaBlock>().equals(
                  previous.timeline.blocks,
                  current.timeline.blocks,
                ),
            builder: (context, state) {
              final blocks = _mixed(
                state.timeline.blocks.whereType<PostBlock>().toList(),
              );
              if (blocks.isEmpty) {
                if (state.status.isFailure) return const TimelineError();
                if (state.status.isPopulated && !state.timeline.hasMore) {
                  return const TimelineEmpty();
                }
                return const SliverToBoxAdapter(
                  child: Column(
                    children: [
                      FeedLoadingBlock(),
                      Gap.v(AppSpacing.md),
                      FeedLoadingBlock(),
                    ],
                  ),
                );
              }
              return SliverList.builder(
                // +1: the end of the list, where the next page is asked for.
                itemCount: blocks.length + 1,
                itemBuilder: (context, index) {
                  if (index == blocks.length) {
                    return _MapsEnd(state: state);
                  }
                  final block = blocks[index];
                  return PostView(
                    key: ValueKey(block.id),
                    block: block,
                    postIndex: index,
                    // Its globe in place of the media: no video to play.
                    withInViewNotifier: false,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// After the last post: the next page asked for as it comes into view, a
/// Retry for a failed one, nothing once every post is in.
class _MapsEnd extends StatelessWidget {
  const _MapsEnd({required this.state});

  final TimelineState state;

  @override
  Widget build(BuildContext context) {
    void next() =>
        context.read<TimelineBloc>().add(const TimelinePageRequested());
    if (state.status.isFailure) return PageLoadRetry(onRetry: next);
    if (!state.timeline.hasMore) return const SizedBox(height: AppSpacing.xxlg);
    return FeedLoaderItem(
      // A new item each page, so it asks again for the next one.
      key: ValueKey('mapsEnd:${state.timeline.page}'),
      onPresented: next,
    );
  }
}
