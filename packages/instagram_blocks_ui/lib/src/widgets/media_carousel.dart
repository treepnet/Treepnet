import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:inview_notifier_list/inview_notifier_list.dart';
import 'package:shared/shared.dart';

class MediaCarousel extends StatefulWidget {
  const MediaCarousel({
    required this.media,
    required this.settings,
    this.postIndex,
    super.key,
  });

  final List<Media> media;
  final MediaCarouselSettings settings;
  final int? postIndex;

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  late ValueNotifier<int> _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = ValueNotifier(0);
    // The second photo is on its way before the first swipe.
    _prefetchAfter(0);
  }

  @override
  void dispose() {
    _currentIndex.dispose();
    super.dispose();
  }

  /// Photos of this post already fetched ahead.
  final _prefetched = <String>{};

  /// Fetches the next page's photo into the image cache (the file only), so
  /// a swipe finds it there instead of waiting for it.
  void _prefetchAfter(int index) {
    final next = index + 1;
    if (next >= widget.media.length) return;
    final media = widget.media[next];
    if (media is! ImageMedia) return;
    final url = media.url;
    if (url.isEmpty || url.startsWith('file://') || !_prefetched.add(url)) {
      return;
    }
    unawaited(
      postImageCacheManager
          .getSingleFile(url, key: url)
          .then<void>((_) {}, onError: (Object _) => _prefetched.remove(url)),
    );
  }

  Widget _carousel({bool? isInView}) => CarouselSlider.builder(
    itemCount: widget.media.length,
    itemBuilder: (context, index, realIndex) {
      final media = widget.media[index];
      final url = media.url;
      final blurHash = media.blurHash;

      return switch (media) {
        final ImageMedia media => _MediaCarouselImage(
          blurHash: blurHash,
          url: url,
          media: media,
          settings: widget.settings,
        ),
        final VideoMedia media => _MediaCarouselVideo(
          currentIndex: _currentIndex,
          settings: widget.settings,
          media: media,
          url: url,
          blurHash: blurHash,
          isInView: isInView,
          realIndex: realIndex,
        ),
        final MemoryImageMedia media => _MediaCarouselMemoryImage(media: media),
        final MemoryVideoMedia media => _MediaCarouselMemoryVideo(
          currentIndex: _currentIndex,
          realIndex: realIndex,
          media: media,
          blurHash: blurHash,
          settings: widget.settings,
          isInView: isInView,
        ),
        _ => const SizedBox.shrink(),
      };
    },
    options: CarouselOptions(
      aspectRatio: widget.settings.aspectRatio!,
      viewportFraction: widget.settings.viewportFraction!,
      enableInfiniteScroll: widget.settings.enableInfiniteScroll!,
      onPageChanged: (index, reason) {
        _currentIndex.value = index;
        _prefetchAfter(index);
        widget.settings.onPageChanged?.call(index, reason);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!widget.settings.withInViewNotifier!) return _carousel();
    assert(widget.postIndex != null, 'Post index must be provided!');

    return InViewNotifierWidget(
      id: '${widget.postIndex!}',
      builder: (_, isInView, _) => _carousel(isInView: isInView),
    );
  }
}

class _MediaCarouselVideo extends StatelessWidget {
  const _MediaCarouselVideo({
    required this.currentIndex,
    required this.realIndex,
    required this.settings,
    required this.media,
    required this.url,
    required this.blurHash,
    required this.isInView,
  });

  final ValueNotifier<int> currentIndex;
  final int realIndex;
  final MediaCarouselSettings settings;
  final VideoMedia media;
  final String url;
  final String? blurHash;
  final bool? isInView;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentIndex,
      builder: (context, currentIndex, _) {
        final shouldPlay = currentIndex == realIndex;

        return settings.videoPlayerBuilder?.call(
              context,
              media,
              settings.aspectRatio!,
              (isInView ?? true) && shouldPlay,
            ) ??
            InlineVideo(
              key: ValueKey(media.id),
              videoSettings: VideoSettings.build(
                videoUrl: url,
                shouldPlay: shouldPlay && (isInView ?? true),
                blurHash: blurHash,
                withSound: false,
                id: media.id,
                aspectRatio: settings.aspectRatio,
              ),
            );
      },
    );
  }
}

class _MediaCarouselMemoryVideo extends StatelessWidget {
  const _MediaCarouselMemoryVideo({
    required this.currentIndex,
    required this.realIndex,
    required this.media,
    required this.blurHash,
    required this.settings,
    required this.isInView,
  });

  final ValueNotifier<int> currentIndex;
  final int realIndex;
  final MemoryVideoMedia media;
  final String? blurHash;
  final MediaCarouselSettings settings;
  final bool? isInView;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentIndex,
      builder: (context, currentIndex, _) {
        final shouldPlay = currentIndex == realIndex;

        return InlineVideo(
          key: ValueKey(media.id),
          videoSettings: VideoSettings.build(
            id: media.id,
            videoFile: media.file,
            shouldPlay: shouldPlay && (isInView ?? true),
            blurHash: blurHash,
            aspectRatio: settings.aspectRatio,
            withPlayerController: false,
            withSoundButton: false,
          ),
        );
      },
    );
  }
}

class _MediaCarouselImage extends StatelessWidget {
  const _MediaCarouselImage({
    required this.media,
    required this.url,
    required this.blurHash,
    required this.settings,
  });

  final ImageMedia media;
  final String url;
  final String? blurHash;
  final MediaCarouselSettings settings;

  /// Full-bleed posts never need more than a 1080px-wide bitmap, and pinning
  /// it means every phone decodes the same one — the carousel box does the
  /// sizing, so the post looks identical everywhere.
  static const _decodeWidth = 1080;

  @override
  Widget build(BuildContext context) {
    return BlurHashImageThumbnail(
      id: media.id,
      url: url,
      fit: settings.fit,
      decodeWidth: _decodeWidth,
      blurHash: blurHash,
      // Its 480 px copy first (a grid has the first one already), then the
      // photo over it.
      previewUrl: media.thumbUrl,
    );
  }
}

class _MediaCarouselMemoryImage extends StatelessWidget {
  const _MediaCarouselMemoryImage({required this.media});

  final MemoryImageMedia media;

  @override
  Widget build(BuildContext context) {
    return ImageAttachmentThumbnail(
      image: Attachment(
        file: AttachmentFile(size: media.bytes.length, bytes: media.bytes),
      ),
      // A photo just picked (post preview) is full camera size — a 12MP one
      // takes ~48MB decoded, and up to ten can be picked. Shown at most
      // screen-wide, so decode at most 1080px; the upload is untouched.
      memCacheWidth: 1080,
    );
  }
}
