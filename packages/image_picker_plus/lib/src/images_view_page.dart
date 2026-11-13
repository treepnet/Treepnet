import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_plus/image_picker_plus.dart';
import 'package:image_picker_plus/src/crop_image_view.dart';
import 'package:image_picker_plus/src/custom_crop.dart';
import 'package:image_picker_plus/src/image.dart';
import 'package:image_picker_plus/src/multi_selection_mode.dart';
import 'package:image_picker_plus/src/photo_crops.dart';
import 'package:image_picker_plus/src/pill_button.dart';
import 'package:image_picker_plus/src/prepare_files.dart';
import 'package:insta_assets_crop/insta_assets_crop.dart';
import 'package:shimmer/shimmer.dart';

class ImagesViewPage extends StatefulWidget {
  const ImagesViewPage({
    required this.multiSelectedMedia,
    required this.multiSelectionMode,
    required this.clearMultiImages,
    required this.appTheme,
    required this.tabsTexts,
    required this.cropImage,
    required this.multiSelection,
    required this.showInternalVideos,
    required this.showInternalImages,
    required this.showImagePreview,
    required this.gridDelegate,
    required this.maximumSelection,
    required this.filterOption,
    required this.wantKeepAlive,
    super.key,
    this.callbackFunction,
    this.onBackButtonTap,
    this.pickAvatar = false,
    this.showCameraTile = false,
    this.onCameraTap,
  });

  /// When true a camera tile is shown as the first cell of the grid.
  final bool showCameraTile;

  /// Called when the camera tile is tapped.
  final VoidCallback? onCameraTap;
  final ValueNotifier<List<File>> multiSelectedMedia;
  final ValueNotifier<bool> multiSelectionMode;
  final TabsTexts tabsTexts;
  final bool cropImage;
  final bool multiSelection;
  final bool showInternalVideos;
  final bool showInternalImages;
  final int maximumSelection;
  final AsyncValueSetter<SelectedImagesDetails>? callbackFunction;
  final bool pickAvatar;

  /// To avoid lag when you interacting with image when it expanded
  final AppTheme appTheme;
  final VoidCallback clearMultiImages;
  final bool showImagePreview;
  final SliverGridDelegateWithFixedCrossAxisCount gridDelegate;
  final VoidCallback? onBackButtonTap;
  final bool wantKeepAlive;

  final FilterOptionGroup? filterOption;

  @override
  State<ImagesViewPage> createState() => _ImagesViewPageState();
}

