// ignore_for_file: avoid_positional_boolean_parameters

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/chats/chats.dart';
import 'package:treepnet/feed/post/video/video.dart';
import 'package:treepnet/home/home.dart';
import 'package:treepnet/navigation/navigation.dart';
import 'package:treepnet/stories/stories.dart';
import 'package:treepnet/user_profile/user_profile.dart';
import 'package:go_router/go_router.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:user_repository/user_repository.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UserProfileBloc(
        userRepository: context.read<UserRepository>(),
        postsRepository: context.read<PostsRepository>(),
      ),
      lazy: false,
      child: HomeView(navigationShell: navigationShell),
    );
  }
}

/// {@template home_view}
/// Main view of the application. It contains the [navigationShell] that will
/// handle the navigation between the different bottom navigation bars.
/// {@endtemplate}
class HomeView extends StatefulWidget {
  /// {@macro home_view}
  const HomeView({required this.navigationShell, Key? key})
    : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  /// Navigation shell that will handle the navigation between the different
  /// bottom navigation bars.
  final StatefulNavigationShell navigationShell;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late VideoPlayerState _videoPlayerState;
  late PageController _pageController;
  bool _isNearCamera = false;

  /// The settled page (1 = main shell). Used to make hardware-back return to
  /// the main page instead of exiting the app from the camera/chat pages.
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: 1)
      ..addListener(() {
        final page = _pageController.hasClients ? (_pageController.page ?? 1) : 1;
        final isNearCamera = page < 0.95;
        final settled = page.round();
        if (isNearCamera != _isNearCamera || settled != _currentPage) {
          setState(() {
            _isNearCamera = isNearCamera;
            _currentPage = settled;
          });
        }
      })
      ..addListener(_onPageScroll);
    _videoPlayerState = VideoPlayerState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      HomeProvider().setPageController(_pageController);
    });
  }

  void _onPageScroll() {
    _pageController.position.isScrollingNotifier.addListener(_isPageScrolling);
  }

  void _isPageScrolling() {
    final isScrolling =
        _pageController.position.isScrollingNotifier.value == true;
    final mainPageView = _pageController.page == 1;
    final navigationBarIndex = widget.navigationShell.currentIndex;
    final isFeed = !isScrolling && mainPageView && navigationBarIndex == 0;
    final isTimeline = !isScrolling && mainPageView && navigationBarIndex == 1;
    final isReels = !isScrolling && mainPageView && navigationBarIndex == 3;

    if (isScrolling) {
      _videoPlayerState.stopAll();
    }
    switch ((isFeed, isTimeline, isReels)) {
      case (true, false, false):
        _videoPlayerState.playFeed();
      case (false, true, false):
        _videoPlayerState.playTimeline();
      case (false, false, true):
        _videoPlayerState.playReels();
      case _:
        _videoPlayerState.stopAll();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The feed used to enable this PageView so a horizontal swipe reached the
    // camera (page 0) or chats (page 2). The feed now owns that gesture for
    // its own Posts/Stories tabs, so it stays disabled here; the + button and
    // the chat tab still get there via `animateToPage`.
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CreateStoriesBloc(
        storiesRepository: context.read<StoriesRepository>(),
      ),
      child: VideoPlayerInheritedWidget(
        videoPlayerState: _videoPlayerState,
        child: ListenableBuilder(
          listenable: HomeProvider(),
          builder: (context, child) {
            return PopScope(
              // Only the main shell (page 1) may pop out of the app. The
              // camera (0) and chats (2) both slide back to the feed instead —
              // relying on the picker's own WillPopScope let back exit.
              canPop: _currentPage == 1,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                // On the New post camera, back returns to the gallery grid
                // rather than leaving New post for the feed.
                final picker = customImagePickerKey.currentState;
                if (_currentPage == 0 && (picker?.isOnCamera ?? false)) {
                  picker!.backToGrid();
                  return;
                }
                HomeProvider().animateToPage(1);
              },
              child: PageView.builder(
              itemCount: 3,
              controller: _pageController,
              physics: HomeProvider().enablePageView
                  ? null
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: (page) {
                if (page != 0 && page != 2 && page == 1) {
                  customImagePickerKey.currentState?.resetAll();
                }
                if (page == 1) {
                  HomeProvider().togglePageView(enable: false);
                }
              },
              itemBuilder: (context, index) {
                return switch (index) {
                  0 => _isNearCamera
                      ? UserProfileCreatePost(
                          canPop: false,
                          imagePickerKey: customImagePickerKey,
                          onPopInvoked: () => HomeProvider().animateToPage(1),
                          onBackButtonTap: () => HomeProvider().animateToPage(1),
                        )
                      : const Scaffold(body: SizedBox()),
                  2 => const ChatsPage(),
                  _ => AppScaffold(
                    body: widget.navigationShell,
                    bottomNavigationBar: BottomNavBar(
                      navigationShell: widget.navigationShell,
                    ),
                  ),
                };
              },
              ),
            );
          },
        ),
      ),
    );
  }
}
