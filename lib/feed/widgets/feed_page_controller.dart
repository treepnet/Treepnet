import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/feed/feed.dart';
import 'package:treepnet/feed/post/video/video.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import 'package:path/path.dart' as p;
import 'package:treepnet/app/services/media_upload_queue.dart';
import 'package:treepnet/feed/widgets/post_upload_progress.dart';

class FeedPageController extends ChangeNotifier {
  factory FeedPageController() => _internal;

  FeedPageController._();

  static final FeedPageController _internal = FeedPageController._();

  late ScrollController _nestedScrollController;
  late BuildContext _context;

  void init({
    required ScrollController nestedScrollController,
    required BuildContext context,
  }) {
    _nestedScrollController = nestedScrollController;
    _context = context;
  }

  bool _hasPlayedAnimation = false;
  double _animationValue = 0;

  bool get hasPlayedAnimation => _hasPlayedAnimation;
  set hasPlayedAnimation(bool value) {
    _hasPlayedAnimation = value;
    notifyListeners();
  }

  double get animationValue => _animationValue;
  set animationValue(double value) {
    _animationValue = value;
    notifyListeners();
  }

  void markAnimationAsUnseen() {
    _hasPlayedAnimation = false;
    _animationValue = 0;
    notifyListeners();
  }

  void scrollToTop() => _nestedScrollController.animateTo(
    0,
    duration: 250.ms,
    curve: Curves.ease,
  );

