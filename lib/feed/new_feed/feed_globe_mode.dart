import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// How a list's posts show their author's travel globe in place of their
/// photos ([FeedGlobeMode]).
enum FeedGlobeStyle {
  /// The new feed: the post alone on the globe, as its small card (photo,
  /// buttons, an arrow down to its pin); its country and city in the
  /// globe's corner; its description beside the arrows under the globe.
  card,

  /// Trends' Maps tab: every post of the author as its small photo on its
  /// pin, any of them growing with its own buttons; the arrows alone under
  /// the globe.
  photos;

  /// Every post of the author on its pin, as its small photo.
  bool get photosOnPins => this == photos;

  /// The post's country and city on its globe, in the bottom left corner.
  bool get showPlace => this == card;

  /// The post's description beside the arrows under the globe, and its time.
  bool get showCaption => this == card;
}

/// Marks a list whose posts show their author's globe in place of their
/// photos (FeedPostGlobe): the new feed, and Trends' Maps tab. Posts
/// anywhere else are as ever.
class FeedGlobeMode extends InheritedWidget {
  const FeedGlobeMode({
    required super.child,
    this.style = FeedGlobeStyle.card,
    this.onScreen,
    this.viewportHeight,
    super.key,
  });

  final FeedGlobeStyle style;

  /// Whether the list is the one on screen (its tab shown, its feed picked):
  /// a grown card's video plays only then — it would play on, aloud, behind
  /// the other tab. Null: always on screen.
  final ValueListenable<bool>? onScreen;

  /// How tall the list's visible part is. On a screen too short for a whole
  /// post (its header, its 4:5 globe and the arrows under it), its globe is
  /// made as much shorter as that takes: the arrows, the list's only way
  /// on, would be off its bottom. Null: always 4:5.
  final double? viewportHeight;

  bool get photosOnPins => style.photosOnPins;
  bool get showPlace => style.showPlace;
  bool get showCaption => style.showCaption;

  /// The mode [context] is in, if any. Read once: a list keeps its mode.
  static FeedGlobeMode? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FeedGlobeMode>();

  /// The [viewportHeight] of the list [context] is in; [context] is built
  /// again when it changes.
  static double? viewportHeightOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<FeedGlobeMode>()
      ?.viewportHeight;

  @override
  bool updateShouldNotify(FeedGlobeMode oldWidget) =>
      style != oldWidget.style ||
      onScreen != oldWidget.onScreen ||
      viewportHeight != oldWidget.viewportHeight;
}
