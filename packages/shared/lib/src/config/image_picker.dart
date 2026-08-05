// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:app_ui/app_ui.dart' hide AppTheme;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_plus/image_picker_plus.dart';
import 'package:shared/shared.dart';

export 'package:image_picker_plus/src/images_view_page.dart';

class PickImage {
  factory PickImage() => _internal;

  /// {@macro image_picker}
  PickImage._();

  static final PickImage _internal = PickImage._();

  late TabsTexts _tabsTexts;

  // ignore: use_setters_to_change_properties
  void init({TabsTexts? tabsTexts}) {
    _tabsTexts = tabsTexts ?? const TabsTexts();
  }

  static final _defaultFilterOption = FilterOptionGroup(
    videoOption: FilterOption(
      durationConstraint: DurationConstraint(max: 3.minutes),
    ),
  );

  AppTheme _appTheme(BuildContext context) => AppTheme(
    // The picker paints the letterbox around the viewfinder with primaryColor,
    // so this is the backdrop colour. The confirm arrows set their own white
    // explicitly rather than borrowing it from here.
    primaryColor: const Color(0xFF191919),
    // The bands above and below the viewfinder. They took the theme's blue
    // through primaryContainerColor before.
    surfaceColor: const Color(0xFF191919),
    onSurfaceColor: context.customAdaptiveColor(
      light: AppColors.black,
      dark: AppColors.white,
    ),
    primaryContainerColor: const Color(0xFF191919),
    shimmerBaseColor: const Color(0xff2d2f2f),
    shimmerHighlightColor: const Color(0xff13151b),
  );

  SliverGridDelegateWithFixedCrossAxisCount _sliverGridDelegate() =>
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 1.7,
        mainAxisSpacing: 1.5,
      );

  Future<void> pickImagesAndVideos(
    BuildContext context, {
    required Future<void> Function(
      BuildContext context,
      SelectedImagesDetails,
    )
    onMediaPicked,
    bool cropImage = true,
    bool showPreview = true,
    int maxSelection = 10,
    bool multiSelection = true,
  }) => context.pickBoth(
    source: ImageSource.both,
    multiSelection: multiSelection,
    filterOption: _defaultFilterOption,
    galleryDisplaySettings: GalleryDisplaySettings(
      maximumSelection: maxSelection,
      showImagePreview: showPreview,
      cropImage: cropImage,
      tabsTexts: _tabsTexts,
      appTheme: _appTheme(context),
      callbackFunction: (details) => onMediaPicked.call(context, details),
    ),
  );

  Future<SelectedImagesDetails?> pickImage(
    BuildContext context, {
    ImageSource source = ImageSource.gallery,
    int maxSelection = 1,
    bool cropImage = true,
    bool multiImages = false,
    bool showPreview = true,
    bool pickAvatar = false,
    TabsTexts? tabsTexts,
    SliverGridDelegateWithFixedCrossAxisCount? gridDelegate,
  }) => context.pickImage(
    source: source,
    multiImages: multiImages,
    filterOption: _defaultFilterOption,
    galleryDisplaySettings: GalleryDisplaySettings(
      cropImage: cropImage,
      maximumSelection: maxSelection,
      showImagePreview: showPreview,
      // Callers can retitle the screen — the story flow says "New story" where
      // the default says "New post".
      tabsTexts: tabsTexts ?? _tabsTexts,
      pickAvatar: pickAvatar,
      appTheme: _appTheme(context),
      // Null keeps the picker's own roomier grid — stories use that, posts
      // pass the tight four-column one.
      gridDelegate: gridDelegate ?? _sliverGridDelegate(),
    ),
  );

  Future<void> pickVideo(
    BuildContext context, {
    required Future<void> Function(
      BuildContext context,
      SelectedImagesDetails,
    )
    onMediaPicked,
    ImageSource source = ImageSource.both,
    int maxSelection = 10,
    bool cropImage = true,
    bool multiImages = false,
    bool showPreview = true,
  }) => context.pickVideo(
    source: source,
    filterOption: _defaultFilterOption,
    galleryDisplaySettings: GalleryDisplaySettings(
      showImagePreview: showPreview,
      cropImage: cropImage,
      maximumSelection: maxSelection,
      tabsTexts: _tabsTexts,
      appTheme: _appTheme(context),
      callbackFunction: (details) => onMediaPicked.call(context, details),
    ),
  );

  Widget customMediaPicker({
    required BuildContext context,
    required ImageSource source,
    required PickerSource pickerSource,
    required ValueSetter<SelectedImagesDetails> onMediaPicked,
    Key? key,
    bool multiSelection = true,
    FilterOptionGroup? filterOption,
    VoidCallback? onBackButtonTap,
    bool wantKeepAlive = true,
    ValueChanged<bool>? onCameraTabChanged,
  }) => CustomImagePicker(
    onCameraTabChanged: onCameraTabChanged,
    key: key,
    galleryDisplaySettings: GalleryDisplaySettings(
      showImagePreview: true,
      cropImage: true,
      tabsTexts: _tabsTexts,
      appTheme: _appTheme(context),
      callbackFunction: (details) async => onMediaPicked.call(details),
    ),
    wantKeepAlive: wantKeepAlive,
    multiSelection: multiSelection,
    pickerSource: pickerSource,
    source: source,
    filterOption: _defaultFilterOption,
    onBackButtonTap: onBackButtonTap,
  );

  /// Reads image as bytes.
  Future<Uint8List> imageBytes({required File file}) =>
      compute((file) => file.readAsBytes(), file);
}
