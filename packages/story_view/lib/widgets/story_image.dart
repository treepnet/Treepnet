import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils.dart';
import '../controller/story_controller.dart';

/// Utitlity to load image (gif, png, jpg, etc) media just once. Resource is
/// cached to disk with default configurations of [DefaultCacheManager].
class ImageLoader {
  ui.Codec? frames;

  String url;

  Map<String, dynamic>? requestHeaders;

  LoadState state = LoadState.loading; // by default

  /// True while a file read + decode is in flight, so a second cache event
  /// arriving during that async gap doesn't start a duplicate decode.
  bool _decoding = false;

  /// How long a load may take before it counts as failed. On a stalled
  /// connection the download never errors — it just never finishes — and the
  /// story sat on a spinner for good.
  static const timeout = Duration(seconds: 15);

  StreamSubscription<FileResponse>? _subscription;
  Timer? _timeout;

  ImageLoader(this.url, {this.requestHeaders});

  /// Warms the disk cache for [url] so a story opens without a network wait
  /// once the viewer reaches it. Errors are ignored; the real load retries.
  static void prefetch(String url) {
    if (url.isEmpty) return;
    DefaultCacheManager().getSingleFile(url).then((_) {}, onError: (_) {});
  }

  /// Physical width of the screen, used as the decode width: a story is shown
  /// full-bleed, so decoding wider (uploads are 1440px) only costs decode time
  /// and texture memory while the open transition is animating.
  static int? _screenWidthPx() {
    final view = ui.PlatformDispatcher.instance.implicitView;
    final width = view?.physicalSize.width ?? 0;
    return width > 0 ? width.round() : null;
  }

  /// Load image from disk cache first, if not found then load from network.
  /// `onComplete` is called when [imageBytes] become available.
  ///
  /// Calling it again after a failure is a retry. The download itself carries
  /// on in the cache manager after a timeout, so a retry often finds it done.
  void loadImage(VoidCallback onComplete) {
    if (this.frames != null) {
      this.state = LoadState.success;
      onComplete();
      return;
    }

    cancel();
    this.state = LoadState.loading;
    _timeout = Timer(timeout, () {
      // The file is here and being decoded: that finishes on its own.
      if (_decoding) return;
      cancel();
      this.state = LoadState.failure;
      onComplete();
    });

    final fileStream = DefaultCacheManager().getFileStream(this.url,
        headers: this.requestHeaders as Map<String, String>?);

    _subscription = fileStream.listen(
      (fileResponse) async {
        if (!(fileResponse is FileInfo)) return;
        // the reason for this is that, when the cache manager fetches
        // the image again from network, the provided `onComplete` should
        // not be called again
        if (this.frames != null || _decoding) {
          return;
        }
        _decoding = true;

        try {
          // Async read: the sync variant blocked the UI isolate on file I/O
          // right as the story opened.
          final imageBytes = await fileResponse.file.readAsBytes();
          this.state = LoadState.success;
          this.frames = await ui.instantiateImageCodec(
            imageBytes,
            targetWidth: _screenWidthPx(),
            allowUpscaling: false,
          );
        } catch (_) {
          this.state = LoadState.failure;
        } finally {
          _decoding = false;
        }
        cancel();
        onComplete();
      },
      onError: (error) {
        cancel();
        this.state = LoadState.failure;
        onComplete();
      },
    );
  }

