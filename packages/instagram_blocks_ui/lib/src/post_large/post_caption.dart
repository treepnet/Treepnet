import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

class PostCaption extends StatelessWidget {
  const PostCaption({
    required this.username,
    required this.caption,
    required this.onUserProfileAvatarTap,
    super.key,
  });

  // Kept for API compatibility with callers; the username is no longer shown
  // above the caption.
  final String username;
  final String caption;
  final VoidCallback onUserProfileAvatarTap;

  @override
  Widget build(BuildContext context) {
    if (caption.isEmpty) return const SizedBox.shrink();
    // Just the caption, in full — no leading username and no truncation, so a
    // long description shows every line.
    return Text(
      caption,
      style: context.bodyMedium,
    );
  }
}
