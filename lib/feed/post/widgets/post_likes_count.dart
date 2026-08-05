import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/feed/post/post.dart';
import 'package:treepnet/feed/post/view/post_likers_page.dart';
import 'package:shared/shared.dart';

class PostLikesCount extends StatelessWidget {
  const PostLikesCount({
    required this.block,
    required this.onUserTap,
    super.key,
  });

  final PostBlock block;
  final ValueSetter<String> onUserTap;

  @override
  Widget build(BuildContext context) {
    final likesCount = context.select((PostBloc bloc) => bloc.state.likes);

    if (likesCount == 0) return const SizedBox.shrink();

    // The design puts the bare number next to the heart, so this renders just
    // the count; tapping it still opens the full list of likers.
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => PostLikersPage(postId: block.id)),
        ),
        child: Text(
          '$likesCount',
          key: ValueKey('likes-count-${block.id}'),
          style: context.titleMedium?.copyWith(
            fontWeight: AppFontWeight.semiBold,
          ),
        ),
      ),
    );
  }
}
