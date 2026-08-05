import 'package:flutter/material.dart';
import 'package:gallery_media_picker/src/core/decode_image.dart';
import 'package:gallery_media_picker/src/core/functions.dart';
import 'package:gallery_media_picker/src/presentation/pages/gallery_media_picker_controller.dart';
import 'package:photo_manager/photo_manager.dart';

class CoverThumbnail extends StatefulWidget {
  const CoverThumbnail({
    super.key,
    this.thumbnailQuality = 120,
    this.thumbnailScale = 1.0,
    this.thumbnailFit = BoxFit.cover,
  });
  final int thumbnailQuality;
  final double thumbnailScale;
  final BoxFit thumbnailFit;

  @override
  State<CoverThumbnail> createState() => _CoverThumbnailState();
}

class _CoverThumbnailState extends State<CoverThumbnail> {
  /// create object of PickerDataProvider
  final provider = GalleryMediaPickerController();

  @override
  void initState() {
    // Guarded at call time, not here: the permission prompt is async, so this
    // fires long after initState — checking `mounted` now says nothing about
    // whether the widget still exists when the answer arrives.
    GalleryFunctions.getPermission((fn) {
      if (mounted) setState(fn);
    }, provider);
    super.initState();
  }

  @override
  void dispose() {
    provider.pickedFile.clear();
    provider.picked.clear();
    provider.pathList.clear();
    PhotoManager.stopChangeNotify();
    // Always last, and never conditional — the framework requires it.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return provider.pathList.isNotEmpty
        ? Image(
            image: DecodeImage(
              provider.pathList[0],
              thumbSize: widget.thumbnailQuality,
              scale: widget.thumbnailScale,
            ),
            fit: widget.thumbnailFit,
            filterQuality: FilterQuality.high,
          )
        : const Icon(Icons.photo_camera_back_outlined);
  }
}
