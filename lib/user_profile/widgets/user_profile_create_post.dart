// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/feed.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/home/home.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/map/location_picker_map.dart';
import 'package:treepnet/stories/view/create_story_flow.dart';

class UserProfileCreatePost extends StatelessWidget {
  const UserProfileCreatePost({
    this.canPop = true,
    this.imagePickerKey,
    this.pickVideo = false,
    this.onPopInvoked,
    this.onBackButtonTap,
    super.key,
    this.wantKeepAlive = true,
  });

  final bool canPop;
  final Key? imagePickerKey;
  final bool pickVideo;
  final bool wantKeepAlive;
  final VoidCallback? onBackButtonTap;
  final VoidCallback? onPopInvoked;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Embedded on the home PageView: back must return to the feed, not do
      // nothing. But when the New post camera is open, back returns to the
      // gallery grid first, so the user stays in New post.
      onWillPop: () async {
        final picker = customImagePickerKey.currentState;
        if (picker?.isOnCamera ?? false) {
          picker!.backToGrid();
          return false;
        }
        if (onPopInvoked != null) {
          onPopInvoked!.call();
          return false;
        }
        return true;
      },
      child: _CreateSurface(
        builder: (onCameraTabChanged) => PickImage().customMediaPicker(
          onCameraTabChanged: onCameraTabChanged,
          key: imagePickerKey,
          context: context,
          source: ImageSource.both,
          // Photos only — video upload (gallery, camera and reels) is disabled.
          pickerSource: PickerSource.image,
          multiSelection: true,
          wantKeepAlive: wantKeepAlive,
          onMediaPicked: (details) => context.pushNamed(
            AppRoutes.publishPost.name,
            extra: CreatePostProps(details: details, pickVideo: pickVideo),
          ),
          onBackButtonTap: onBackButtonTap != null
              ? () => onBackButtonTap?.call()
              : null,
        ),
      ),
    );
  }
}

/// Holds the picker and, on the gallery tab only, the Post/Story row.
///
/// The row is hidden behind the viewfinder: the camera has its own controls
/// down there, and two bars stacked on top of each other read as a bug.
class _CreateSurface extends StatefulWidget {
  const _CreateSurface({required this.builder});

  final Widget Function(ValueChanged<bool> onCameraTabChanged) builder;

  @override
  State<_CreateSurface> createState() => _CreateSurfaceState();
}

class _CreateSurfaceState extends State<_CreateSurface> {
  bool _onCamera = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: widget.builder((onCamera) {
            if (_onCamera != onCamera) setState(() => _onCamera = onCamera);
          }),
        ),
        if (!_onCamera)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _PostOrStoryBar(),
          ),
      ],
    );
  }
}

