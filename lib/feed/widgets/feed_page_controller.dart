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

  late ScrollController _nestedScrollController;
  late BuildContext _context;

  void init({
    required ScrollController nestedScrollController,
    required BuildContext context,
  }) {
    _nestedScrollController = nestedScrollController;
    _context = context;
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

  void scrollToTop() {
    // Tapping the Feed nav tab from another tab calls this before the feed's
    // scroll view is attached; animateTo on a controller with no clients trips
    // an assertion ("ScrollController not attached to any scroll views").
    // Nothing to scroll when it isn't attached, so just skip.
    if (!_nestedScrollController.hasClients) return;
    _nestedScrollController.animateTo(
      0,
      duration: 250.ms,
      curve: Curves.ease,
    );
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
