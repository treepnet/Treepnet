import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/chat/chat.dart';
import 'package:treepnet/feed/post/widgets/share_post.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

/// The bar under a story.
///
/// The author sees who has watched it (and the like count); everyone else gets
/// a reply box and a like button. A reply is just a direct message — the same
/// thing Instagram does — so it reuses the existing chat instead of a separate
/// story-comment table.
class StoryFooter extends StatefulWidget {
  /// {@macro story_footer}
  const StoryFooter({
    required this.story,
    required this.author,
    required this.viewer,
    this.onComposing,
    this.leading,
    this.onMore,
    this.onAddStory,
    super.key,
  });

  /// The story currently on screen.
  final Story story;

  /// Whose story it is.
  final User author;

  /// The signed-in user watching it.
  final User viewer;

  /// Shown on the left of the viewer's reply row (before it opens): the story
  /// author — avatar, name and "time ago" — so those sit in the footer bar at
  /// the very bottom rather than floating up over the picture.
  final Widget? leading;

  /// Opens the owner's "more" menu (Delete). Lives on the page because it needs
  /// the story controller and list; the footer just triggers it.
  final VoidCallback? onMore;

  /// Opens the story camera to add another story. Owner-only; the page owns the
  /// create-story flow, the footer just triggers it.
  final VoidCallback? onAddStory;

  /// Fires true when the reply field opens and false when it closes, so the
  /// page can hold playback while someone types.
  final ValueChanged<bool>? onComposing;

  @override
  State<StoryFooter> createState() => _StoryFooterState();
}

class _StoryFooterState extends State<StoryFooter> with WidgetsBindingObserver {
  final _replyController = TextEditingController();
  bool _sending = false;

  /// Whether the reply field is showing. Starts closed.
  bool _replying = false;
  final _replyFocus = FocusNode();

  /// Tracks the keyboard so we can tell an open→closed transition from the
  /// first frame (where the inset is briefly 0 before it slides up).
  bool _keyboardWasVisible = false;

