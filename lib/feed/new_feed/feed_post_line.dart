import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart' show TimeAgo;
import 'package:shared/shared.dart';
import 'package:treepnet/feed/new_feed/feed_post_globe.dart';
import 'package:treepnet/feed/new_feed/feed_post_steps.dart';

/// The line under a post's globe (the new feed and Trends' Maps tab): the
/// arrows to the next post and the one before at its right, and, on the new
/// feed, at their left the post's description — its first line stopping
/// short of the arrows, the rest under it the line's full width — or, with
/// no description, when it was posted. Trends has the arrows alone.
class FeedPostLine extends StatelessWidget {
  const FeedPostLine({
    required this.block,
    required this.mode,
    this.postIndex,
    super.key,
  });

  final PostBlock block;
  final FeedGlobeMode mode;

  /// The post's place in its list (no arrows without one).
  final int? postIndex;

  /// Between the description's first line and the arrows.
  static const double _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final steps = switch (postIndex) {
      final index? => FeedPostSteps(
        first: index == 0,
        // Trends lines them up under the globe's buttons.
        underGlobeButtons: mode.photosOnPins,
      ),
      null => null,
    };
    final caption = block.caption.trim();
    if (mode.showCaption && caption.isNotEmpty) {
      return _flowing(context, caption, steps);
    }
    // No description: when it was posted, level with the arrows (not for a
    // sponsored post, as under any post); on Trends, nothing.
    final time = mode.showCaption && block is! PostSponsoredBlock;
    return Row(
      children: [
        Expanded(
          child: time
              ? ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: FeedPostSteps.height,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TimeAgo(createdAt: block.createdAt),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        ?steps,
      ],
    );
  }

  /// The description around the arrows: its first line (as it breaks at
  /// the width beside them) level with them, the rest from under that line
  /// across the whole width.
  Widget _flowing(BuildContext context, String caption, FeedPostSteps? steps) {
    final style = DefaultTextStyle.of(context).style.merge(context.bodyMedium);
    // Measured as the Text below draws it: bold with the phone's Bold Text
    // on, in the app's language.
    final measured = MediaQuery.boldTextOf(context)
        ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
        : style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final beside = steps == null
            ? width
            : math.max<double>(
                0,
                width - FeedPostSteps.widthOf(first: steps.first) - _gap,
              );
        final painter = TextPainter(
          text: TextSpan(text: caption, style: measured),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        )..layout(maxWidth: beside);
        final end = painter
            .getLineBoundary(const TextPosition(offset: 0))
            .end
            .clamp(1, caption.length);
        final lineHeight = painter.computeLineMetrics().first.height;
        painter.dispose();
        final first = caption.substring(0, end).trimRight();
        final rest = caption.substring(end).trimLeft();
        return SizedBox(
          width: width,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: FeedPostSteps.height),
            child: Stack(
              children: [
                Padding(
                  // The first line level with the arrows' middle.
                  padding: EdgeInsets.only(
                    top: math.max(0, (FeedPostSteps.height - lineHeight) / 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: beside,
                        child: Text(
                          first,
                          key: const ValueKey('feedPostCaptionFirst'),
                          style: style,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      if (rest.isNotEmpty)
                        Text(
                          rest,
                          key: const ValueKey('feedPostCaptionRest'),
                          style: style,
                        ),
                    ],
                  ),
                ),
                if (steps != null) Positioned(top: 0, right: 0, child: steps),
              ],
            ),
          ),
        );
      },
    );
  }
}