  /// Stops listening for this load (the page went away, or it is being
  /// retried). The download, if any, still lands in the disk cache.
  void cancel() {
    _timeout?.cancel();
    _timeout = null;
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Builds what a story shows when its media fails to load. [retry] loads it
/// again.
typedef StoryErrorBuilder = Widget Function(
  BuildContext context,
  VoidCallback retry,
);

/// Widget to display animated gifs or still images. Shows a loader while image
/// is being loaded. Listens to playback states from [controller] to pause and
/// forward animated media.
class StoryImage extends StatefulWidget {
  final ImageLoader imageLoader;

  final BoxFit? fit;

  final StoryController? controller;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  /// Takes precedence over [errorWidget], and can offer a retry.
  final StoryErrorBuilder? errorBuilder;

  StoryImage(
    this.imageLoader, {
    Key? key,
    this.controller,
    this.fit,
    this.loadingWidget,
    this.errorWidget,
    this.errorBuilder,
  }) : super(key: key ?? UniqueKey());

  /// Use this shorthand to fetch images/gifs from the provided [url]
  factory StoryImage.url(
    String url, {
    StoryController? controller,
    Map<String, dynamic>? requestHeaders,
    BoxFit fit = BoxFit.fitWidth,
    Widget? loadingWidget,
    Widget? errorWidget,
    StoryErrorBuilder? errorBuilder,
    Key? key,
  }) {
    return StoryImage(
        ImageLoader(
          url,
          requestHeaders: requestHeaders,
        ),
        controller: controller,
        fit: fit,
        loadingWidget: loadingWidget,
        errorWidget: errorWidget,
        errorBuilder: errorBuilder,
        key: key,
    );
  }

  @override
  State<StatefulWidget> createState() => StoryImageState();
}

class StoryImageState extends State<StoryImage> {
  ui.Image? currentFrame;

  Timer? _timer;

  StreamSubscription<PlaybackState>? _streamSubscription;

  @override
  void initState() {
    super.initState();

    if (widget.controller != null) {
      this._streamSubscription =
          widget.controller!.playbackNotifier.listen((playbackState) {
        // for the case of gifs we need to pause/play
        if (widget.imageLoader.frames == null) {
          return;
        }

        if (playbackState == PlaybackState.pause) {
          this._timer?.cancel();
        } else {
          forward();
        }
      });
    }

    _load();
  }

  void _load() {
    widget.controller?.pause();

    widget.imageLoader.loadImage(() async {
      if (mounted) {
        if (widget.imageLoader.state == LoadState.success) {
          widget.controller?.play();
          forward();
        } else {
          // Show the error, and let the progress bar run: the viewer moves on
          // by itself instead of sitting on a story that won't load.
          setState(() {});
          widget.controller?.play();
        }
      }
    });
  }

  /// Loads the image again, from the start of its progress bar.
  void _retry() {
    widget.controller?.pause();
    widget.controller?.rewind();
    _load();
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _streamSubscription?.cancel();
    widget.imageLoader.cancel();

    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  void forward() async {
    this._timer?.cancel();

    if (widget.controller != null &&
        widget.controller!.playbackNotifier.stream.value ==
            PlaybackState.pause) {
      return;
    }

    final nextFrame = await widget.imageLoader.frames!.getNextFrame();

    this.currentFrame = nextFrame.image;

    if (nextFrame.duration > Duration(milliseconds: 0)) {
      this._timer = Timer(nextFrame.duration, forward);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: ImageContentView(
        imageLoader: widget.imageLoader,
        fit: widget.fit,
        currentFrame: this.currentFrame,
        loadingWidget: widget.loadingWidget,
        errorWidget: widget.errorBuilder?.call(context, _retry) ??
            widget.errorWidget,
      ),
    );
  }
}

/**
 * @name ImageContentView
 * @description Stateless widget that displays an image based on loading state: success, failure, or loading.
 */
class ImageContentView extends StatelessWidget {
  final ImageLoader imageLoader;
  final BoxFit? fit;
  final ui.Image? currentFrame;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const ImageContentView({
    Key? key,
    required this.imageLoader,
    required this.fit,
    required this.currentFrame,
    this.loadingWidget,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (imageLoader.state) {
      case LoadState.success:
        return RawImage(
          image: currentFrame,
          fit: fit,
        );
      case LoadState.failure:
        return Center(
          child: errorWidget ??
              const Text(
                "Image failed to load.",
                style: TextStyle(color: Colors.white),
              ),
        );
      default:
        return Center(
          child: loadingWidget ??
              const SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
        );
    }
  }
}

