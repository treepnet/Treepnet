import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  @override
  void initState() {
    super.initState();
    setState(() => _isLoading = true);
    context.read<FeedBloc>().getPostBy(widget.id).then((value) {
      if (!mounted) return;
      setState(() {
        _block = value;
        _hasData = value != null;
        _isLoading = false;
      });
    });
  }

  /// Re-reads the post. If it has gone (the owner just deleted it) there is
  /// nothing left to show, so step back to wherever we came from — the map's
  /// place list, the profile grid — instead of rendering a missing post.
  Future<void> _reload() async {
    final value = await context.read<FeedBloc>().getPostBy(widget.id);
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
