import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// PhotoManager and Uint8List both arrive via shared's re-exports.
import 'package:shared/shared.dart';
import 'package:treepnet/l10n/l10n.dart';

/// The camera a story starts from.
///
/// Standalone on purpose: New post has its own viewfinder inside
/// `image_picker_plus`, and the two must never share code — a tweak to one
/// used to silently change the other. The chrome is styled to match it, but
/// that is a copied look, not shared code.
///
/// Pops with the captured file's path, or `null` if the user backs out.
class StoryCameraPage extends StatefulWidget {
  const StoryCameraPage({super.key});

  /// Opens the camera above everything else and waits for a picture.
  static Future<String?> push(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const StoryCameraPage(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<StoryCameraPage> createState() => _StoryCameraPageState();
}

class _StoryCameraPageState extends State<StoryCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  bool _initializing = true;
  bool _capturing = false;
  bool _switching = false;
  bool _backgrounded = false;
  String? _error;

  /// Serialises camera swaps — see [_select].
  Future<void> _cameraQueue = Future<void>.value();

  /// Thumbnail of the newest picture on the device, shown on the gallery
  /// button so it reads as "your photos" rather than a generic icon.
  Uint8List? _latestThumbnail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  /// Camera first, gallery second — never at the same time. Android drops a
  /// permission request while another one is on screen, so asking for photos
  /// during the camera prompt got silently denied and the thumbnail never
  /// loaded.
  Future<void> _start() async {
    await _bootstrap();
    if (!mounted) return;
    await _loadLatestThumbnail();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android hands the sensor to whatever is in the foreground, so let go of
    // it while we are backgrounded and take it again on the way back.
    //
    // `paused`, deliberately not `inactive`: a permission dialog only makes us
    // inactive, and tearing the camera down for it raced the initialize() that
    // put the dialog up in the first place — which is what left the viewfinder
    // black on a fresh install.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgrounded && _cameras.isNotEmpty) {
        _backgrounded = false;
        _select(_cameraIndex);
      }
    }
  }

  void _releaseCamera() {
    _backgrounded = true;
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    controller.dispose();
    if (mounted) setState(() => _initializing = true);
  }

  Future<void> _bootstrap() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'No camera found';
          _initializing = false;
        });
        return;
      }
      // Stories open on the back camera, same as Instagram.
      final back = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      await _select(back == -1 ? 0 : back);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.description ?? context.l10n.cameraUnavailableText;
        _initializing = false;
      });
    }
  }

  /// Queues camera swaps so only one ever runs at a time.
  ///
  /// Android hands the sensor to a single controller; two overlapping swaps end
  /// with the surviving controller not being the one that holds it, and the
  /// preview goes black.
  Future<void> _select(int index) {
    final next = _cameraQueue.then((_) => _doSelect(index));
    _cameraQueue = next.catchError((Object _) {});
    return next;
  }

  /// Tears the old controller down *before* building the new one: Android only
  /// hands the sensor to one controller at a time, so overlapping them is what
  /// makes a flip silently fail.
  Future<void> _doSelect(int index) async {
    if (_cameras.isEmpty) return;
    final target = index % _cameras.length;

    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final description = _cameras[target];
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _error = e.description ?? context.l10n.cameraUnavailableText;
        _initializing = false;
      });
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _cameraIndex = target;
      _initializing = false;
      _error = null;
    });
    // Off explicitly: the plugin defaults to auto, and with no flash control on
    // screen the lamp must never fire on its own.
    try {
      await controller.setFlashMode(FlashMode.off);
    } on CameraException {
      // Front lenses have no lamp — nothing to turn off, nothing to report.
    }
  }

  bool get _isFront =>
      _cameras.isNotEmpty &&
      _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;

  Future<void> _flip() async {
    if (_cameras.length < 2 || _capturing || _switching) return;
    setState(() {
      _switching = true;
      _initializing = true;
    });
    await _select(_cameraIndex + 1);
    if (!mounted) return;
    setState(() => _switching = false);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_capturing || _switching) return;
    setState(() => _capturing = true);
    try {
      final shot = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(shot.path);
    } on CameraException {
      if (!mounted) return;
      setState(() => _capturing = false);
    }
  }

  Future<void> _loadLatestThumbnail() async {
    try {
      // Images only (no READ_MEDIA_VIDEO in the manifest), so request just the
      // image permission — the default request would look "denied" otherwise.
      final permission = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      );
      if (!permission.hasAccess) return;
      final albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.image,
      );
      if (albums.isEmpty) return;
      final newest = await albums.first.getAssetListPaged(page: 0, size: 1);
      if (newest.isEmpty) return;
      final thumbnail = await newest.first.thumbnailDataWithSize(
        const ThumbnailSize.square(240),
      );
      if (!mounted || thumbnail == null) return;
      setState(() => _latestThumbnail = thumbnail);
    } on Exception {
      // No gallery access, no thumbnail — the button still opens the picker.
    }
  }

  /// Second chance at the thumbnail: the picker asks for gallery access too, so
  /// a user who granted it there should see their photo on the way back.
  Future<void> _retryThumbnailAfterPicker() async {
    if (_latestThumbnail != null || !mounted) return;
    await _loadLatestThumbnail();
  }

  Future<void> _pickFromGallery() async {
    // Gallery only — the default source, so this never opens the New post
    // viewfinder.
    final details = await PickImage().pickImage(
      context,
      cropImage: false,
      showPreview: false,
      // Reached from the story camera, so the header must not say "New post".
      tabsTexts: TabsTexts(newPostText: context.l10n.newStoryText),
      // A story is a full-height frame, so its picker shows fewer, taller
      // tiles than the post grid's four square columns.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 133 / 170,
      ),
    );
    final picked = details?.selectedFiles;
    if (picked == null || picked.isEmpty || !mounted) {
      await _retryThumbnailAfterPicker();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(picked.first.selectedFile.path);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        // Same chrome as the New post camera: transparent bar, white rounded
        // icons at size 30, each with a shadow so they stay legible on a bright
        // viewfinder. Only the close button lives up here — flip sits in the
        // shutter row.
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          title: Text(
            context.l10n.newStoryText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
          leading: _barButton(
            icon: Icons.clear_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _viewfinder(),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _bottomBar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewfinder() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    final controller = _controller;
    if (_initializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    // Cover, not contain: the sensor is narrower than the screen, so fitting
    // leaves dark bands. Filling crops the sides, which is what a camera looks
    // like. Same call the New post viewfinder makes — arrived at separately.
    final preview = controller.value.previewSize;
    final viewfinder = ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: preview?.height ?? 1080,
          height: preview?.width ?? 1920,
          child: CameraPreview(controller),
        ),
      ),
    );
    if (!_isFront) return viewfinder;
    // The front sensor hands back what it sees, so raising your right hand
    // moves it to the left of frame. Flip horizontally to make the preview
    // behave like a mirror, which is what everyone expects of a selfie.
    return Transform.flip(flipX: true, child: viewfinder);
  }

  Widget _barButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: Colors.white,
        size: 30,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
      ),
    );
  }

  /// Gallery, shutter, flip — one row, pinned to the bottom of the screen.
  ///
  /// No `Align` or `Expanded` in here on purpose. An `Align` with no size
  /// factor grows to the largest size its constraints allow, so as a Row child
  /// it took the full screen height, the Row grew with it, and the whole bar
  /// drifted back to the vertical centre. `spaceBetween` needs neither: the
  /// gallery and flip buttons are both 48 wide, so the shutter lands centred.
  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _galleryButton(),
          _shutter(),
          if (_cameras.length > 1)
            _barButton(icon: Icons.flip_camera_ios_rounded, onPressed: _flip)
          else
            // Balances the gallery button so the shutter stays centred.
            const SizedBox(width: _flipButtonSize),
        ],
      ),
    );
  }

  /// An [IconButton]'s default footprint — matches [_galleryButtonSize].
  static const double _flipButtonSize = 48;

  static const double _galleryButtonSize = 48;

  Widget _galleryButton() {
    final thumbnail = _latestThumbnail;
    return GestureDetector(
      onTap: _pickFromGallery,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _galleryButtonSize,
        height: _galleryButtonSize,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white70, width: 1.5),
          color: Colors.black26,
        ),
        child: thumbnail == null
            ? const Icon(
                Icons.photo_library_outlined,
                color: Colors.white,
                size: 24,
              )
            : Image.memory(thumbnail, fit: BoxFit.cover),
      ),
    );
  }

  Widget _shutter() {
    return GestureDetector(
      onTap: _capture,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _capturing ? Colors.white54 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
