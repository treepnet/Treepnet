import 'dart:async';

import 'package:flutter/widgets.dart';

/// Taps on the bottom bar's tab that is already showing. Its page goes back
/// to its top, as the feed does (FeedPageController.scrollToTop).
abstract final class TabReselect {
  static final _taps = StreamController<int>.broadcast();

  /// The index of each tab tapped while it was the one showing.
  static Stream<int> get taps => _taps.stream;

  static void tapped(int index) => _taps.add(index);

  /// Listens for taps on tab [index] and scrolls [controller] to its top.
  static StreamSubscription<int> scrollToTopOn(
    int index,
    ScrollController Function() controller,
  ) => taps.where((tab) => tab == index).listen((_) {
    final scroll = controller();
    if (!scroll.hasClients) return;
    scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.ease,
    );
  });
}