class _ImagesViewPageState extends State<ImagesViewPage>
    with AutomaticKeepAliveClientMixin {
  late PMFilter _filterOption;

  final ValueNotifier<List<FutureBuilder<Uint8List?>>> _mediaList =
      ValueNotifier(<FutureBuilder<Uint8List?>>[]);

  /// The backing photo-library assets, index-aligned with [_mediaList] and
  /// [allMedia]. Full files are resolved lazily from these (see [_resolveFile])
  /// instead of up front — resolving every asset's original on iOS exports it
  /// from the Photos library (and can pull from iCloud), which blocked the
  /// grid.
  final List<AssetEntity> _assets = <AssetEntity>[];

  final ValueNotifier<List<File?>> allMedia = ValueNotifier(<File?>[]);

  /// Each picked photo's crop, kept under that photo (see [PhotoCrops]).
  final _crops = PhotoCrops();

  /// The photo in the preview ([selectedMedia]) as of the last change, so its
  /// crop can be kept when the preview moves to another one.
  File? _previewFile;

  /// The photo the crop preview has finished loading: until it is the one in
  /// [selectedMedia], the preview's crop is still the previous photo's.
  final previewShown = ValueNotifier<File?>(null);

  final selectedMedia = ValueNotifier<File?>(null);
  final ValueNotifier<List<int>> indexOfSelectedMedia = ValueNotifier(<int>[]);

  final scrollController = ScrollController();

  final ValueNotifier<bool> expandMedia = ValueNotifier(false);
  final expandHeight = ValueNotifier<double>(0);
  final moveAwayHeight = ValueNotifier<double>(0);
  final ValueNotifier<bool> expandImageView = ValueNotifier(false);

  final ValueNotifier<bool> isMediaReady = ValueNotifier(false);
  final ValueNotifier<int> currentPage = ValueNotifier(0);
  final ValueNotifier<int> lastPage = ValueNotifier(0);

  /// To avoid lag when you interacting with image when it expanded
  final ValueNotifier<bool> enableVerticalTapping = ValueNotifier(false);
  final cropKey = GlobalKey<CustomCropState>();
  final ValueNotifier<bool> noPaddingForGridView = ValueNotifier(false);

  final scrollPixels = ValueNotifier<double>(0);
  final ValueNotifier<bool> isScrolling = ValueNotifier(false);
  final ValueNotifier<bool> noMedia = ValueNotifier(false);

  /// Photo access refused: the gallery says so and offers Settings (it said
  /// "There is no media", with no way out).
  final ValueNotifier<bool> noAccess = ValueNotifier(false);

  /// Only the photos the user chose are visible (iOS "Selected Photos",
  /// Android 14 partial access): a button adds more.
  final ValueNotifier<bool> limitedAccess = ValueNotifier(false);

  /// Back from Settings with access now given: load the gallery.
  late final AppLifecycleListener _lifecycle;
  final ValueNotifier<bool> noDuration = ValueNotifier(false);

  AppTheme get appTheme => widget.appTheme;

  void resetAll() {
    selectedMedia.value = allMedia.value.isEmpty ? null : allMedia.value.first;
    widget.multiSelectedMedia.value = [];
    widget.multiSelectionMode.value = false;
    _crops.clear();
  }

  @override
  void dispose() {
    _mediaList.dispose();
    allMedia.dispose();
    scrollController.dispose();
    isMediaReady.dispose();
    lastPage.dispose();
    expandMedia.dispose();
    expandHeight.dispose();
    moveAwayHeight.dispose();
    expandImageView.dispose();
    enableVerticalTapping.dispose();
    noDuration.dispose();
    _lifecycle.dispose();
    noAccess.dispose();
    limitedAccess.dispose();
    selectedMedia.removeListener(_onPreviewChanged);
    previewShown.dispose();
    _busy.dispose();
    indexOfSelectedMedia.dispose();
    super.dispose();
  }

  @override
  void initState() {
    selectedMedia.addListener(_onPreviewChanged);
    _lifecycle = AppLifecycleListener(onResume: _recheckAccess);
    _applyFilerOption();

    _fetchNewMedia(currentPageValue: 0);
    super.initState();
  }

  void _applyFilerOption() {
    final newOption = FilterOptionGroup(
      imageOption: const FilterOption(
        sizeConstraint: SizeConstraint(ignoreSize: true),
      ),
      audioOption: const FilterOption(
        needTitle: true,
        sizeConstraint: SizeConstraint(ignoreSize: true),
      ),
      createTimeCond: DateTimeCond.def().copyWith(ignore: true),
      updateTimeCond: DateTimeCond.def().copyWith(ignore: true),
    );
    if (widget.filterOption != null) {
      newOption.merge(widget.filterOption!);
    }
    _filterOption = newOption;
  }

  bool _handleScrollEvent(
    ScrollNotification scroll, {
    required int currentPageValue,
    required int lastPageValue,
  }) {
    if (scroll.metrics.pixels / scroll.metrics.maxScrollExtent > 0.33 &&
        currentPageValue != lastPageValue) {
      _fetchNewMedia(currentPageValue: currentPageValue);
      return true;
    }
    return false;
  }

  Future<void> _fetchNewMedia({required int currentPageValue}) async {
    lastPage.value = currentPageValue;
    // Request ONLY the media types this picker actually shows. Requesting the
    // default (images + videos) failed on Android 13+ when READ_MEDIA_VIDEO is
    // not declared, so an images-only build was treated as "denied" and bounced
    // the user to system settings.
    final type = widget.showInternalVideos && widget.showInternalImages
        ? RequestType.common
        : (widget.showInternalImages ? RequestType.image : RequestType.video);
    final result = await PhotoManager.requestPermissionExtend(
      requestOption: PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: type,
          mediaLocation: false,
        ),
      ),
    );
    // `hasAccess` (not `isAuth`) so users who grant *limited* photo access
    // still see their selected photos instead of being treated as denied.
    if (!mounted) return;
    limitedAccess.value = result == PermissionState.limited;
    if (result.hasAccess && noAccess.value) noAccess.value = false;
    if (result.hasAccess) {
      final albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: type,
        filterOption: _filterOption,
      );
      if (albums.isEmpty) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => noMedia.value = true);
        return;
      } else if (noMedia.value) {
        noMedia.value = false;
      }

      final media = await albums[0].getAssetListPaged(
        page: currentPageValue,
        size: 60,
      );
      if (media.isEmpty) {
        // Just the end of the album. Only an empty *first* page means the
        // gallery is genuinely empty — treating every exhausted page as
        // "no media" wiped the grid as soon as you scrolled to the bottom.
        if (currentPageValue == 0 && allMedia.value.isEmpty) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => noMedia.value = true);
        }
        return;
      }
      // Build ONLY the (lazy) thumbnails here. The full-resolution File of each
      // asset is deliberately NOT resolved up front: on iOS `AssetEntity.file`
      // exports the original from the Photos library (and may download it from
      // iCloud), so resolving all 60 per page sequentially blocked the grid for
      // ~10s. Files are resolved on demand in [_resolveFile] when a tile is
      // actually tapped/selected; the grid renders immediately from thumbnails.
      final temp = <FutureBuilder<Uint8List?>>[];
      for (var i = 0; i < media.length; i++) {
        temp.add(getImageGallery(media, i));
      }
      _assets.addAll(media);
      _mediaList.value.addAll(temp);
      allMedia.value.addAll(
        List<File?>.filled(media.length, null, growable: true),
      );

      currentPage.value++;
      isMediaReady.value = true;
      // Resolve just the FIRST asset so the crop preview has something to show
      // and single-select keeps its "first image pre-selected" behaviour. One
      // export — cheap — and only on the first page. After the grid is shown,
      // and allowed to fail: it used to come first, unguarded, so one photo
      // that couldn't be had (only in iCloud, offline) left the picker loading
      // for good, blocking new posts and stories. Then nothing is preselected.
      if (currentPageValue == 0 &&
          selectedMedia.value == null &&
          _assets.isNotEmpty) {
        unawaited(_preselectFirst());
      }
      // Guard against setState after the page was disposed (fast back-out while
      // media is still paging in) — otherwise the post-frame callback throws
      // "Null check operator used on a null value".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      // Respect the user's decision — do NOT force-open the Settings app
      // (App Store Guideline 5.1.1(iv)). Show the no-access state, whose
      // button opens Settings only when tapped.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) noAccess.value = true;
      });
    }
  }

  /// Loads the gallery again from the first page (after Settings or adding
  /// photos to limited access). The selection is cleared: its files belong
  /// to the old list.
  void _reloadGallery() {
    _assets.clear();
    _mediaList.value = <FutureBuilder<Uint8List?>>[];
    allMedia.value = <File?>[];
    currentPage.value = 0;
    lastPage.value = 0;
    clearMultiImages();
    selectedMedia.value = null;
    _fetchNewMedia(currentPageValue: 0);
  }

  /// The media types this picker shows (only those are asked for: asking
  /// for videos without READ_MEDIA_VIDEO failed on Android 13+).
  RequestType get _requestType =>
      widget.showInternalVideos && widget.showInternalImages
          ? RequestType.common
          : (widget.showInternalImages ? RequestType.image : RequestType.video);

  /// Back in the app with access refused: if it was given in Settings, load
  /// the gallery. Only reads the state: asking here would show Android's
  /// permission dialog again on every resume (the dialog itself pauses and
  /// resumes the app).
  Future<void> _recheckAccess() async {
    if (!noAccess.value) return;
    final state = await PhotoManager.getPermissionState(
      requestOption: PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: _requestType,
          mediaLocation: false,
        ),
      ),
    );
    if (state.hasAccess && mounted) _reloadGallery();
  }

  Future<void> _selectMorePhotos() async {
    await PhotoManager.presentLimited(type: _requestType);
    if (mounted) _reloadGallery();
  }

  Widget _noAccessView() {
    return Stack(
      children: [
        normalAppBar(withDoneButton: false, noImages: true),
        Align(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.tabsTexts.noPhotoAccessText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                PickerPillButton(
                  label: widget.tabsTexts.openSettingsText,
                  onPressed: PhotoManager.openSetting,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The "Select more photos" pill over the bottom of the grid, with limited
  /// access only.
  Widget _selectMoreButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: limitedAccess,
      builder: (context, limited, _) {
        if (!limited) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: 16),
            child: PickerPillButton(
              label: widget.tabsTexts.selectMorePhotosText,
              icon: Icons.add,
              onPressed: _selectMorePhotos,
            ),
          ),
        );
      },
    );
  }

  FutureBuilder<Uint8List?> getImageGallery(List<AssetEntity> media, int i) {
    final highResolution = widget.gridDelegate.crossAxisCount <= 3;
    final futureBuilder = FutureBuilder<Uint8List?>(
      future: media[i].thumbnailDataWithSize(
        highResolution
            ? const ThumbnailSize(350, 350)
            : const ThumbnailSize(200, 200),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final image = snapshot.data;
          if (image != null) {
            return ColoredBox(
              color: const Color.fromARGB(255, 189, 189, 189),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: MemoryImageDisplay(
                      imageBytes: image,
                      appTheme: widget.appTheme,
                    ),
                  ),
                  if (media[i].type == AssetType.video) ...[
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 2),
                        child: VideoThumbnailFooter(asset: media[i]),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }
        }
        return const SizedBox();
      },
    );
    return futureBuilder;
  }

  /// Resolves (and caches) the full-resolution [File] for the asset at [index].
  ///
  /// This is the ONLY place `AssetEntity.file` is called, and only for tiles
  /// the user actually interacts with — so the expensive iOS Photos export
  /// happens per selection instead of for every tile up front. The resolved
  /// file is written back into [allMedia] so a second call is free and,
  /// crucially, so selection equality (the same [File] instance lands in
  /// `multiSelectedMedia`) keeps working.
  Future<File?> _resolveFile(int index) async {
    if (index < 0 || index >= _assets.length) return null;
    final cached = index < allMedia.value.length ? allMedia.value[index] : null;
    if (cached != null) return cached;
    final file = await _assets[index].file;
    if (file != null && index < allMedia.value.length) {
      allMedia.value[index] = file;
    }
    return file;
  }

  Future<void> _preselectFirst() async {
    try {
      final first = await _resolveFile(0);
      if (first != null && mounted && selectedMedia.value == null) {
        selectedMedia.value = first;
      }
    } catch (_) {
      // Unavailable: the user picks another one.
    }
  }

  /// A tapped photo's file can't be had: say so instead of nothing.
  void _showUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(widget.tabsTexts.photoUnavailableText)),
    );
  }

  /// Tap on a tile: resolve its file lazily, then run the normal select logic.
  Future<void> _handleTap(int index) async {
    final File? image;
    try {
      image = await _resolveFile(index);
    } catch (_) {
      _showUnavailable();
      return;
    }
    if (!mounted) return;
    if (image == null) return _showUnavailable();
    onTapImage(image, widget.multiSelectedMedia.value, index);
  }

  /// Long-press release on a tile — mirrors the original inline handler, but
  /// resolves the file first (see [_resolveFile]).
  Future<void> _handleLongPressUp(int index) async {
    final File? image;
    try {
      image = await _resolveFile(index);
    } catch (_) {
      _showUnavailable();
      return;
    }
    if (!mounted) return;
    if (image == null) return _showUnavailable();
    if (widget.multiSelectionMode.value) {
      selectionImageCheck(
        image,
        widget.multiSelectedMedia.value,
        index,
        enableCopy: true,
      );
      expandImageView.value = false;
      moveAwayHeight.value = 0;
      enableVerticalTapping.value = false;
      noPaddingForGridView.value = true;
    } else {
      onTapImage(image, widget.multiSelectedMedia.value, index);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<bool>(
      valueListenable: noAccess,
      builder: (context, refused, _) =>
          refused ? _noAccessView() : _galleryOrEmpty(),
    );
  }

  Widget _galleryOrEmpty() {
    return ValueListenableBuilder<bool>(
      valueListenable: noMedia,
      builder: (context, noImages, child) {
        if (noImages) {
          return Stack(
            children: [
              normalAppBar(withDoneButton: false, noImages: true),
              Align(
                child: Text(
                  widget.tabsTexts.noMediaFound,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Limited access with nothing chosen yet looks empty too.
              _selectMoreButton(),
            ],
          );
        } else {
          return Stack(
            fit: StackFit.expand,
            children: [
              buildGridView(),
              _selectMoreButton(),
            ],
          );
        }
      },
    );
  }

  Widget buildGridView() {
    return ValueListenableBuilder(
      valueListenable: isMediaReady,
      builder: (context, bool isImagesReadyValue, child) {
        if (isImagesReadyValue) {
          return ValueListenableBuilder<List<FutureBuilder<Uint8List?>>>(
            valueListenable: _mediaList,
            builder: (context, mediaList, child) {
              return ValueListenableBuilder(
                valueListenable: lastPage,
                builder: (context, int lastPageValue, child) =>
                    ValueListenableBuilder(
                  valueListenable: currentPage,
                  builder: (context, int currentPageValue, child) {
                    if (!widget.showImagePreview) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          normalAppBar(),
                          Flexible(
                            child: normalGridView(
                              mediaList,
                              currentPageValue,
                              lastPageValue,
                            ),
                          ),
                        ],
                      );
                    } else {
                      return instagramGridView(
                        mediaList,
                        currentPageValue,
                        lastPageValue,
                      );
                    }
                  },
                ),
              );
            },
          );
        } else {
          return loadingWidget();
        }
      },
    );
  }

  Widget loadingWidget() {
    return SingleChildScrollView(
      child: Column(
        children: [
          appBar(),
          Shimmer.fromColors(
            baseColor: widget.appTheme.shimmerBaseColor,
            highlightColor: widget.appTheme.shimmerHighlightColor,
            child: Column(
              children: [
                if (widget.showImagePreview) ...[
                  Container(
                    color: appTheme.shimmerHighlightColor,
                    height: 360,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 1),
                ],
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.gridDelegate.crossAxisSpacing,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    primary: false,
                    gridDelegate: widget.gridDelegate,
                    itemBuilder: (context, index) {
                      return Container(
                        color: appTheme.shimmerHighlightColor,
                        width: double.infinity,
                      );
                    },
                    itemCount: 40,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar appBar() {
    return AppBar(
      backgroundColor: appTheme.surfaceColor,
      elevation: 0,
      leading: exitButton(),
      centerTitle: false,
      title: Text(
        widget.pickAvatar
            ? widget.tabsTexts.newAvatarImageText
            : widget.tabsTexts.newPostText,
      ),
    );
  }

  Widget normalAppBar({bool withDoneButton = true, bool noImages = false}) {
    final width = MediaQuery.sizeOf(context).width;

    return Container(
      color: widget.appTheme.surfaceColor,
      height: 56,
      width: width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              exitButton(),
              const SizedBox(width: 24),
              Text(
                widget.pickAvatar
                    ? widget.tabsTexts.newAvatarImageText
                    : widget.tabsTexts.newPostText,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          if (withDoneButton) ...[
            doneButton(),
          ],
        ],
      ),
    );
  }

  IconButton exitButton() {
    return IconButton(
      icon: Icon(Icons.clear_rounded, color: appTheme.onSurfaceColor, size: 30),
      onPressed: () {
        if (widget.onBackButtonTap == null) {
          Navigator.of(context).maybePop();
        } else {
          widget.onBackButtonTap!.call();
        }
        resetAll();
      },
    );
  }

  /// The preview moved off a photo: keep that photo's crop as it was left.
  void _onPreviewChanged() {
    final previous = _previewFile;
    _previewFile = selectedMedia.value;
    if (previous == null || previous.path == _previewFile?.path) return;
    _saveCrop(previous);
  }

  void _saveCrop(File file) {
    final crop = cropKey.currentState?.cropOf(file);
    if (crop != null) _crops.save(file.path, crop, aspect: _aspect);
  }

  /// The frame's shape: 4:5 when expanded, else square.
  double get _aspect => expandMedia.value ? 4 / 5 : 1.0;

  /// [file]'s crop: the preview's when it shows [file], else the one kept
  /// when the preview left it, else the middle of the photo (it was never on
  /// screen long enough to load, or was cropped for the other frame shape).
  Future<PhotoCrop?> _cropFor(File file) async {
    final live = cropKey.currentState?.cropOf(file);
    if (live != null) return live;
    return _crops.of(file.path, aspect: _aspect) ??
        await PhotoCrops.centeredOf(file.path, aspect: _aspect);
  }

  /// Next is enabled once the photo in the preview has loaded: before that the
  /// preview's crop is still the previous photo's, and the photo used to go
  /// out uncropped.
  bool _previewReady(File? preview, File? shown) =>
      preview != null &&
      (!widget.showImagePreview ||
          !widget.cropImage ||
          preview.isVideo ||
          shown?.path == preview.path);

  /// Next is working (cropping and reading the photos): it shows a spinner
  /// and ignores taps. There was no sign for the seconds 5–10 photos take, a
  /// second tap opened a second "add details" page (a second post), and a
  /// second tap while picking an avatar could close the edit page too.
  final _busy = ValueNotifier<bool>(false);

  Widget doneButton() {
    return ListenableBuilder(
      listenable: Listenable.merge([selectedMedia, previewShown, _busy]),
      builder: (context, _) {
        if (_busy.value) {
          return const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          );
        }
        final ready = _previewReady(selectedMedia.value, previewShown.value);
        return IconButton(
          icon: Icon(
            Icons.arrow_forward_rounded,
            color: ready ? Colors.white : Colors.white.withValues(alpha: 0.35),
            size: 30,
          ),
          onPressed: ready ? _onNext : null,
        );
      },
    );
  }

  /// A photo that can't be opened or cropped: say so (it used to fail
  /// silently, Next doing nothing).
  void _showCantUse() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(widget.tabsTexts.photoCantBeUsedText)),
    );
  }

  /// [file] cropped (a photo) and read, ready to post. Throws when it can't be.
  Future<SelectedByte> _prepare(File file) async {
    final isThatVideo = file.isVideo;
    final cropped =
        !isThatVideo && widget.cropImage ? await cropImage(file) : null;
    final ready = cropped ?? file;
    return SelectedByte(
      isThatImage: !isThatVideo,
      selectedFile: ready,
      selectedByte: await ready.readAsBytes(),
    );
  }

  Future<void> _onNext() async {
    if (_busy.value) return;
    _busy.value = true;
    try {
      await _next();
    } finally {
      if (mounted) _busy.value = false;
    }
  }

  Future<void> _next() async {
    final aspect = _aspect;
    final multi = widget.multiSelectionMode.value && widget.multiSelection;
    final List<File> files;
    if (multi) {
      files = List<File>.of(widget.multiSelectedMedia.value);
    } else {
      final image = selectedMedia.value;
      if (image == null) return;
      files = [image];
    }
    if (files.isEmpty) return;

    final done = await prepareTwoAtATime(files, _prepare);
    final prepared = done.results;
    final failed = done.failed;
    if (!mounted) return;
    if (failed.isNotEmpty) {
      // Out of the selection; the rest stay picked for another Next.
      final failedPaths = {for (final f in failed) f.path};
      final remaining = [
        for (final f in widget.multiSelectedMedia.value)
          if (!failedPaths.contains(f.path)) f,
      ];
      widget.multiSelectedMedia.value = remaining;
      for (final f in failed) {
        _crops.remove(f.path);
      }
      if (remaining.isNotEmpty &&
          failedPaths.contains(selectedMedia.value?.path)) {
        selectedMedia.value = remaining.last;
      }
      _showCantUse();
      return;
    }

    final details = SelectedImagesDetails(
      selectedFiles: prepared.cast<SelectedByte>(),
      multiSelectionMode: multi,
      aspectRatio: aspect,
    );
    if (widget.callbackFunction != null) {
      await widget.callbackFunction!(details);
    } else {
      await Navigator.of(context).maybePop(details);
    }
  }

  Widget normalGridView(
    List<FutureBuilder<Uint8List?>> mediaListValue,
    int currentPageValue,
    int lastPageValue,
  ) {
    return NotificationListener(
      onNotification: (ScrollNotification notification) {
        _handleScrollEvent(
          notification,
          currentPageValue: currentPageValue,
          lastPageValue: lastPageValue,
        );
        return true;
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.gridDelegate.crossAxisSpacing,
        ),
        child: GridView.builder(
          gridDelegate: widget.gridDelegate,
          itemBuilder: (context, index) {
            if (widget.showCameraTile) {
              if (index == 0) return cameraTile();
              return buildImage(mediaListValue, index - 1);
            }
            return buildImage(mediaListValue, index);
          },
          itemCount: mediaListValue.length + (widget.showCameraTile ? 1 : 0),
        ),
      ),
    );
  }

  /// The camera launcher shown as the first grid cell (Instagram-style).
  Widget cameraTile() {
    return GestureDetector(
      onTap: () => widget.onCameraTap?.call(),
      child: Container(
        color: widget.appTheme.shimmerBaseColor,
        child: Icon(
          Icons.photo_camera_rounded,
          color: widget.appTheme.onSurfaceColor,
          size: 34,
        ),
      ),
    );
  }

  ValueListenableBuilder<File?> buildImage(
    List<FutureBuilder<Uint8List?>> mediaListValue,
    int index,
  ) {
    return ValueListenableBuilder(
      valueListenable: selectedMedia,
      builder: (context, File? selectedImageValue, child) {
        return ValueListenableBuilder(
          valueListenable: allMedia,
          builder: (context, List<File?> allImagesValue, child) {
            return ValueListenableBuilder(
              valueListenable: widget.multiSelectedMedia,
              builder: (context, List<File> selectedImagesValue, child) {
                final mediaList = mediaListValue[index];
                // The File may be null until this tile is tapped (resolved
                // lazily). The tile still renders from its thumbnail; only the
                // File-dependent overlays (selection blur, multi-select badge)
                // wait for a resolved File.
                final image = index < allImagesValue.length
                    ? allImagesValue[index]
                    : null;
                final imageSelected =
                    image != null && selectedImagesValue.contains(image);

                return Stack(
                  children: [
                    gestureDetector(index, mediaList),
                    if (image != null && selectedImageValue == image)
                      gestureDetector(index, blurContainer()),
                    if (image != null)
                      MultiSelectionMode(
                        appTheme: widget.appTheme,
                        image: image,
                        multiSelectionMode: widget.multiSelectionMode,
                        imageSelected: imageSelected,
                        multiSelectedImage: selectedImagesValue,
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Container blurContainer() {
    return Container(
      width: double.infinity,
      color: widget.appTheme.outlineColor.withValues(alpha: 0.4),
      height: double.maxFinite,
    );
  }

  Widget gestureDetector(int index, Widget childWidget) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.multiSelectionMode,
        widget.multiSelectedMedia,
      ]),
      builder: (context, child) {
        return GestureDetector(
          key: ValueKey(index),
          onTap: () => _handleTap(index),
          onLongPress: () {
            if (widget.multiSelection) {
              widget.multiSelectionMode.value = true;
            }
          },
          onLongPressUp: () => _handleLongPressUp(index),
          child: childWidget,
        );
      },
    );
  }

  void onTapImage(File image, List<File> selectedImagesValue, int index) {
    // setState(() {
    if (widget.multiSelectionMode.value) {
      final close = selectionImageCheck(image, selectedImagesValue, index);
      if (close) return;
    }
    selectedMedia.value = image;
    expandImageView.value = false;
    moveAwayHeight.value = 0;
    enableVerticalTapping.value = false;
    noPaddingForGridView.value = true;
    // });
  }

  /// A tap in multi-select. A selected photo is taken out, and the preview
  /// moves to the last one still selected (it used to show the photo just
  /// taken out). Another photo is added, up to the limit, and shown. Each
  /// change sets a new list, so the number badges update at once (edits in
  /// place notified no one). Returns true when the tap is fully handled.
  bool selectionImageCheck(
    File image,
    List<File> multiSelectionValue,
    int index, {
    bool enableCopy = false,
  }) {
    final selected = List<File>.of(multiSelectionValue);
    if (selected.contains(image)) {
      selected.remove(image);
      indexOfSelectedMedia.value = List<int>.of(indexOfSelectedMedia.value)
        ..remove(index);
      widget.multiSelectedMedia.value = selected;
      selectedMedia.value = selected.isNotEmpty ? selected.last : image;
      // After the preview moved (which keeps the crop of the photo it leaves).
      _crops.remove(image.path);
      return true;
    }
    if (selected.length < widget.maximumSelection) {
      selected.add(image);
      indexOfSelectedMedia.value = [...indexOfSelectedMedia.value, index];
      widget.multiSelectedMedia.value = selected;
    }
    selectedMedia.value = image;
    return false;
  }

  /// [imageFile] cropped as [_cropFor] says; null when it can't be (then the
  /// photo goes as it is).
  Future<File?> cropImage(File imageFile) async {
    final crop = await _cropFor(imageFile);
    if (crop == null) return null;
    // No InstaAssetsCrop.requestPermissions(): the photo is already a file
    // the app can read, and the crop goes to the app's own temp folder. On
    // Android it asked for storage write access (removed from the manifest,
    // so never granted) before every photo.

    final sample = await InstaAssetsCrop.sampleImage(
      file: imageFile,
      preferredSize: (2000 / crop.scale).round(),
    );

    final file = await InstaAssetsCrop.cropImage(
      file: sample,
      area: crop.area,
    );
    await sample.delete();
    return file;
  }

  void clearMultiImages() {
    widget.multiSelectedMedia.value = [];
    widget.clearMultiImages();
    indexOfSelectedMedia.value = [];
    _crops.clear();
  }

  Widget instagramGridView(
    List<FutureBuilder<Uint8List?>> mediaList,
    int currentPageValue,
    int lastPageValue,
  ) {
    return ValueListenableBuilder<double>(
      valueListenable: expandHeight,
      builder: (context, expandedHeightValue, child) {
        return ValueListenableBuilder<double>(
          valueListenable: moveAwayHeight,
          builder: (context, moveAwayHeightValue, child) =>
              ValueListenableBuilder<double>(
            valueListenable: scrollPixels,
            builder: (context, scrollPixels, snapshot) {
              return ValueListenableBuilder<bool>(
                valueListenable: noPaddingForGridView,
                builder: (context, noPaddingForGridView, snapshot) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: expandImageView,
                    builder: (context, expandImageValue, child) {
                      final a = expandedHeightValue - 360;
                      final expandHeightV = a < 0.0 ? a : 0.0;
                      final moveAwayHeightV = moveAwayHeightValue < 360
                          ? moveAwayHeightValue * -1.0
                          : -360.0;
                      final topPosition =
                          expandImageValue ? expandHeightV : moveAwayHeightV;
                      enableVerticalTapping.value = !(topPosition == 0);
                      var padding = 2.0;
                      if (scrollPixels < 416) {
                        final pixels = 416 - scrollPixels;
                        padding = pixels >= 58 ? pixels + 2 : 58;
                      } else if (expandImageValue) {
                        padding = 58;
                      } else if (noPaddingForGridView) {
                        padding = 58;
                      } else {
                        padding = topPosition + 418;
                      }
                      final duration = noDuration.value ? 0 : 250;

                      return Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: padding),
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                expandImageView.value = false;
                                moveAwayHeight.value =
                                    scrollController.position.pixels;
                                this.scrollPixels.value =
                                    scrollController.position.pixels;
                                isScrolling.value = true;
                                noPaddingForGridView = false;
                                noDuration.value = false;
                                if (notification is ScrollEndNotification) {
                                  expandHeight.value =
                                      expandedHeightValue > 240 ? 360 : 0;
                                  isScrolling.value = false;
                                }

                                _handleScrollEvent(
                                  notification,
                                  currentPageValue: currentPageValue,
                                  lastPageValue: lastPageValue,
                                );
                                return true;
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      widget.gridDelegate.crossAxisSpacing,
                                ),
                                child: GridView.builder(
                                  gridDelegate: widget.gridDelegate,
                                  controller: scrollController,
                                  itemBuilder: (context, index) {
                                    if (widget.showCameraTile) {
                                      if (index == 0) return cameraTile();
                                      return buildImage(mediaList, index - 1);
                                    }
                                    return buildImage(mediaList, index);
                                  },
                                  itemCount: mediaList.length +
                                      (widget.showCameraTile ? 1 : 0),
                                ),
                              ),
                            ),
                          ),
                          AnimatedPositioned(
                            top: topPosition,
                            duration: Duration(milliseconds: duration),
                            child: Column(
                              children: [
                                normalAppBar(),
                                CropImageView(
                                  cropKey: cropKey,
                                  indexOfSelectedImages: indexOfSelectedMedia,
                                  withMultiSelection: widget.multiSelection,
                                  selectedImage: selectedMedia,
                                  shownImage: previewShown,
                                  appTheme: widget.appTheme,
                                  multiSelectionMode: widget.multiSelectionMode,
                                  enableVerticalTapping: enableVerticalTapping,
                                  expandHeight: expandHeight,
                                  expandImage: expandMedia,
                                  expandImageView: expandImageView,
                                  noDuration: noDuration,
                                  clearMultiImages: clearMultiImages,
                                  topPosition: topPosition,
                                  canExpand:
                                      widget.cropImage && !widget.pickAvatar,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => widget.wantKeepAlive;
}

class VideoThumbnailFooter extends StatelessWidget {
  const VideoThumbnailFooter({required this.asset, super.key});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.slow_motion_video_rounded,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 4),
        Text(
          parseDuration(asset.videoDuration.inSeconds),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            overflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }

  String parseDuration(int seconds) {
    if (seconds < 600) {
      return '${Duration(seconds: seconds)}'.substring(3, 7);
    } else if (seconds > 600 && seconds < 3599) {
      return '${Duration(seconds: seconds)}'.substring(2, 7);
    } else {
      return '${Duration(seconds: seconds)}'.substring(1, 7);
    }
  }
}
