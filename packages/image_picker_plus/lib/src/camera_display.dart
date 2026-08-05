import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_plus/src/custom_crop.dart';
import 'package:image_picker_plus/src/entities/app_theme.dart';
import 'package:image_picker_plus/src/entities/selected_image_details.dart';
import 'package:image_picker_plus/src/entities/tabs_texts.dart';
import 'package:image_picker_plus/src/utilities/extensions/file_extension.dart';
import 'package:image_picker_plus/src/video_layout/record_count.dart';
import 'package:image_picker_plus/src/video_layout/record_fade_animation.dart';
import 'package:insta_assets_crop/insta_assets_crop.dart';

class CustomCameraDisplay extends StatefulWidget {
  const CustomCameraDisplay({
    required this.appTheme,
    required this.tabsNames,
    required this.selectedCameraImage,
    required this.enableCamera,
    required this.enableVideo,
    required this.redDeleteText,
    required this.selectedVideo,
    required this.replacingTabBar,
    required this.clearVideoRecord,
    required this.moveToVideoScreen,
    required this.callbackFunction,
    super.key,
    this.onBackButtonTap,
  });
  final bool selectedVideo;
  final AppTheme appTheme;
  final TabsTexts tabsNames;
  final bool enableCamera;
  final bool enableVideo;
  final VoidCallback moveToVideoScreen;
  final ValueNotifier<File?> selectedCameraImage;
  final ValueNotifier<bool> redDeleteText;
  final ValueChanged<bool> replacingTabBar;
  final ValueNotifier<bool> clearVideoRecord;
  final AsyncValueSetter<SelectedImagesDetails>? callbackFunction;
  final VoidCallback? onBackButtonTap;

  @override
  CustomCameraDisplayState createState() => CustomCameraDisplayState();
}

class CustomCameraDisplayState extends State<CustomCameraDisplay> {
  ValueNotifier<bool> startVideoCount = ValueNotifier(false);

  bool initializeDone = false;
  bool allPermissionsAccessed = true;
  bool _hasCamera = false;

  List<CameraDescription>? cameras;
  CameraController? controller;

  final cropKey = GlobalKey<CustomCropState>();

  late Widget videoStatusAnimation;
  int selectedCamera = 0;
  File? videoRecordFile;

  @override
  void dispose() {
    startVideoCount.dispose();
    controller?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    videoStatusAnimation = const SizedBox.shrink();
    _initializeCamera();

    super.initState();
  }

  Future<void> _initializeCamera() async {
    try {
      // The camera view needs only the CAMERA permission, which the controller
      // requests on initialize(). It must NOT gate on photo-library access:
      // on Android 14+ that opened the partial-photo-access dialog and returned
      // "not authorized", trapping the viewfinder behind "accept all
      // permissions" even though the camera itself was usable.
      allPermissionsAccessed = true;
      if (!mounted) return;
      cameras = await availableCameras();
      if (cameras == null || (cameras?.isEmpty ?? true)) {
        setState(() {
          _hasCamera = false;
          initializeDone = true;
        });
        return;
      }
      controller = CameraController(
        cameras![0],
        ResolutionPreset.high,
        // No audio: the app captures photos only, and RECORD_AUDIO is not
        // declared. The default (enableAudio: true) asked for the mic and made
        // initialize() fail with "accept all permissions".
        enableAudio: false,
      );
      await controller?.initialize();
      // The plugin defaults to auto. With the flash control gone there is no
      // way to stop the lamp firing, so pin it off.
      try {
        await controller?.setFlashMode(FlashMode.off);
      } on CameraException {
        // Front lenses have no lamp — nothing to turn off.
      }
      initializeDone = true;
      _hasCamera = true;
    } catch (e) {
      allPermissionsAccessed = false;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      // The letterbox around the viewfinder. It used to take primaryColor,
      // which is the confirm arrow's colour — so making that white turned the
      // whole backdrop white.
      color: widget.appTheme.surfaceColor,
      child: allPermissionsAccessed
          ? (initializeDone
              ? _hasCamera
                  ? buildBody()
                  : noCameraFound()
              : loadingProgress())
          : failedPermissions(),
    );
  }

