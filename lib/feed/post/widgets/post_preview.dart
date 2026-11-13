import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/feed.dart';
import 'package:treepnet/feed/post/post.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:shared/shared.dart';
import 'package:sliver_tools/sliver_tools.dart';

class PostPreviewPage extends StatelessWidget {
  const PostPreviewPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const PostPreviewAppBar(),
      body: PostPreviewDetails(id: id),
    );
  }
}

class PostPreviewAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PostPreviewAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const AppLogo(), centerTitle: false);
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class PostPreviewNotFound extends StatelessWidget {
  const PostPreviewNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Text(context.l10n.noPostFoundText, style: context.headlineSmall),
      ),
    );
  }
}

class PostPreviewDetails extends StatefulWidget {
  const PostPreviewDetails({required this.id, super.key});

  final String id;

  @override
  State<PostPreviewDetails> createState() => _PostPreviewDetailsState();
}

class _PostPreviewDetailsState extends State<PostPreviewDetails> {
  PostBlock? _block;
  bool _hasData = true;
  bool _isLoading = false;

  /// The post couldn't be read (offline, a server error): "Couldn't load",
  /// with a retry. It said "No post found", or the spinner never stopped.
  bool _failed = false;
  StreamSubscription<PostRemoval>? _removals;

  @override
  void initState() {
    super.initState();
    _removals = context.read<PostsRepository>().postRemovals.listen(_onRemoved);
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final value = await context.read<FeedBloc>().getPostBy(widget.id);
      if (!mounted) return;
      setState(() {
        _block = value;
        _hasData = value != null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _removals?.cancel();
    super.dispose();
  }

  /// This post deleted, hidden or archived, or its author blocked. Done on
  /// this page (it is the one on top): step back, as after a reload that
  /// finds it gone. Done elsewhere while this page waits below: "No post
  /// found" here instead of a post that can't be liked or saved any more.
  void _onRemoved(PostRemoval removal) {
    final block = _block;
    if (!mounted || block == null) return;
    if (!removal.removes(postId: block.id, authorId: block.author.id)) return;
    if ((ModalRoute.of(context)?.isCurrent ?? false) &&
        Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _block = null;
      _hasData = false;
    });
  }

  /// Re-reads the post. If it has gone (the owner just deleted it) there is
  /// nothing left to show, so step back to wherever we came from — the map's
  /// place list, the profile grid — instead of rendering a missing post.
  Future<void> _reload() async {
    if (_block == null) return _load();
    final PostBlock? value;
    try {
      value = await context.read<FeedBloc>().getPostBy(widget.id);
    } catch (_) {
      // Couldn't read it: the post stays as it was, not closed as gone.
      return;
    }
    if (!mounted) return;
    if (value == null) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _block = value;
      _hasData = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Read once into a local so the null check can't race a rebuild.
    final block = _block;
    return RefreshIndicator.adaptive(
      onRefresh: _reload,
      child: CustomScrollView(
        slivers: [
          SliverAnimatedSwitcher(
            duration: 150.ms,
            child: !_isLoading && _hasData && block != null
                ? SliverToBoxAdapter(
                    child: PostView(
                      key: ValueKey(block.id),
                      block: block,
                      withCustomVideoPlayer: false,
                      withInViewNotifier: false,
                    ),
                  )
                : _isLoading
                ? const PostPreviewLoading()
                : _failed
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: LoadFailed(onRetry: _load),
                  )
                : const PostPreviewNotFound(),
          ),
        ],
      ),
    );
  }
}

class PostPreviewLoading extends StatelessWidget {
  const PostPreviewLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}
