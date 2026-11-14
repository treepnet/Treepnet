import 'package:flutter/material.dart';
import 'package:treepnet/user_profile/user_profile.dart';

/// The people the profile follows ([UserProfileFollowList]).
class UserProfileFollowings extends StatelessWidget {
  const UserProfileFollowings({super.key});

  @override
  Widget build(BuildContext context) =>
      const UserProfileFollowList(followers: false);
}