  Widget failedPermissions() {
    return Stack(
      children: [
        appBar(withLeading: false),
        Align(
          child: Text(
            widget.tabsNames.acceptAllPermissions,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.apply(color: widget.appTheme.onSurfaceColor),
          ),
        ),
      ],
    );
  }

  Widget noCameraFound() {
    return Stack(
      children: [
        appBar(withLeading: false),
        Align(
          child: Text(
            widget.tabsNames.noCameraFoundText,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.apply(color: widget.appTheme.onSurfaceColor),
          ),
        ),
      ],
    );
  }

  Center loadingProgress() {
    return Center(
      child: CircularProgressIndicator(
        color: widget.appTheme.primaryColor,
        strokeWidth: 1,
      ),
    );
  }

  Widget buildBody() {
    final whiteColor = widget.appTheme.surfaceColor;
    final selectedImage = widget.selectedCameraImage.value;
    return Stack(
      children: [
        // Backing colour for every gap: the viewfinder is letterboxed when the
        // sensor's aspect ratio does not match the screen, and that band was
        // coming out white.
        Positioned.fill(
          child: ColoredBox(color: widget.appTheme.surfaceColor),
        ),
        if (selectedImage == null) ...[
          if (controller != null)
            Positioned.fill(
              // Cover, not contain: the sensor is narrower than the screen, so
              // fitting it left dark bands above and below the frame. Filling
              // crops the sides instead, which is what a camera should look
              // like.
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller!.value.previewSize?.height ?? 1080,
                    height: controller!.value.previewSize?.width ?? 1920,
                    child: CameraPreview(controller!),
                  ),
                ),
              ),
            ),
        ] else ...[
          Positioned.fill(
            child: Container(
              color: whiteColor,
              child: buildCrop(selectedImage),
            ),
          ),
        ],
        Column(
          children: [
            appBar(),
            const Spacer(),
          ],
        ),
        buildPickImageContainer(context),
      ],
    );
  }

  Align buildPickImageContainer(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 240,
        width: double.infinity,
        // Transparent: the viewfinder runs the full height behind the shutter.
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.topCenter,
                child: RecordCount(
                  appTheme: widget.appTheme,
                  startVideoCount: startVideoCount,
                  makeProgressRed: widget.redDeleteText,
                  clearVideoRecord: widget.clearVideoRecord,
                ),
              ),
            ),
            const Spacer(),
            Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: cameraButton(context),
                ),
                Positioned(bottom: 100, child: videoStatusAnimation),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }


  CustomCrop buildCrop(File selectedImage) {
    final isThatVideo = selectedImage.isVideo;
    return CustomCrop(
      image: selectedImage,
      isThatImage: !isThatVideo,
      key: cropKey,
      alwaysShowGrid: true,
      paintColor: widget.appTheme.primaryColor,
    );
  }

  AppBar appBar({bool withLeading = true}) {
    final selectedImage = widget.selectedCameraImage.value;
    final isPreviewing = selectedImage != null;
    final textColor = isPreviewing ? widget.appTheme.onSurfaceColor : Colors.white;
    final iconColor = isPreviewing ? widget.appTheme.onSurfaceColor : Colors.white;
    return AppBar(
      backgroundColor: isPreviewing ? widget.appTheme.surfaceColor : Colors.transparent,
      elevation: 0,
      title: Text(
        widget.tabsNames.newPostText,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          shadows: isPreviewing ? null : [const Shadow(color: Colors.black54, blurRadius: 8)],
        ),
      ),
      centerTitle: false,
      leading: IconButton(
        icon: Icon(
          Icons.clear_rounded,
          color: iconColor,
          size: 30,
          shadows: isPreviewing ? null : [const Shadow(color: Colors.black54, blurRadius: 8)],
        ),
        onPressed: () async {
          // With a shot on screen, the cross belongs to the shot: throw it away
          // and go back to the viewfinder rather than leaving the camera.
          if (widget.selectedCameraImage.value != null) {
            final discard = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                backgroundColor: widget.appTheme.surfaceColor,
                title: Text(
                  'Discard photo?',
                  style: TextStyle(color: widget.appTheme.onSurfaceColor),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text(
                      'Discard',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
            if (discard ?? false) {
              widget.selectedCameraImage.value = null;
              if (mounted) setState(() {});
            }
            return;
          }
          if (widget.onBackButtonTap == null) {
            Navigator.of(context).maybePop();
          } else {
            widget.onBackButtonTap!.call();
          }
        },
      ),
      // Confirm arrow only once there is something to confirm. On the bare
      // viewfinder it did nothing, so it read as a dead button.
      actions: !withLeading || (selectedImage == null && videoRecordFile == null)
          ? null
          : <Widget>[
              AnimatedSwitcher(
                duration: const Duration(seconds: 1),
                switchInCurve: Curves.easeIn,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    shadows: isPreviewing ? null : [const Shadow(color: Colors.black54, blurRadius: 8)],
                    size: 30,
                  ),
                  onPressed: () async {
                    if (videoRecordFile != null) {
                      final byte = await videoRecordFile!.readAsBytes();
                      final selectedByte = SelectedByte(
                        isThatImage: false,
                        selectedFile: videoRecordFile!,
                        selectedByte: byte,
                      );
                      final details = SelectedImagesDetails(
                        multiSelectionMode: false,
                        selectedFiles: [selectedByte],
                        aspectRatio: 1,
                      );
                      if (!mounted) return;

                      void pop() => Navigator.of(context).maybePop(details);
                      if (widget.callbackFunction != null) {
                        await widget.callbackFunction!(details);
                      } else {
                        pop();
                      }
                    } else if (selectedImage != null) {
                      final croppedByte = await cropImage(selectedImage);
                      if (croppedByte != null) {
                        final byte = await croppedByte.readAsBytes();

                        final selectedByte = SelectedByte(
                          isThatImage: true,
                          selectedFile: croppedByte,
                          selectedByte: byte,
                        );

                        final details = SelectedImagesDetails(
                          selectedFiles: [selectedByte],
                          multiSelectionMode: false,
                          aspectRatio: 1,
                        );
                        if (!mounted) return;

                        void pop() => Navigator.of(context).maybePop(details);
                        if (widget.callbackFunction != null) {
                          await widget.callbackFunction!(details);
                        } else {
                          pop.call();
                        }
                      }
                    }
                  },
                ),
              ),
            ],
    );
  }

  Future<File?> cropImage(File imageFile) async {
    await InstaAssetsCrop.requestPermissions();
    final scale = cropKey.currentState!.scale;
    final area = cropKey.currentState!.area;
    if (area == null) {
      return null;
    }
    final sample = await InstaAssetsCrop.sampleImage(
      file: imageFile,
      preferredSize: (2000 / scale).round(),
    );
    final file = await InstaAssetsCrop.cropImage(
      file: sample,
      area: area,
    );
    await sample.delete();
    return file;
  }

  GestureDetector cameraButton(BuildContext context) {
    return GestureDetector(
      onTap: widget.enableCamera ? onPress : null,
      onLongPress: widget.enableVideo ? onLongTap : null,
      onLongPressUp: widget.enableVideo ? onLongTapUp : onPress,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: Colors.transparent,
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> onPress() async {
    try {
      if (!widget.selectedVideo) {
        final image = await controller?.takePicture();
        if (image == null) return;
        final selectedImage = File(image.path);
        setState(() {
          widget.selectedCameraImage.value = selectedImage;
          widget.replacingTabBar(true);
        });
      } else {
        setState(() {
          videoStatusAnimation = buildFadeAnimation();
        });
      }
    } catch (e) {
      if (kDebugMode) print(e);
    }
  }

  void onLongTap() {
    controller?.startVideoRecording();
    widget.moveToVideoScreen();
    setState(() {
      startVideoCount.value = true;
    });
  }

  Future<void> onLongTapUp() async {
    setState(() {
      startVideoCount.value = false;
      widget.replacingTabBar(true);
    });
    final video = await controller?.stopVideoRecording();
    if (video == null) return;
    videoRecordFile = File(video.path);
  }

  RecordFadeAnimation buildFadeAnimation() {
    return RecordFadeAnimation(child: buildMessage());
  }

  Widget buildMessage() {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            color: Color.fromARGB(255, 54, 53, 53),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.tabsNames.holdButtonText,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: Center(
            child: Icon(
              Icons.arrow_drop_down_rounded,
              color: Color.fromARGB(255, 49, 49, 49),
              size: 65,
            ),
          ),
        ),
      ],
    );
  }
}
