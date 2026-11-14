import 'package:flutter/material.dart';
import 'package:treepnet/user_profile/user_profile.dart';

/// The profile's followers ([UserProfileFollowList]).
class UserProfileFollowers extends StatelessWidget {
  const UserProfileFollowers({super.key});

  @override
  Widget build(BuildContext context) =>
      const UserProfileFollowList(followers: true);
}