  Future<void> processPostMedia({
    required List<SelectedByte> selectedFiles,
    required String postId,
    required String caption,
    required bool pickVideo,
    String? location,
    String? locationCountry,
    String? locationRegion,
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) async {
    final firstThumb =
        selectedFiles.isNotEmpty && selectedFiles.first.isThatImage
        ? selectedFiles.first.selectedByte
        : null;
    PostUploadProgress().begin(thumbnail: firstThumb);

    final isReel =
        selectedFiles.length == 1 && selectedFiles.every((e) => !e.isThatImage);
    final navigateToReelPage = isReel;
    StatefulNavigationShell.of(
      _context,
    ).goBranch(navigateToReelPage ? 3 : 0, initialLocation: true);
    if (pickVideo) {
      VideoPlayerInheritedWidget.of(_context).videoPlayerState.playReels();
    }

    void uploadPost({required List<Map<String, dynamic>> media}) =>
        _context.read<FeedBloc>().add(
          FeedPostCreateRequested(
            postId: postId,
            caption: caption,
            media: media,
            location: location,
            locationCountry: locationCountry,
            locationRegion: locationRegion,
            locationName: locationName,
            locationLat: locationLat,
            locationLng: locationLng,
          ),
        );

    late final storage = MediaStorage.instance.from('posts');

    final queue = _context.read<MediaUploadQueue>();

    try {
    if (isReel) {
      final selectedFile = selectedFiles.first;
      final mediaPath = '$postId/video_0';

      final firstFrame = await VideoPlus.getVideoThumbnail(
        selectedFile.selectedFile,
      );
      final blurHash = firstFrame == null
          ? ''
          : await BlurHashPlus.blurHashEncode(firstFrame);
      final compressedVideo =
          (await VideoPlus.compressVideo(selectedFile.selectedFile))?.file ??
          selectedFile.selectedFile;
      final compressedVideoBytes = await PickImage().imageBytes(
        file: compressedVideo,
      );
      final attachment = AttachmentFile(
        size: compressedVideoBytes.length,
        bytes: compressedVideoBytes,
        path: compressedVideo.path,
      );

      String mediaUrl;
      String? firstFrameUrl;

      try {
        await storage.uploadBinary(
          mediaPath,
          attachment.bytes!,
          fileOptions: MediaFileOptions(
            contentType: attachment.mediaType!.mimeType,
            cacheControl: '9000000',
          ),
        );
        mediaUrl = storage.getPublicUrl(mediaPath);

        if (firstFrame != null) {
          late final firstFramePath = '$postId/video_first_frame_0';
          await storage.uploadBinary(
            firstFramePath,
            firstFrame,
            fileOptions: MediaFileOptions(
              contentType: attachment.mediaType!.mimeType,
              cacheControl: '9000000',
            ),
          );
          firstFrameUrl = storage.getPublicUrl(firstFramePath);
        }
      } catch (error, stackTrace) {
        logW('Immediate upload failed. Enqueuing offline upload...', error: error, stackTrace: stackTrace);
        late final firstFramePath = '$postId/video_first_frame_0';
        final localPath = await queue.enqueueTask(
          postId: postId,
          bytes: attachment.bytes!,
          remotePath: mediaPath,
          bucket: 'posts',
          contentType: attachment.mediaType!.mimeType,
          mediaType: VideoMedia.identifier,
          index: 0,
          blurHash: blurHash,
          firstFrameBytes: firstFrame,
          firstFrameRemotePath: firstFramePath,
        );
        mediaUrl = Uri.file(localPath).toString();
        if (firstFrame != null) {
          final firstFrameLocalPath = p.join(p.dirname(localPath), 'first_frame_0.jpg');
          firstFrameUrl = Uri.file(firstFrameLocalPath).toString();
        }
      }

      final media = [
        {
          'media_id': uuid.v4(),
          'url': mediaUrl,
          'type': VideoMedia.identifier,
          'blur_hash': blurHash,
          'first_frame_url': firstFrameUrl,
        },
      ];
      uploadPost(media: media);
    } else {
      final media = <Map<String, dynamic>>[];
      for (var i = 0; i < selectedFiles.length; i++) {
        late final selectedByte = selectedFiles[i].selectedByte;
        late final selectedFile = selectedFiles[i].selectedFile;
        late final isVideo = selectedFile.isVideo;
        String blurHash;
        Uint8List? convertedBytes;
        // Compressed image bytes, reused for both the blur hash and the upload.
        // Compressing off the main thread first prevents the full-resolution
        // image from blocking the UI thread (ANR) during blur hash encoding.
        Uint8List? compressedImageBytes;
        if (isVideo) {
          convertedBytes = await VideoPlus.getVideoThumbnail(selectedFile);
          blurHash = convertedBytes == null
              ? ''
              : await BlurHashPlus.blurHashEncode(convertedBytes);
        } else {
          compressedImageBytes = await ImageCompress.compressByte(selectedByte);
          blurHash = await BlurHashPlus.blurHashEncode(compressedImageBytes);
        }
        PostUploadProgress().to(0.4);
        late final mediaExtension = selectedFile.path
            .split('.')
            .last
            .toLowerCase();

        late final mediaPath = '$postId/${!isVideo ? 'image_$i' : 'video_$i'}';

        Uint8List bytes;
        if (isVideo) {
          try {
            final compressedVideo = await VideoPlus.compressVideo(selectedFile);
            bytes = await PickImage().imageBytes(file: compressedVideo!.file!);
          } catch (error, stackTrace) {
            logE(
              _context.l10n.errorCompressingVideoText,
              error: error,
              stackTrace: stackTrace,
            );
            bytes = selectedByte;
          }
        } else {
          bytes = compressedImageBytes ?? selectedByte;
        }

        String mediaUrl;
        String? firstFrameUrl;

        try {
          await storage.uploadBinary(
            mediaPath,
            bytes,
            fileOptions: MediaFileOptions(
              contentType: '${!isVideo ? 'image' : 'video'}/$mediaExtension',
              cacheControl: '9000000',
            ),
          );
          mediaUrl = storage.getPublicUrl(mediaPath);
          PostUploadProgress().to(0.85);

          if (convertedBytes != null) {
            late final firstFramePath = '$postId/video_first_frame_$i';
            await storage.uploadBinary(
              firstFramePath,
              convertedBytes,
              fileOptions: MediaFileOptions(
                contentType: 'video/$mediaExtension',
                cacheControl: '9000000',
              ),
            );
            firstFrameUrl = storage.getPublicUrl(firstFramePath);
          }
        } catch (error, stackTrace) {
          logW('Immediate upload failed. Enqueuing offline upload...', error: error, stackTrace: stackTrace);
          late final firstFramePath = '$postId/video_first_frame_$i';
          final localPath = await queue.enqueueTask(
            postId: postId,
            bytes: bytes,
            remotePath: mediaPath,
            bucket: 'posts',
            contentType: '${!isVideo ? 'image' : 'video'}/$mediaExtension',
            mediaType: isVideo ? VideoMedia.identifier : ImageMedia.identifier,
            index: i,
            blurHash: blurHash,
            firstFrameBytes: convertedBytes,
            firstFrameRemotePath: isVideo ? firstFramePath : null,
          );
          mediaUrl = Uri.file(localPath).toString();
          if (convertedBytes != null) {
            final firstFrameLocalPath = p.join(p.dirname(localPath), 'first_frame_$i.jpg');
            firstFrameUrl = Uri.file(firstFrameLocalPath).toString();
          }
        }

        final mediaType = isVideo
            ? VideoMedia.identifier
            : ImageMedia.identifier;
        if (isVideo) {
          media.add({
            'media_id': uuid.v4(),
            'url': mediaUrl,
            'type': mediaType,
            'blur_hash': blurHash,
            'first_frame_url': firstFrameUrl,
          });
        } else {
          media.add({
            'media_id': uuid.v4(),
            'url': mediaUrl,
            'type': mediaType,
            'blur_hash': blurHash,
          });
        }
      }
      uploadPost(media: media);
    }
    } finally {
      PostUploadProgress().complete();
    }
  }
}
