import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which feed the Posts tab shows: the usual one, or the new one (the globe
/// side of the switch at the feed's top left). A prototype: the new feed is
/// still to be designed.
enum FeedMode {
  /// The usual feed.
  classic,

  /// The new feed.
  globe,
}

/// The feed the person picked, kept on this phone so it opens the same way
/// next time. The usual feed until something else is picked.
abstract final class FeedModeStore {
  static const _key = 'treepnet_feed_mode';

  /// The feed shown now.
  static final ValueNotifier<FeedMode> mode = ValueNotifier(FeedMode.classic);

  /// Reads the one picked before (quietly the usual feed if it can't).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mode.value = prefs.getString(_key) == FeedMode.globe.name
          ? FeedMode.globe
          : FeedMode.classic;
    } catch (_) {}
  }

  /// Shows [value] now and keeps it for next time.
  static Future<void> set(FeedMode value) async {
    mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value.name);
    } catch (_) {}
  }
}
