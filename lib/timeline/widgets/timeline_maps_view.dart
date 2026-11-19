import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/feed/new_feed/feed_globe_mode.dart';
import 'package:treepnet/feed/post/post.dart';
import 'package:treepnet/feed/widgets/widgets.dart';
import 'package:treepnet/timeline/timeline.dart';

/// Trends' Maps tab: Trends' posts, each on its author's globe as in the
/// new feed (the photos on the pins, the arrows to the next post and the
/// one before under it) — not in Trends' rating order but mixed, as
/// recommendations ([TrendsMix]). Scrolled by the arrows only, so a drag is
/// always the globe's; the next page comes in as the last post's down arrow
/// reaches the end, mixed in after the posts already there (which keep
/// their places).
class TimelineMapsView extends StatefulWidget {
  const TimelineMapsView({
    required this.scrollController,
    this.onScreen,
    @visibleForTesting this.random,
    super.key,
  });

  /// Back to the top when the Trends tab is tapped again.
  final ScrollController scrollController;

  /// Whether the tab is shown ([FeedGlobeMode.onScreen]).
  final ValueListenable<bool>? onScreen;

  /// The mix's dice (a fixed one in tests).
  final math.Random? random;

  /// How many of the last posts' people a new post avoids, when it can.
  @visibleForTesting
  static const spread = TrendsMix.spread;

  @override
  State<TimelineMapsView> createState() => _TimelineMapsViewState();
}

class _TimelineMapsViewState extends State<TimelineMapsView> {
  late final _mix = TrendsMix(random: widget.random ?? math.Random());

  /// Trends' posts as last mixed, and where each is (to keep a post's globe
  /// when one above it goes).
  List<PostBlock> _blocks = const [];
  Map<String, int> _indexOf = const {};

  void _remix(List<PostBlock> trends) {
    _blocks = _mix.order(trends);
    _indexOf = {for (final (i, block) in _blocks.indexed) block.id: i};
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _list(constraints.maxHeight),
    );
  }

  /// The list, [viewportHeight] tall (a post too tall for it gets a shorter
  /// globe, its arrows on screen).
  Widget _list(double viewportHeight) {
    return FeedGlobeMode(
      // Every post of the author on its pin, as its small photo; the arrows
      // alone under each post (the grid's posts keep their descriptions).
      style: FeedGlobeStyle.photos,
      onScreen: widget.onScreen,
      viewportHeight: viewportHeight,
      child: CustomScrollView(
        controller: widget.scrollController,
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          BlocBuilder<TimelineBloc, TimelineState>(
            buildWhen: (previous, current) =>
                previous.status != current.status ||
                previous.timeline.hasMore != current.timeline.hasMore ||
                // A page that brought nothing new still moves the end on.
                previous.timeline.page != current.timeline.page ||
                !const ListEquality<InstaBlock>().equals(
                  previous.timeline.blocks,
                  current.timeline.blocks,
                ),
            builder: (context, state) {
              _remix(state.timeline.blocks.whereType<PostBlock>().toList());
              final blocks = _blocks;
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
                // A post that goes (hidden, deleted) leaves the ones below
                // it as they were, globes turned and all.
                findChildIndexCallback: (key) =>
                    key is ValueKey<String> ? _indexOf[key.value] : null,
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

/// The Maps tab's order of Trends' posts: posts already placed keep their
/// places; new ones (a new page) are shuffled, then placed one by one, each
/// by someone none of the last [spread] posts are by (or as few as can be),
/// of those someone with the most posts still to place — so the same
/// person's posts never come one after another while someone else's can
/// come between (a pick that would leave that impossible is passed over).
/// Posts gone from Trends drop out.
class TrendsMix {
  TrendsMix({required math.Random random}) : _random = random;

  final math.Random _random;

  /// How many of the last posts' people a new post avoids, when it can.
  static const spread = 3;

  /// The posts' order, by id: kept as more pages come.
  final _order = <String>[];

  /// [trends] (Trends' posts, in its order) in this tab's order.
  List<PostBlock> order(List<PostBlock> trends) {
    final byId = {for (final block in trends) block.id: block};
    _order.removeWhere((id) => !byId.containsKey(id));
    final placed = _order.toSet();
    final fresh = [
      for (final block in trends)
        if (!placed.contains(block.id)) block,
    ]..shuffle(_random);
    if (fresh.isEmpty) return [for (final id in _order) byId[id]!];
    final recent = [
      for (final id in _order.reversed.take(spread)) byId[id]!.author.id,
    ];
    final left = <String, int>{};
    for (final block in fresh) {
      left[block.author.id] = (left[block.author.id] ?? 0) + 1;
    }

    /// Whether, [author]'s post placed next, the rest can still follow with
    /// no one's two in a row: no one with more than half of them (rounded
    /// up), [author] with no more than half (rounded down) — the next one
    /// can't be theirs.
    bool separableAfter(String author) {
      final rest = fresh.length - 1;
      for (final MapEntry(key: who, value: count) in left.entries) {
        final mine = who == author;
        final after = mine ? count - 1 : count;
        if (after > (mine ? rest ~/ 2 : (rest + 1) ~/ 2)) return false;
      }
      return true;
    }

    /// Of [fresh], the first by whoever has the most left, not by [avoid]
    /// ([separable]: nor one leaving the rest inseparable).
    int pick(Set<String> avoid, {required bool separable}) {
      var best = -1;
      for (var i = 0; i < fresh.length; i++) {
        final author = fresh[i].author.id;
        if (avoid.contains(author)) continue;
        if (best >= 0 && left[author]! <= left[fresh[best].author.id]!) {
          continue;
        }
        if (separable && !separableAfter(author)) continue;
        best = i;
      }
      return best;
    }

    while (fresh.isNotEmpty) {
      var at = -1;
      for (final separable in [true, false]) {
        for (var window = recent.length; window > 0 && at < 0; window--) {
          at = pick(recent.take(window).toSet(), separable: separable);
        }
        if (at >= 0) break;
      }
      if (at < 0) at = pick(const {}, separable: false);
      final block = fresh.removeAt(at);
      left[block.author.id] = left[block.author.id]! - 1;
      _order.add(block.id);
      recent.insert(0, block.author.id);
      if (recent.length > spread) recent.removeLast();
    }
    return [for (final id in _order) byId[id]!];
  }
}

/// After the last post: the next page asked for as it comes into view, a
/// Retry for a failed one, nothing once every post is in. A plain spinner
/// while Trends refreshes: a page asked for meanwhile would land on the
/// refreshed list.
class _MapsEnd extends StatelessWidget {
  const _MapsEnd({required this.state});

  final TimelineState state;

  @override
  Widget build(BuildContext context) {
    void next() =>
        context.read<TimelineBloc>().add(const TimelinePageRequested());
    if (state.status.isFailure) return PageLoadRetry(onRetry: next);
    if (!state.timeline.hasMore) return const SizedBox(height: AppSpacing.xxlg);
    if (state.status.isLoading) return const FeedLoaderItem();
    return FeedLoaderItem(
      // A new item each page, so it asks again for the next one.
      key: ValueKey('mapsEnd:${state.timeline.page}'),
      onPresented: next,
    );
  }
}
