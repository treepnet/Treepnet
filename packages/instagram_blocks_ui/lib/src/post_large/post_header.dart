import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:shared/shared.dart';

class PostHeader extends StatelessWidget {
  const PostHeader({
    required this.block,
    required this.isOwner,
    required this.isFollowed,
    required this.onAvatarTap,
    required this.follow,
    required this.enableFollowButton,
    required this.isSponsored,
    required this.postOptionsSettings,
    this.postAuthorAvatarBuilder,
    this.authorBadge,
    this.authorSubtitle,
    this.color,
    super.key,
  });

  final PostBlock block;

  final bool isOwner;

  final bool isFollowed;

  final ValueSetter<String?>? onAvatarTap;

  final VoidCallback follow;

  final bool enableFollowButton;

  final bool isSponsored;

  final AvatarBuilder? postAuthorAvatarBuilder;

  /// Optional badge rendered next to the author's name (the travel
  /// checkmark). Built app-side, since this package can't reach the
  /// user repository.
  final Widget? authorBadge;

  /// Optional line under the author's name — the app puts the author's total
  /// visited-location count here. Built app-side (repo access lives there).
  final Widget? authorSubtitle;

  final Color? color;

  final PostOptionsSettings postOptionsSettings;

  @override
  Widget build(BuildContext context) {
    final author = block.author;
    final color = this.color ?? context.adaptiveColor;

    final username = isSponsored
        ? Row(
            children: [
              Text(
                '${author.username} ',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: context.titleMedium?.apply(color: color),
              ),
              Assets.icons.verifiedUser.svg(
                width: AppSize.iconSizeSmall,
                height: AppSize.iconSizeSmall,
              ),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  author.username,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: context.titleMedium?.apply(color: color),
                ),
              ),
              if (authorBadge != null) ...[
                const Gap.h(AppSpacing.xs),
                authorBadge!,
              ],
            ],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Tappable(
              onTap: () => onAvatarTap?.call(author.avatarUrl),
              child: Row(
                children: [
                  postAuthorAvatarBuilder?.call(
                        context,
                        author,
                        onAvatarTap,
                      ) ??
                      UserProfileAvatar(
                        resizeHeight: 108,
                        userId: author.id,
                        isLarge: false,
                        avatarUrl: author.avatarUrl,
                        onTap: onAvatarTap,
                        scaleStrength: ScaleStrength.xxs,
                      ),
                  const Gap.h(AppSpacing.md),
                  // The location now lives in a chip on the right (see below),
                  // so only sponsored posts keep a subtitle under the name.
                  if (isSponsored)
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          username,
                          Text(
                            BlockSettings().postTextDelegate.sponsoredPostText,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: context.bodySmall?.apply(
                              color: color.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          username,
                          if (authorSubtitle != null) authorSubtitle!,
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Builder(
            builder: (_) {
              bool showFollowButton() {
                if (isSponsored) return false;
                if (isOwner) return false;
                return !isFollowed;
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showFollowButton() && enableFollowButton) ...[
                    FollowButton(
                      follow: follow,
                      isFollowed: isFollowed,
                      isOutlined: this.color != null,
                    ),
                    const Gap.h(AppSpacing.md),
                  ],
                  PostOptionsButton(
                    block: block,
                    settings: postOptionsSettings,
                    isFollowed: isFollowed,
                    color: color,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class PostOptionsButton extends StatelessWidget {
  const PostOptionsButton({
    required this.block,
    required this.settings,
    required this.color,
    super.key,
    this.isFollowed,
  });

  final PostBlock block;
  final PostOptionsSettings settings;
  final bool? isFollowed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.more_vert,
      size: AppSize.iconSizeMedium,
      color: color,
    );

    Future<void> showOptionsSheet(List<ModalOption> options) async {
      void callback(ModalOption option) => option.onTap.call(context);

      final option = await context.showListOptionsModal(options: options);
      if (option == null) return;
      callback.call(option);
    }

    // A post's owner menu is delete-only: posts are not editable and not
    // archivable (only stories archive, after 24h).
    List<ModalOption> ownerOptions({
      required VoidCallback onPostEditTap,
      required VoidCallback onPostDeleteTap,
      VoidCallback? onPostArchiveTap,
    }) => <ModalOption>[
      ModalOption(
        name: BlockSettings().postTextDelegate.deleteText,
        actionTitle: BlockSettings().postTextDelegate.deletePostText,
        actionContent:
            BlockSettings().postTextDelegate.deletePostConfirmationText,
        actionYesText: BlockSettings().postTextDelegate.deleteText,
        actionNoText: BlockSettings().postTextDelegate.cancelText,
        icon: Assets.icons.trash.svg(
          colorFilter: const ColorFilter.mode(AppColors.red, BlendMode.srcIn),
        ),
        distractive: true,
        onTap: onPostDeleteTap,
      ),
    ];

    List<ModalOption> viewerOptions({
      required VoidCallback onPostNotShowAgainTap,
      required VoidCallback onPostBlockAuthorTap,
    }) => <ModalOption>[
      ModalOption(
        name: BlockSettings().postTextDelegate.notShowAgainText,
        iconData: Icons.remove_circle_outline_sharp,
        onTap: onPostNotShowAgainTap,
      ),
      ModalOption(
        name: BlockSettings().postTextDelegate.blockPostAuthorText,
        actionTitle: BlockSettings().postTextDelegate.blockAuthorText,
        actionContent:
            BlockSettings().postTextDelegate.blockAuthorConfirmationText,
        actionYesText: BlockSettings().postTextDelegate.blockText,
        iconData: Icons.block,
        actionNoText: BlockSettings().postTextDelegate.cancelText,
        distractive: true,
        onTap: onPostBlockAuthorTap,
      ),
    ];

    return settings.when(
      viewer: () => Tappable(
        onTap: () => showOptionsSheet(
          viewerOptions(
            onPostNotShowAgainTap: () {},
            onPostBlockAuthorTap: () {},
          ),
        ),
        child: icon,
      ),
      owner: (onPostDelete, onPostEdit, onPostArchive) => Tappable(
        onTap: () => showOptionsSheet(
          ownerOptions(
            onPostEditTap: () => onPostEdit.call(block),
            onPostDeleteTap: () => onPostDelete.call(block.id),
            onPostArchiveTap: onPostArchive == null
                ? null
                : () => onPostArchive.call(block.id),
          ),
        ),
        child: icon,
      ),
    );
  }
}
