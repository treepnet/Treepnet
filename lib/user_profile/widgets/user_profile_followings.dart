import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/user_profile/user_profile.dart';

class UserProfileFollowings extends StatefulWidget {
  const UserProfileFollowings({super.key});

  @override
  State<UserProfileFollowings> createState() => _UserProfileFollowingsState();
}

class _UserProfileFollowingsState extends State<UserProfileFollowings>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 20;

  /// Window size; grows by [_pageSize] when the user scrolls to the end so a
  /// huge following list isn't fetched (one profile query each) all at once.
  int _limit = _pageSize;
  int _requestedLimit = _pageSize;

  @override
  void initState() {
    super.initState();
    _request();
  }

  void _request() {
    context.read<UserProfileBloc>().add(
      UserProfileFetchFollowingsRequested(limit: _limit),
    );
  }

  /// Called when the last loaded tile is built (user reached the end); widens
  /// the window on the next frame if more may exist.
  void _maybeGrow(int loaded) {
    if (loaded >= _limit && _requestedLimit == _limit) {
      _requestedLimit = _limit + _pageSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _limit = _requestedLimit;
        _request();
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final followings = context.select(
      (UserProfileBloc bloc) => bloc.state.followings,
    );

    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverList.builder(
          itemCount: followings.length,
          itemBuilder: (context, index) {
            if (index >= followings.length - 1) _maybeGrow(followings.length);
            final user = followings[index];
            return UserProfileListTile(user: user, follower: false);
          },
        ),
      ],
    );
  }
}