/// The two things "+" can make, floating over the grid.
///
/// Post is where you already are; Story hands off to the story camera — the
/// same one the feed's Share button opens, so the two entry points cannot
/// drift apart.
class _PostOrStoryBar extends StatelessWidget {
  const _PostOrStoryBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            // Translucent rather than opaque: the row sits on the grid, so the
            // thumbnails stay readable behind it.
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: ColoredBox(
              color: AppColors.black.withValues(alpha: 0.55),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeLabel(
                        label: context.l10n.postText,
                        selected: true,
                      ),
                    ),
                    Expanded(
                      child: _ModeLabel(
                        label: context.l10n.storyText,
                        selected: false,
                        onTap: () {
                          final user = context.read<AppBloc>().state.user;
                          startStoryCreation(context, user);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeLabel extends StatelessWidget {
  const _ModeLabel({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          style: context.titleMedium?.copyWith(
            color: selected ? AppColors.white : AppColors.textSecondary,
            fontWeight: selected ? AppFontWeight.bold : AppFontWeight.medium,
          ),
        ),
      ),
    );
  }
}

class CreatePostProps {
  const CreatePostProps({
    required this.details,
    this.pickVideo = false,
    this.locationSeed,
  });

  final SelectedImagesDetails details;
  final bool pickVideo;

  /// Place to pre-fill, when the flow started from a spot on the map instead
  /// of from the create tab. Null means "ask for one".
  final LocationSeed? locationSeed;
}

/// A place carried into the create-post flow.
class LocationSeed {
  /// {@macro location_seed}
  const LocationSeed({
    required this.region,
    required this.lat,
    required this.lng,
  });

  final GeoRegion region;
  final double lat;
  final double lng;
}

/// Opens the media picker and, once something is chosen, the publish page with
/// [seed] already filled in.
///
/// Lives here next to the flow it starts, so callers elsewhere (the map) don't
/// have to know how a post gets made.
Future<void> createPostAt(BuildContext context, LocationSeed seed) async {
  final details = await PickImage().pickImage(
    context,
    source: ImageSource.both,
    multiImages: true,
  );
  if (details == null || !context.mounted) return;
  await context.pushNamed(
    AppRoutes.publishPost.name,
    extra: CreatePostProps(details: details, locationSeed: seed),
  );
}

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({required this.props, super.key});

  final CreatePostProps props;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  /// The post description (caption).
  String _caption = '';

  /// Tagged people (space-separated `@handles`), appended to the caption.
  String _mentions = '';

  /// Structured region selected via the map picker (colors the profile map).
  GeoRegion? _region;

  /// Exact coordinates the pin was dropped on (a marker per post on the map).
  double? _lat;
  double? _lng;

  /// The custom name the user typed for the spot (e.g. "Kiz Kulesi").
  String? _placeName;

  late List<Media> _media;
  bool _sharing = false;

  /// Set when the user tries to publish without a location (required — the
  /// region is what colors their travel map, Treepnet's whole differentiator).
  bool _locationError = false;

  List<SelectedByte> get selectedFiles => widget.props.details.selectedFiles;

  @override
  void initState() {
    super.initState();
    // Came from a spot on the map: that place is the answer, don't re-ask.
    final seed = widget.props.locationSeed;
    if (seed != null) {
      _region = seed.region;
      _lat = seed.lat;
      _lng = seed.lng;
    }
    _media = selectedFiles
        .map(
          (e) => e.isThatImage
              ? MemoryImageMedia(bytes: e.selectedByte, id: uuid.v4())
              : MemoryVideoMedia(id: uuid.v4(), file: e.selectedFile),
        )
        .toList();
  }

  /// The final caption stored with the post: the description with any tagged
  /// people appended on a new line (there is no separate mentions column yet).
  String get _fullCaption {
    final caption = _caption.trim();
    final mentions = _mentions.trim();
    if (mentions.isEmpty) return caption;
    return caption.isEmpty ? mentions : '$caption\n$mentions';
  }

  Future<void> _onShareTap() async {
    if (_sharing) return;
    // A named location is required — it's what colors the profile travel map
    // and what everyone sees on the pin.
    if (_region == null || (_placeName ?? '').trim().isEmpty) {
      setState(() => _locationError = true);
      return;
    }
    _sharing = true;

    void goHome() {
      if (!widget.props.pickVideo) {
        HomeProvider().animateToPage(1);
        FeedPageController().scrollToTop();
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.goNamed(AppRoutes.feed.name);
      }
    }

    try {
      final postId = uuid.v4();
      final region = _region;
      unawaited(
        FeedPageController().processPostMedia(
          postId: postId,
          selectedFiles: selectedFiles,
          caption: _fullCaption,
          pickVideo: widget.props.pickVideo,
          location: region?.name,
          locationCountry: region?.countryCode,
          locationRegion: region?.iso,
          locationName: (_placeName != null && _placeName!.isNotEmpty)
              ? _placeName
              : region == null
              ? null
              : '${region.name}, ${region.countryName}',
          locationLat: _lat,
          locationLng: _lng,
        ),
      );
      goHome.call();
    } catch (error, stackTrace) {
      _sharing = false;
      toggleLoadingIndeterminate(enable: false);
      logE('Failed to create post', error: error, stackTrace: stackTrace);
      openSnackbar(
        SnackbarMessage.error(title: context.l10n.failedToCreatePostText),
      );
    }
  }

  Future<void> _editDescription() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _TextEntryPage(
          title: context.l10n.descriptionText,
          initial: _caption,
          hint: context.l10n.writeDescriptionHintText,
        ),
      ),
    );
    if (result != null) setState(() => _caption = result);
  }

  Future<void> _editMentions() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _TextEntryPage(
          title: context.l10n.tagPeopleText,
          initial: _mentions,
          hint: context.l10n.tagPeopleHintText,
          singleLine: true,
        ),
      ),
    );
    if (result != null) setState(() => _mentions = result);
  }

  Future<void> _editLocation() async {
    final picked = await showLocationPicker(context);
    if (picked != null) {
      setState(() {
        _region = picked.region;
        _lat = picked.lat;
        _lng = picked.lng;
        _placeName = picked.placeName;
        _locationError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final region = _region;
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: Colors.transparent,
        releaseFocus: true,
        resizeToAvoidBottomInset: true,
        appBar: _CreatePostAppBar(
          title: context.l10n.addInformationText,
          onConfirm: _onShareTap,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxlg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Centered square preview of the picked media.
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: PostMedia(
                        media: _media,
                        withLikeOverlay: false,
                        withInViewNotifier: false,
                        autoHideCurrentIndex: false,
                        mediaCarouselSettings:
                            const MediaCarouselSettings.empty(
                              viewportFraction: 1,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
              const Gap.v(AppSpacing.xlg),
              _InfoRow(
                value: _caption.trim().isEmpty ? null : _caption.trim(),
                placeholder: context.l10n.descriptionText,
                onTap: _editDescription,
              ),
              const Gap.v(AppSpacing.md),
              if (_locationError)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    bottom: AppSpacing.xs,
                  ),
                  child: Text(
                    context.l10n.addLocationAndNameText,
                    style: const TextStyle(
                      color: Color(0xFFE0384E),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              _InfoRow(
                value: region == null
                    ? null
                    : '${region.name}, ${region.countryName}',
                placeholder: context.l10n.locationText,
                onTap: _editLocation,
                error: _locationError,
                onClear: region == null
                    ? null
                    : () => setState(() {
                        _region = null;
                        _lat = null;
                        _lng = null;
                      }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared app bar for the create-post flow: back / centered title / ✓ confirm.
class _CreatePostAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CreatePostAppBar({required this.title, required this.onConfirm});

  final String title;
  final VoidCallback onConfirm;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        title,
        style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.check, color: Colors.white, size: 26),
          onPressed: onConfirm,
        ),
        const Gap.h(AppSpacing.sm),
      ],
    );
  }
}

/// A tappable summary row on the "Add information" screen (a dark rounded card
/// showing either its [value] or a dimmed [placeholder], with a chevron or an
/// optional clear button).
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.placeholder,
    required this.onTap,
    this.value,
    this.onClear,
    this.error = false,
  });

  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  /// Draws a red border to flag a required field left empty.
  final bool error;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: error ? Border.all(color: AppColors.red, width: 1.5) : null,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md + 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue ? value! : placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              const Gap.h(AppSpacing.sm),
              if (hasValue && onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close, color: Colors.white70),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-screen text-entry page (Figma "Description" / "Tag people"):
/// back / title / ✓, with an autofocused field. Confirming pops the text.
class _TextEntryPage extends StatefulWidget {
  const _TextEntryPage({
    required this.title,
    required this.initial,
    required this.hint,
    this.singleLine = false,
  });

  final String title;
  final String initial;
  final String hint;
  final bool singleLine;

  @override
  State<_TextEntryPage> createState() => _TextEntryPageState();
}

class _TextEntryPageState extends State<_TextEntryPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: Colors.transparent,
        releaseFocus: true,
        resizeToAvoidBottomInset: true,
        appBar: _CreatePostAppBar(
          title: widget.title,
          onConfirm: () => Navigator.of(context).pop(_controller.text.trim()),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: AppTextField(
            textController: _controller,
            autofocus: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            filled: false,
            fillColor: Colors.transparent,
            maxLines: widget.singleLine ? 1 : 12,
            textInputType: TextInputType.multiline,
            textInputAction: widget.singleLine
                ? TextInputAction.done
                : TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
            hintText: widget.hint,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 18),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            onFieldSubmitted: widget.singleLine
                ? (v) => Navigator.of(context).pop(_controller.text.trim())
                : null,
          ),
        ),
      ),
    );
  }
}
