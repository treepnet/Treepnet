import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/stories/stories.dart';

class StoriesCarousel extends StatelessWidget {
  const StoriesCarousel({super.key});

  static const _storiesCarouselHeight = 124.0;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AppBloc bloc) => bloc.state.user);

    return SliverPadding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xxs,
        bottom: AppSpacing.xxs,
      ),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: _storiesCarouselHeight,
          child: BlocBuilder<StoriesBloc, StoriesState>(
            builder: (context, state) {
              final followings = state.users;
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: followings.length + 1,
                separatorBuilder: (context, index) =>
                    const Gap.h(AppSpacing.lg),
                itemBuilder: (context, index) {
                  final following = index == 0 ? null : followings[index - 1];
                  final isMine = index == 0;

                  return Padding(
                    padding: EdgeInsets.only(left: isMine ? AppSpacing.md : 0),
                    child: StoryAvatar(
                      key: ValueKey(following?.id ?? user.id),
                      author: following ?? user,
                      isMine: isMine,
                      username: following?.displayUsername ?? '',
                      onTap: (_) {
                        startStoryCreation(context, user);
                      },
                      onLongPress: isMine ? null : () {},
                      avatarBuilder:
                          (
                            context,
                            author,
                            onAvatarTap,
                            isMine,
                            stories,
                            onLongPress,
                          ) {
                            return UserStoriesAvatar(
                              resizeHeight: 252,
                              isLarge: true,
                              stories: stories,
                              author: author,
                              onAvatarTap: onAvatarTap,
                              withAddButton: isMine,
                              onLongPress: (_) => onLongPress?.call(),
                              tappableVariant: TappableVariant.scaled,
                              showWhenSeen: true,
                              onAddButtonTap: () => onAvatarTap(''),
                            );
                          },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
