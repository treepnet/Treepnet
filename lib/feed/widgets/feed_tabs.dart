import 'package:flutter/widgets.dart';
import 'package:treepnet/feed/post/video/widgets/video_player_inherited_widget.dart';

/// {@template feed_keep_alive_tab}
/// One tab of the feed's Posts | Stories pager, kept alive while the other is
/// shown. A PageView drops an off-screen page, so going to Stories and back
/// threw the posts away: the list jumped to the top and every card rebuilt
/// and fetched its counts again (the Stories grid reloaded the same way).
/// {@endtemplate}
class FeedKeepAliveTab extends StatefulWidget {
  /// {@macro feed_keep_alive_tab}
  const FeedKeepAliveTab({required this.child, super.key});

  /// The tab's content.
  final Widget child;

  @override
  State<FeedKeepAliveTab> createState() => _FeedKeepAliveTabState();
}

class _FeedKeepAliveTabState extends State<FeedKeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Feed videos play only while the Posts tab is the one shown. The posts stay
/// alive behind Stories now ([FeedKeepAliveTab]), and their "in view" check
/// goes by the list's own scroll, so a video there would keep playing (with
/// sound) out of sight. Whatever turns feed playback on while Stories is open
/// (the bottom bar, the home pager) is undone at once.
class FeedTabsVideoGate {
  /// Watches [state]'s feed playback; call [dispose] when done.
  FeedTabsVideoGate(this.state) {
    state.shouldPlayFeed.addListener(_keepQuietOffPosts);
  }

  /// The app's video playback switches.
  final VideoPlayerState state;

  int _tab = 0;

  /// 0 = Posts, 1 = Stories.
  void tabChanged(int tab) {
    _tab = tab;
    if (tab == 0) {
      state.playFeed();
    } else {
      state.shouldPlayFeed.value = false;
    }
  }

  void _keepQuietOffPosts() {
    if (_tab != 0 && state.shouldPlayFeed.value) {
      state.shouldPlayFeed.value = false;
    }
  }

  /// Stops watching.
  void dispose() => state.shouldPlayFeed.removeListener(_keepQuietOffPosts);
}
