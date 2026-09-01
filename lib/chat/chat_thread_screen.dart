import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger_chat/messenger_chat.dart';
import 'package:treepnet/app/bloc/app_bloc.dart';
import 'package:treepnet/app/routes/app_routes.dart';
import 'package:treepnet/chat/chat_session.dart';
import 'package:treepnet/chat/chat_theme.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/stories/widgets/user_stories_avatar.dart';
import 'package:user_repository/user_repository.dart';

/// A single 1:1 conversation, styled with the app's chat design tokens
/// ([ChatTheme]).
///
/// [MessengerChat.init] must already have been called (see `openChat`) — this
/// widget only draws the configured conversation. It adds the app-level block
/// system on top of the plugin: a header ⋮ menu (block / unblock / delete) and,
/// when either side has blocked the other, a notice in place of the composer.
class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({
    required this.peer,
    required this.peerUuid,
    required this.conversationId,
    required this.lang,
    super.key,
  });

  final ChatUser peer;

  /// The peer's app-side profile uuid (`profiles.id`) — the block system is
  /// keyed on it. May be empty if the inbox couldn't resolve it, in which case
  /// block state is simply not shown.
  final String peerUuid;
  final String conversationId;
  final ChatLanguage lang;

  @override
  Widget build(BuildContext context) {
    final me = context.select((AppBloc bloc) => bloc.state.user.id);
    final repo = context.read<UserRepository>();
    final menu = _ChatOverflowMenu(
      peerUuid: peerUuid,
      peerName: peer.name,
      conversationId: conversationId,
    );

    // Header avatar with the app-wide story ring (white = unseen story, grey =
    // seen, none = no story); tapping it opens the story or, failing that, the
    // profile. Tapping the name always opens the profile. Only when we know the
    // peer's app uuid.
    Widget? headerAvatar;
    VoidCallback? onTitleTap;
    if (peerUuid.isNotEmpty) {
      final peerUser = User(
        id: peerUuid,
        username: peer.name,
        avatarUrl: peer.avatarUrl,
      );
      headerAvatar = SizedBox(
        width: 44,
        height: 44,
        child: UserStoriesAvatar(
          author: peerUser,
          isLarge: false,
          radius: 20,
          withAdaptiveBorder: false,
          // Only the WHITE (unseen) ring in chat — no grey "seen" ring.
          enableInactiveBorder: false,
        ),
      );
      onTitleTap = () => context.pushNamed(
        AppRoutes.userProfile.name,
        pathParameters: {'user_id': peerUuid},
      );
    }

    if (peerUuid.isEmpty || me.isEmpty) {
      return _chat(trailing: menu, composerOverride: null);
    }

    // Block gates BOTH ways: if I blocked them the notice offers unblock; if
    // they blocked me it just says messaging is unavailable. The thread still
    // opens and history stays readable.
    return StreamBuilder<bool>(
      stream: repo.isBlocked(userId: me, otherUserId: peerUuid),
      initialData: false,
      builder: (context, iBlockedSnap) {
        final iBlocked = iBlockedSnap.data ?? false;
        return StreamBuilder<bool>(
          stream: repo.isBlocked(userId: peerUuid, otherUserId: me),
          initialData: false,
          builder: (context, blockedMeSnap) {
            final blockedMe = blockedMeSnap.data ?? false;
            final blocked = iBlocked || blockedMe;
            return _chat(
              trailing: menu,
              avatar: headerAvatar,
              onTitleTap: onTitleTap,
              composerOverride:
                  blocked ? _BlockedComposerBar(iBlocked: iBlocked) : null,
            );
          },
        );
      },
    );
  }

  Widget _chat({
    required Widget trailing,
    Widget? avatar,
    VoidCallback? onTitleTap,
    Widget? composerOverride,
  }) => MessengerChat(
    peer: peer,
    lang: lang,
    chatAppBarStyle: ChatTheme.appBarStyle,
    chatDecoration: ChatTheme.decoration,
    messageStyle: ChatTheme.messageStyle,
    chatTextFieldStyle: ChatTheme.textFieldStyle,
    appBarTrailing: trailing,
    appBarAvatar: avatar,
    onTitleTap: onTitleTap,
    composerOverride: composerOverride,
  );
}

/// The header's ⋮ menu: block / unblock this person, or delete the
/// conversation. Block / unblock write the same `blocked_users` rows the
/// profile menu and Settings → Blocked users use, so blocking is unified
/// app-wide.
class _ChatOverflowMenu extends StatelessWidget {
  const _ChatOverflowMenu({
    required this.peerUuid,
    required this.peerName,
    required this.conversationId,
  });

  final String peerUuid;
  final String peerName;
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final me = context.read<AppBloc>().state.user.id;
    final repo = context.read<UserRepository>();
    final canBlock = peerUuid.isNotEmpty && me.isNotEmpty;

    return StreamBuilder<bool>(
      stream: canBlock
          ? repo.isBlocked(userId: me, otherUserId: peerUuid)
          : Stream<bool>.value(false),
      initialData: false,
      builder: (context, snapshot) {
        final blocked = snapshot.data ?? false;
        return PopupMenuButton<_ChatMenuAction>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: ChatTheme.bubble,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          onSelected: (action) => _onSelected(
            context,
            action,
            blocked: blocked,
            me: me,
            repo: repo,
          ),
          itemBuilder: (context) => [
            if (canBlock)
              PopupMenuItem(
                value: _ChatMenuAction.block,
                child: Text(
                  blocked
                      ? context.l10n.unblockAuthorText
                      : context.l10n.blockAuthorText,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            PopupMenuItem(
              value: _ChatMenuAction.delete,
              child: Text(
                context.l10n.deleteText,
                style: const TextStyle(color: Color(0xffE5484D)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onSelected(
    BuildContext context,
    _ChatMenuAction action, {
    required bool blocked,
    required String me,
    required UserRepository repo,
  }) {
    switch (action) {
      case _ChatMenuAction.block:
        context.confirmAction(
          title: blocked
              ? context.l10n.unblockAuthorText
              : context.l10n.blockAuthorText,
          content: blocked
              ? context.l10n.unblockUserTitleText(peerName)
              : context.l10n.blockAuthorConfirmationText,
          yesText: blocked ? context.l10n.unblockText : context.l10n.blockText,
          noText: context.l10n.cancelText,
          yesTextStyle: TextStyle(color: blocked ? null : AppColors.red),
          fn: () => blocked
              ? repo.unblockUser(userId: me, blockedId: peerUuid)
              : repo.blockUser(userId: me, blockedId: peerUuid),
        );
      case _ChatMenuAction.delete:
        final navigator = Navigator.of(context);
        context.confirmAction(
          title: context.l10n.deleteChatText,
          content: context.l10n.chatDeleteConfirmationText,
          yesText: context.l10n.deleteText,
          noText: context.l10n.cancelText,
          yesTextStyle: const TextStyle(color: AppColors.red),
          fn: () async {
            if (ChatSession.instance.isStarted) {
              await ChatSession.instance.listTransport.deleteConversation(
                conversationId,
              );
            }
            navigator.maybePop();
          },
        );
    }
  }
}

enum _ChatMenuAction { block, delete }

/// Shown in place of the input when either side has blocked the other.
class _BlockedComposerBar extends StatelessWidget {
  const _BlockedComposerBar({required this.iBlocked});

  final bool iBlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: ChatTheme.background,
      alignment: Alignment.center,
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: Text(
        iBlocked
            ? context.l10n.blockedThisUserText
            : context.l10n.cantMessageUserText,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
