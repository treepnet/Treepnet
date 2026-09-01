import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/user_profile/user_profile.dart';

class UserProfileFollowers extends StatefulWidget {
  const UserProfileFollowers({super.key});

  @override
  State<UserProfileFollowers> createState() => _UserProfileFollowersState();
}

class _UserProfileFollowersState extends State<UserProfileFollowers>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 20;

  /// Reactive-window size; grows by [_pageSize] when the user scrolls to the
  /// end so a huge follower list isn't fetched (one profile query each) at once.
  int _limit = _pageSize;
  int _requestedLimit = _pageSize;

  @override
  void initState() {
    super.initState();
    _request();
  }

  void _request() {
    context.read<UserProfileBloc>().add(
      UserProfileFollowersSubscriptionRequested(limit: _limit),
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
    final followers = context.select(
      (UserProfileBloc bloc) => bloc.state.followers,
    );

    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverList.builder(
          itemCount: followers.length,
          itemBuilder: (context, index) {
            if (index >= followers.length - 1) _maybeGrow(followers.length);
            final user = followers[index];
            return UserProfileListTile(user: user, follower: true);
          },
        ),
      ],
    );
  }
}
