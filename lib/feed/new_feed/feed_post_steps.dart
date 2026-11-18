import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The new feed's (a prototype) buttons to the next post and the one before,
/// at the right of the line under each post, where the save button was: the
/// down arrow on every post, the up arrow beside it from the second post on.
/// Each scrolls the feed so that post's top is at the top of the list.
class FeedPostSteps extends StatelessWidget {
  const FeedPostSteps({required this.first, super.key});

  /// The feed's first post: nothing above it to go to.
  final bool first;

  static const double _size = 40;

  /// The arrow (it had a 26 one on a grey disc).
  static const double _icon = 34;
  static const _duration = Duration(milliseconds: 350);

  /// Scrolls the feed [context] is in to the post after the one [context] is
  /// in ([down]) or the one before.
  static Future<void> step(BuildContext context, {required bool down}) async {
    final position = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    // The post: the list's own child that holds [context].
    var post = context.findRenderObject();
    var list = post?.parent;
    while (list != null && list is! RenderSliverMultiBoxAdaptor) {
      post = list;
      list = list.parent;
    }
    if (position == null ||
        list is! RenderSliverMultiBoxAdaptor ||
        post is! RenderBox) {
      return;
    }
    final viewport = RenderAbstractViewport.maybeOf(post);
    if (viewport == null) return;
    final here = viewport.getOffsetToReveal(post, 0).offset;

    Future<void> to(double offset, Duration duration) => position.animateTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: duration,
      curve: Curves.easeInOutCubic,
    );

    if (down) {
      // The next post starts where this one ends.
      return to(here + post.size.height, _duration);
    }
    var before = list.childBefore(post);
    if (before == null) {
      // The one before is far above, not built: up to this post's top first,
      // which brings it in, then on to its top.
      await to(here, _duration ~/ 2);
      if (!post.attached || !list.attached) return;
      before = list.childBefore(post);
      if (before == null) return;
    }
    await to(viewport.getOffsetToReveal(before, 0).offset, _duration);
  }

  Widget _button(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required bool down,
  }) => Tappable.scaled(
    key: key,
    onTap: () => unawaited(step(context, down: down)),
    // The arrow alone, on nothing; the box around it takes the tap.
    child: SizedBox(
      width: _size,
      height: _size,
      child: Icon(icon, color: AppColors.white, size: _icon),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!first) ...[
          _button(
            context,
            key: const ValueKey('feedPostUp'),
            icon: Icons.keyboard_arrow_up_rounded,
            down: false,
          ),
          const Gap.h(AppSpacing.xs),
        ],
        _button(
          context,
          key: const ValueKey('feedPostDown'),
          icon: Icons.keyboard_arrow_down_rounded,
          down: true,
        ),
      ],
    );
  }
}
