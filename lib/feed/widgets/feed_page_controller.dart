import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/feed/post/video/video.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/app/services/media_upload_queue.dart';
import 'package:treepnet/monitoring/crash_reporter.dart';
import 'package:user_repository/user_repository.dart';

class FeedPageController extends ChangeNotifier {
  factory FeedPageController() => _internal;

  FeedPageController._();

  static final FeedPageController _internal = FeedPageController._();

  /// The Posts tab's scroll view (FeedBody), the Stories grid's, and the
  /// feed's tab switch — registered by the feed while it is on screen.
  ScrollController? _postsScroll;
  ScrollController? _storiesScroll;
  int Function()? _currentTab;
  void Function(int tab)? _showTab;
  late BuildContext _context;

  void init({
    required ScrollController nestedScrollController,
    required BuildContext context,
    int Function()? currentTab,
    void Function(int tab)? showTab,
  }) {
    _postsScroll = nestedScrollController;
    _context = context;
    _currentTab = currentTab;
    _showTab = showTab;
  }

  /// The feed went away with [nestedScrollController]: forget it.
  void detach(ScrollController nestedScrollController) {
    if (_postsScroll != nestedScrollController) return;
    _postsScroll = null;
    _currentTab = null;
    _showTab = null;
  }

  /// The Stories grid's scroll view, while it is built.
  void attachStoriesScroll(ScrollController controller) =>
      _storiesScroll = controller;

  void detachStoriesScroll(ScrollController controller) {
    if (_storiesScroll == controller) _storiesScroll = null;
  }

  bool _hasPlayedAnimation = false;
  double _animationValue = 0;

  bool get hasPlayedAnimation => _hasPlayedAnimation;
  set hasPlayedAnimation(bool value) {
    _hasPlayedAnimation = value;
    notifyListeners();
  }

  double get animationValue => _animationValue;
  set animationValue(double value) {
    _animationValue = value;
    notifyListeners();
  }

  void markAnimationAsUnseen() {
    _hasPlayedAnimation = false;
    _animationValue = 0;
    notifyListeners();
  }

  /// The Feed tab tapped again: the tab on screen (Posts or Stories) goes
  /// back to its top. The posts' controller used to be attached to nothing,
  /// so this never did anything.
  void scrollToTop() {
    final onStories = (_currentTab?.call() ?? 0) == 1;
    _animateToTop(onStories ? _storiesScroll : _postsScroll);
  }

  /// After sharing a post: the Posts tab at its top, where the "Posting…"
  /// banner and then the new post are. It used to stay wherever the reader
  /// was, so it looked as if nothing had happened.
  void showNewPost() {
    _showTab?.call(0);
    _animateToTop(_postsScroll);
  }

  void _animateToTop(ScrollController? controller) {
    // Not built yet (e.g. the Feed tab tapped from another tab first), or
    // gone: nothing to scroll. animateTo with no clients would assert.
    if (controller == null || !controller.hasClients) return;
    controller.animateTo(0, duration: 250.ms, curve: Curves.ease);
  }

  /// Publishes a new post. The picked files and the post are saved to the
  /// phone first ([MediaUploadQueue.startPost]), so it survives the app being
  /// closed; the queue then compresses, uploads and creates it, and the feed's
  /// "Posting…" banner follows its progress.
  Future<void> processPostMedia({
    required List<SelectedByte> selectedFiles,
    required String postId,
    required String caption,
    required bool pickVideo,
    String? location,
    String? locationCountry,
    String? locationRegion,
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) async {
    final queue = _context.read<MediaUploadQueue>();
    final userId = _context.read<UserRepository>().currentUserId;
    final failedText = _context.l10n.failedToCreatePostText;

    final isReel =
        selectedFiles.length == 1 && selectedFiles.every((e) => !e.isThatImage);
    final navigateToReelPage = isReel;
    StatefulNavigationShell.of(
      _context,
    ).goBranch(navigateToReelPage ? 3 : 0, initialLocation: true);
    if (pickVideo) {
      VideoPlayerInheritedWidget.of(_context).videoPlayerState.playReels();
    }

    try {
      if (userId == null) throw StateError('Not signed in');
      await queue.startPost(
        postId: postId,
        userId: userId,
        caption: caption,
        files: [
          for (final file in selectedFiles)
            PostSourceFile(
              bytes: file.selectedByte,
              path: file.selectedFile.path,
              isVideo: !file.isThatImage,
            ),
        ],
        location: location,
        locationCountry: locationCountry,
        locationRegion: locationRegion,
        locationName: locationName,
        locationLat: locationLat,
        locationLng: locationLng,
      );
    } catch (error, stackTrace) {
      logE('Failed to queue post', error: error, stackTrace: stackTrace);
      CrashReporter.instance.report(error, stackTrace, kind: 'post-queue');
      openSnackbar(SnackbarMessage.error(title: failedText));
    }
  }
}
