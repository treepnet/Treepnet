import 'dart:ui' as ui;

import 'package:app_ui/app_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/settings/view/referral_badge.dart';
import 'package:treepnet/stories/stories.dart';
import 'package:user_repository/user_repository.dart';

/// The `Stories` tab of the feed. Unlike the usual horizontal ring of avatars,
/// the design lays stories out as a two-column grid of cover cards, with a
/// floating `Share` button pinned to the bottom.
class StoriesGridView extends StatelessWidget {
  const StoriesGridView({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.select((AppBloc bloc) => bloc.state.user);

    // StoriesBloc only loads the people you follow, so the signed-in user's own
    // stories are watched separately and pinned to the front of the grid —
    // otherwise a story you just posted never shows up here.
    return BlocProvider(
      create: (context) => UserStoriesBloc(
        author: currentUser,
        storiesRepository: context.read<StoriesRepository>(),
      )..add(UserStoriesSubscriptionRequested(currentUser.id)),
      child: BlocBuilder<UserStoriesBloc, UserStoriesState>(
        builder: (context, mine) => _Grid(
          hasOwnStories: mine.stories.isNotEmpty,
          currentUser: currentUser,
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.hasOwnStories, required this.currentUser});

  final bool hasOwnStories;
  final User currentUser;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoriesBloc, StoriesState>(
      builder: (context, state) {
        final users = [
          if (hasOwnStories) currentUser,
          ...state.users.where((u) => u.id != currentUser.id),
        ];

        return Stack(
          children: [
            if (users.isEmpty)
              Center(
                child: Text(
                  context.l10n.noStoriesText,
                  style: context.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              RefreshIndicator(
                onRefresh: () async {
                  // Re-subscribe both feeds: yours and the people you follow.
                  context.read<StoriesBloc>().add(
                    const StoriesFetchUserFollowingsStories(),
                  );
                  context.read<UserStoriesBloc>().add(
                    UserStoriesSubscriptionRequested(currentUser.id),
                  );
                  await Future<void>.delayed(const Duration(milliseconds: 600));
                },
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    // room for the floating Share button
                    AppSpacing.xxxlg + AppSpacing.lg,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    // Extra vertical gap leaves room for the avatar that
                    // hangs over the top of each card.
                    mainAxisSpacing: AppSpacing.xlg,
                    crossAxisSpacing: AppSpacing.md,
                    // Figma card is 170x216; 10px taller by request.
                    childAspectRatio: 170 / 236,
                  ),
                  itemCount: users.length,
                  itemBuilder: (context, index) => _StoryCard(
                    author: users[index],
                    index: index,
                    authors: users,
                  ),
                ),
              ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.lg),
                child: _ShareStoryButton(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Figma: the avatar that straddles each card's top edge is 64x64 overall —
/// a 3px white ring, a 2px gap, then the photo.
const double _avatarTotal = 64;
const double _avatarRing = 3;
const double _avatarGap = 2;
const double _avatarSize = _avatarTotal - 2 * (_avatarRing + _avatarGap);

/// Figma: card corner radius, and its 1px inside white stroke.
const double _cardRadius = 8;
const double _cardStroke = 1;

/// Outline colour once every story in the card has been seen.
const Color _seenRing = Color(0xFF414141);

/// One cover card: the story's media behind an avatar and the author's name.
class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.author,
    required this.index,
    required this.authors,
  });

  final User author;
  final int index;

  /// The whole ordered row, so the viewer can roll on to the next profile.
  final List<User> authors;

  @override
  Widget build(BuildContext context) {
    final currentUser = context.select((AppBloc bloc) => bloc.state.user);

    return BlocProvider(
      create: (context) => UserStoriesBloc(
        author: author,
        storiesRepository: context.read<StoriesRepository>(),
      )..add(UserStoriesSubscriptionRequested(currentUser.id)),
      child: BlocBuilder<UserStoriesBloc, UserStoriesState>(
        builder: (context, state) {
          final stories = state.stories;
          final cover = stories.isEmpty ? null : stories.first.contentUrl;
          final allSeen =
              stories.isNotEmpty && stories.every((story) => story.seen);

          return Tappable.scaled(
            onTap: stories.isEmpty
                ? null
                : () => context.pushNamed(
                    AppRoutes.stories.name,
                    pathParameters: {'user_id': author.id},
                    extra: StoriesProps(
                      stories: stories,
                      author: author,
                      continuation: nextProfileContinuation(
                        storiesRepository: context.read<StoriesRepository>(),
                        authors: authors,
                        fromIndex: index,
                        viewerId: currentUser.id,
                        startedUnseen: !allSeen,
                      ),
                    ),
                  ),
            // The avatar straddles the card's top edge, so the card starts
            // half an avatar down and the avatar is drawn over it.
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: _avatarTotal / 2,
                  child: _Card(
                    cover: cover,
                    username: author.displayUsername,
                    authorId: author.id,
                    dimmed: allSeen,
                    // Covers are always blurred — the story itself is the
                    // reveal, the grid only teases it.
                    blurred: true,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _Avatar(url: author.avatarUrl, dimmed: allSeen),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Card body: cover photo, a hairline outline, and the name near the top.
class _Card extends StatelessWidget {
  const _Card({
    required this.cover,
    required this.username,
    required this.authorId,
    this.blurred = false,
    this.dimmed = false,
  });

  final String? cover;
  final String username;
  final String authorId;

  /// Blur the cover photo while the story is unseen.
  final bool blurred;

  /// Every story seen: the outline drops to the muted grey.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final coverUrl = cover;
    Widget coverImage = coverUrl != null
        ? CachedNetworkImage(
            imageUrl: coverUrl,
            fit: BoxFit.cover,
            memCacheHeight: 600,
            placeholder: (_, _) => const ColoredBox(color: AppColors.dark),
            errorWidget: (_, _, _) => const ColoredBox(color: AppColors.dark),
          )
        : const ColoredBox(color: AppColors.dark);
    if (blurred && coverUrl != null) {
      coverImage = ImageFiltered(
        // Blurs the photo itself. A BackdropFilter samples beyond the card and
        // rendered as a dark vignette around the edges.
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 14,
          sigmaY: 14,
          tileMode: TileMode.decal,
        ),
        child: coverImage,
      );
    }

    return DecoratedBox(
      // A plain white outline: the avatar simply sits on top of it, no notch.
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(
          color: dimmed ? _seenRing : AppColors.white,
          width: _cardStroke,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_cardRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            coverImage,
            // Figma: the cover sits under a frosted panel — a background blur
            // with a 25% black fill over it — which is what makes the name
            // readable on any photo.
            const ColoredBox(color: Color(0x40000000)),
            // Name sits just under the overlapping avatar. `Align` pins it
            // there — inside the expanded Stack a bare Row stretches to the
            // full height and ends up vertically centred.
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: _avatarTotal / 2 + AppSpacing.xxs,
                  left: AppSpacing.xs,
                  right: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.labelSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: AppFontWeight.semiBold,
                        ),
                      ),
                    ),
                    const Gap.h(AppSpacing.xxs),
                    TravelTierBadge(userId: authorId, size: 13),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.dimmed});

  final String? url;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    const size = _avatarSize;
    return Container(
      padding: const EdgeInsets.all(_avatarGap),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Filled so the gap between ring and photo always reads as the page
        // colour, even over the card's blurred cover.
        color: AppColors.background,
        border: Border.all(
          color: dimmed ? _seenRing : AppColors.white,
          width: _avatarRing,
        ),
      ),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: (url == null || url!.isEmpty)
              ? const ColoredBox(
                  color: AppColors.darkGrey,
                  child: Icon(Icons.person, color: AppColors.white, size: 24),
                )
              : CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  memCacheHeight: 140,
                  placeholder: (_, _) =>
                      const ColoredBox(color: AppColors.darkGrey),
                  errorWidget: (_, _, _) =>
                      const ColoredBox(color: AppColors.darkGrey),
                ),
        ),
      ),
    );
  }
}

/// The white pill at the bottom of the grid — opens the story composer.
class _ShareStoryButton extends StatelessWidget {
  const _ShareStoryButton();

  @override
  Widget build(BuildContext context) {
    final user = context.select((AppBloc bloc) => bloc.state.user);

    return Tappable.scaled(
      onTap: () => startStoryCreation(context, user),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm + AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.sharePostText,
              style: context.bodyLarge?.copyWith(
                color: AppColors.black,
                fontWeight: AppFontWeight.semiBold,
              ),
            ),
            const Gap.h(AppSpacing.sm),
            const Icon(Icons.add, color: AppColors.black, size: 20),
          ],
        ),
      ),
    );
  }
}