  bool get _isMine => widget.author.id == widget.viewer.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The composer closes the instant the field loses focus — whether that is
    // a tap on the dimmed story, the back button, or the keyboard being
    // dismissed by the system. Tying it to focus is deterministic; the old
    // build-time check on the keyboard inset raced the close animation and left
    // the reply bar stranded with no keyboard.
    _replyFocus.addListener(() {
      if (!_replyFocus.hasFocus && _replying && !_sending) {
        _setReplying(false);
      }
    });
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    // The Android system back button hides the keyboard WITHOUT dropping the
    // TextField's focus, so the focus listener never fires and the composer,
    // emojis and scrim were left stranded with playback still paused. Detect
    // the keyboard sliding shut and unfocus ourselves — that then runs the
    // focus listener, which closes the composer and resumes the story.
    final keyboardVisible = View.of(context).viewInsets.bottom > 0;
    if (keyboardVisible) {
      _keyboardWasVisible = true;
    } else if (_keyboardWasVisible) {
      _keyboardWasVisible = false;
      if (_replying && !_sending && _replyFocus.hasFocus) {
        _replyFocus.unfocus();
      }
    }
  }

  void _setReplying(bool value) {
    if (_replying == value) return;
    setState(() => _replying = value);
    // Playback has to stop while the keyboard is up, or the story advances
    // out from under whatever is being typed.
    widget.onComposing?.call(value);
  }

  /// Sends the reply as a direct message — the same thing Instagram does, so
  /// it reuses the existing chat rather than a separate story-comment table.
  ///
  /// Two messages travel, in order: first the story itself (as a share
  /// sentinel, rendered as a rich story card the peer can tap to open), then
  /// the typed reply beneath it — so the chat shows the story being replied to,
  /// not just an orphan line of text.
  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final peerAvatar = (widget.author.avatarUrl?.isNotEmpty ?? false)
        ? widget.author.avatarUrl
        : null;
    try {
      await shareTextToUser(
        context,
        peerUuid: widget.author.id,
        peerName: widget.author.displayUsername,
        peerAvatarUrl: peerAvatar,
        text: encodeStoryShare(widget.story.id),
      );
      if (!mounted) return;
      await shareTextToUser(
        context,
        peerUuid: widget.author.id,
        peerName: widget.author.displayUsername,
        peerAvatarUrl: peerAvatar,
        text: text,
      );
      if (!mounted) return;
      _replyController.clear();
      _replyFocus.unfocus();
      _setReplying(false);
      openSnackbar(
        SnackbarMessage.success(title: context.l10n.storyReplySentText),
      );
    } catch (_) {
      if (!mounted) return;
      openSnackbar(
        SnackbarMessage.error(title: context.l10n.somethingWentWrongText),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Opens the Share sheet — same UI and behaviour as sharing a post. While it
  /// is open the story pauses and dims (via [onComposing], the same path the
  /// keyboard uses); closing it — by tapping outside or the back button —
  /// resumes and clears the scrim. A transparent modal barrier keeps the dim
  /// identical to the keyboard's scrim rather than doubling it.
  Future<void> _openShare() async {
    widget.onComposing?.call(true);
    try {
      await context.showScrollableModal(
        barrierColor: Colors.transparent,
        pageBuilder: (scrollController, draggableScrollController) =>
            ShareStory(
              storyId: widget.story.id,
              viewer: widget.viewer,
              scrollController: scrollController,
              draggableScrollController: draggableScrollController,
            ),
      );
    } finally {
      if (mounted) widget.onComposing?.call(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _replyFocus.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _showViewers() async {
    // Same treatment as the keyboard and share: pause and dim the story while
    // the sheet is open, resume when it closes. A transparent barrier lets the
    // page's own scrim provide the dim rather than doubling it.
    widget.onComposing?.call(true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.background,
        barrierColor: Colors.transparent,
        builder: (_) => _ViewersSheet(storyId: widget.story.id),
      );
    } finally {
      if (mounted) widget.onComposing?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: _isMine ? _ownerBar(context) : _viewerBar(context),
      ),
    );
  }

  /// Owner's view (your own story): author on the left, then a view counter
  /// (icon + number only, no "Views" label), the share button, and the "more"
  /// menu (white ⋮) — no like button. This layout is the owner's alone and
  /// does not touch how you see other people's stories.
  Widget _ownerBar(BuildContext context) {
    final stories = context.read<StoriesRepository>();
    return Row(
      children: [
        // Same author block as the viewer footer (avatar, name, time ago).
        if (widget.leading != null)
          Expanded(child: widget.leading!)
        else
          const Spacer(),
        // Add another story — opens the story camera.
        IconButton(
          onPressed: widget.onAddStory,
          icon: const Icon(Icons.add, color: Colors.white, size: 26),
        ),
        // Views: icon + count only, tappable → viewers sheet.
        Tappable.faded(
          onTap: _showViewers,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: StreamBuilder<int>(
              stream: stories.storyViewsCountOf(storyId: widget.story.id),
              builder: (context, snap) {
                final n = snap.data ?? 0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const Gap.h(AppSpacing.xs),
                    Text(
                      '$n',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        // Share — same sheet and behaviour as the viewer footer.
        IconButton(
          onPressed: _openShare,
          icon: const _ShareIcon(size: 26),
        ),
        // More (white ⋮) — story options (Delete), opened on the page.
        IconButton(
          onPressed: widget.onMore,
          icon: const Icon(Icons.more_vert, color: Colors.white, size: 26),
        ),
      ],
    );
  }

  /// Everyone else: a keyboard button, a share arrow and a like heart. The
  /// reply box is summoned rather than parked open — a permanently visible
  /// field covered the bottom of every story for the sake of something most
  /// viewers never use.
  Widget _viewerBar(BuildContext context) {
    if (!_replying) {
      return Row(
        children: [
          // Author on the left, filling the row; the controls stay pinned to
          // the right edge: Follow (only when not yet following), keyboard,
          // then share.
          if (widget.leading != null)
            Expanded(child: widget.leading!)
          else
            const Spacer(),
          StreamBuilder<bool>(
            stream: context.read<UserRepository>().followingStatus(
              userId: widget.author.id,
            ),
            builder: (context, snap) {
              // Default to "following" while unknown so the button never flashes
              // for people you already follow.
              final isFollowing = snap.data ?? true;
              if (isFollowing) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _StoryFollowButton(
                  onTap: () => context.read<UserRepository>().follow(
                    followToId: widget.author.id,
                  ),
                ),
              );
            },
          ),
          IconButton(
            // Opens on the first tap: the field's autofocus raises the
            // keyboard. This only works because the footer keeps its state when
            // the scrim appears — see the keys in stories_page.dart.
            onPressed: () => _setReplying(true),
            icon: const Icon(
              Icons.keyboard_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          IconButton(
            // Shares the story like a post: same sheet, pausing and dimming the
            // story while it is open.
            onPressed: _openShare,
            icon: const _ShareIcon(size: 26),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The same quick-reaction strip the comment composer has.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: commentEmojies
              .map(
                (emoji) => Flexible(
                  child: FittedBox(
                    child: Tappable.faded(
                      onTap: () {
                        _replyController.text =
                            '${_replyController.text}$emoji';
                        _replyController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _replyController.text.length),
                        );
                        _replyFocus.requestFocus();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const Gap.v(AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                focusNode: _replyFocus,
                autofocus: true,
                controller: _replyController,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendReply(),
                decoration: InputDecoration(
                  hintText: context.l10n.storyReplyHint,
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.12),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const Gap.h(AppSpacing.sm),
            if (_sending)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            else
              // Dead until there is something to send, so the arrow reads as a
              // state rather than a button that quietly does nothing.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _replyController,
                builder: (context, value, _) {
                  final ready = value.text.trim().isNotEmpty;
                  return IconButton(
                    onPressed: ready ? _sendReply : null,
                    icon: Icon(
                      Icons.send,
                      size: 26,
                      color: ready ? AppColors.white : const Color(0xFF414141),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// Footer "Follow" pill shown only while you do NOT follow the story's author
/// — white fill, black text. Tapping follows them; the following-status stream
/// then reports true and the button removes itself.
class _StoryFollowButton extends StatelessWidget {
  const _StoryFollowButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable.scaled(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          context.l10n.followUser,
          style: context.labelLarge?.copyWith(
            color: AppColors.black,
            fontWeight: AppFontWeight.semiBold,
          ),
        ),
      ),
    );
  }
}

/// The share glyph — the design's "forward" arrow, drawn straight from its
/// 24×24 path so it needs no SVG asset or new dependency.
class _ShareIcon extends StatelessWidget {
  const _ShareIcon({this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _ShareIconPainter());
}

class _ShareIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // The path is authored in a 24-unit viewBox; scale it to the paint size so
    // the stroke width scales with it, exactly like the SVG would.
    canvas.scale(size.width / 24.0, size.height / 24.0);
    final path = Path()
      ..moveTo(12.9999, 4)
      ..lineTo(12.9999, 8)
      ..cubicTo(6.42494, 9.028, 3.97994, 14.788, 2.99994, 20)
      ..cubicTo(2.96294, 20.206, 8.38394, 14.038, 12.9999, 14)
      ..lineTo(12.9999, 18)
      ..lineTo(20.9999, 11)
      ..lineTo(12.9999, 4)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bottom sheet listing everyone who viewed the story.
class _ViewersSheet extends StatefulWidget {
  const _ViewersSheet({required this.storyId});

  final String storyId;

  @override
  State<_ViewersSheet> createState() => _ViewersSheetState();
}

class _ViewersSheetState extends State<_ViewersSheet> {
  static const _pageSize = 30;

  /// Reactive window over the viewers — a viral story can have thousands, so
  /// only [_limit] are fetched; it widens by [_pageSize] as the list scrolls to
  /// its end (they're ordered newest-first, so growing adds older viewers).
  int _limit = _pageSize;
  int _requestedLimit = _pageSize;
  Stream<List<User>>? _stream;
  int _streamLimit = -1;

  late final StoriesRepository _stories;

  @override
  void initState() {
    super.initState();
    _stories = context.read<StoriesRepository>();
  }

  Stream<List<User>> _viewersStream() {
    if (_stream == null || _streamLimit != _limit) {
      _streamLimit = _limit;
      _stream = _stories.storyViewersOf(storyId: widget.storyId, limit: _limit);
    }
    return _stream!;
  }

  /// Called from the list's [itemBuilder] when the last loaded row is built —
  /// widens the window on the next frame if it's full (there may be more).
  void _maybeGrow(int loaded) {
    if (loaded >= _limit && _requestedLimit == _limit) {
      _requestedLimit = _limit + _pageSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _limit = _requestedLimit);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: StreamBuilder<List<User>>(
        stream: _viewersStream(),
        builder: (context, snap) {
          final viewers = snap.data;
          return Column(
            children: [
              // Header: centred title with the view count and eye on the right.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    Text(
                      context.l10n.storyViewersTitle,
                      style: context.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: AppFontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${viewers?.length ?? 0}',
                            style: context.bodyLarge?.copyWith(
                              color: AppColors.white,
                              fontWeight: AppFontWeight.semiBold,
                            ),
                          ),
                          const Gap.h(AppSpacing.xs),
                          Assets.icons.viewsLined.svg(
                            width: AppSize.iconSizeMedium,
                            height: AppSize.iconSizeMedium,
                            colorFilter: const ColorFilter.mode(
                              AppColors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (viewers == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (viewers.isEmpty) {
                      return Center(
                        child: Text(
                          context.l10n.storyNoViewersText,
                          style: context.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: viewers.length,
                      itemBuilder: (context, i) {
                        // Reached the end of the window → widen it.
                        if (i >= viewers.length - 1) _maybeGrow(viewers.length);
                        return _ViewerTile(user: viewers[i]);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One viewer row: avatar, name and a Follow / Followed button.
class _ViewerTile extends StatelessWidget {
  const _ViewerTile({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final me = context.select((AppBloc bloc) => bloc.state.user);
    final users = context.read<UserRepository>();
    final isMe = me.id == user.id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              UserProfileAvatar(
                avatarUrl: user.avatarUrl,
                radius: 22,
                withAdaptiveBorder: false,
              ),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: Text(
                  user.displayFullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.bodyLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: AppFontWeight.semiBold,
                  ),
                ),
              ),
              if (!isMe)
                StreamBuilder<bool>(
                  stream: users.followingStatus(userId: user.id),
                  builder: (context, snap) {
                    final isFollowed = snap.data ?? false;
                    return _FollowButton(
                      isFollowed: isFollowed,
                      onTap: () => isFollowed
                          ? users.unfollow(unfollowId: user.id)
                          : users.follow(followToId: user.id),
                    );
                  },
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.xxlg + AppSpacing.lg),
          child: Divider(height: 1, thickness: 1, color: AppColors.divider),
        ),
      ],
    );
  }
}

/// White when you can follow, grey once you already do.
class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.isFollowed, required this.onTap});

  final bool isFollowed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable.scaled(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isFollowed ? AppColors.inputSpace : AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Text(
          isFollowed ? context.l10n.followingUser : context.l10n.followUser,
          textAlign: TextAlign.center,
          style: context.labelLarge?.copyWith(
            color: isFollowed ? AppColors.white : AppColors.black,
            fontWeight: AppFontWeight.semiBold,
          ),
        ),
      ),
    );
  }
}
