import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// {@template media_storage}
/// Minimal OCI Object Storage client: `from(bucket).uploadBinary(...)` and
/// `getPublicUrl(...)`, the slice of a storage API the app's media code
/// uses.
///
/// The app uses ONE OCI bucket. Each legacy "bucket" name the call sites pass
/// (`avatars`, `stories`, `posts`) becomes a top-level object-name prefix
/// inside that single bucket.
///
/// Reads are anonymous: objects are publicly readable by URL (the bucket's
/// object list is not), so the native object URL is a stable public link.
/// (Not through the media.treepnet.com Cloudflare CDN: Russian ISPs throttle
/// Cloudflare to the first ~16 KB of each file.)
/// Writes need a link from the backend for each file: it checks the signed-in
/// user ([idToken]) and that the object is theirs to write, and the link it
/// returns writes only that object, for a few minutes. (The app used to carry
/// one bucket-wide write link valid until 2035.)
/// {@endtemplate}
class MediaStorage {
  MediaStorage._();

  /// Shared instance.
  static final MediaStorage instance = MediaStorage._();

  /// Public-read base of the media bucket.
  static const _readBase =
      'https://objectstorage.eu-frankfurt-1.oraclecloud.com'
      '/n/fryarohmp0gm/b/treepnet-media';

  /// Hands out a write link for one object (auth-service).
  static const _uploadLinkUrl =
      'https://api.treepnet.com/auth/media/upload-url';

  /// The signed-in user's Firebase ID token, refreshed first when
  /// [forceRefresh]. Set by the app at start-up; uploads fail without it.
  Future<String?> Function({bool forceRefresh})? idToken;

  /// One client for every upload. It used to be a fresh `Dio()` per call with
  /// no timeouts at all, so on a weak mobile connection an upload could hang
  /// for minutes (the post banner stuck near 90%). A connection that can't be
  /// opened gives up here; a slow transfer is bounded per upload by its size —
  /// see [MediaBucket.uploadBinary]. (No fixed receive timeout: on some
  /// adapters it also covers sending the body, which would cut off a large
  /// video on a slow connection.)
  static final Dio _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 20)),
  );

  /// Returns a handle scoped to [bucket] — the legacy container name, used here
  /// as the object-name prefix inside the single OCI bucket.
  MediaBucket from(String bucket) =>
      MediaBucket(prefix: bucket, storage: this, dio: _dio);
}

/// {@template media_bucket}
/// A handle to one logical media "bucket" (object-name prefix) inside the single
/// OCI bucket, with the uploads and URLs the app needs.
/// {@endtemplate}
class MediaBucket {
  /// {@macro media_bucket}
  MediaBucket({
    required this.prefix,
    required MediaStorage storage,
    Dio? dio,
  }) : _storage = storage,
       _dio = dio ?? Dio();

  /// Legacy container name (`avatars` | `stories` | `posts`), used as the
  /// top-level object-name prefix.
  final String prefix;

  final MediaStorage _storage;
  final Dio _dio;

  /// Object name (`<prefix>/<path>`) with each path segment percent-encoded but
  /// the `/` separators preserved, so timestamps/colons in [path] are URL-safe.
  /// Upload and [getPublicUrl] share this so the stored URL always matches the
  /// object that was written.
  String _encodedObject(String path) =>
      '$prefix/$path'.split('/').map(Uri.encodeComponent).join('/');

  /// The longest one upload may take: 30 s plus enough for [bytes] at a slow
  /// 50 KB/s, capped at 15 minutes (a large video on a poor connection).
  static Duration _uploadTimeout(int bytes) {
    final seconds = 30 + bytes ~/ (50 * 1024);
    return Duration(seconds: seconds.clamp(30, 15 * 60));
  }

  /// Asks the backend for a link that writes the object at [path], and the
  /// path it will be stored at (an avatar goes under the user's own folder).
  Future<({String url, String path})> _uploadLink(
    String path,
    String contentType,
  ) async {
    final idToken = _storage.idToken;
    if (idToken == null) throw StateError('MediaStorage.idToken is not set');
    for (final forceRefresh in [false, true]) {
      final token = await idToken(forceRefresh: forceRefresh);
      if (token == null) throw StateError('Not signed in');
      final response = await _dio.post<Map<String, dynamic>>(
        MediaStorage._uploadLinkUrl,
        data: {'bucket': prefix, 'path': path, 'contentType': contentType},
        options: Options(
          headers: <String, dynamic>{'Authorization': 'Bearer $token'},
          // A 401 is retried once with a fresh token.
          validateStatus: (status) => status != null,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status == 401 && !forceRefresh) continue;
      final data = response.data;
      if (status != 200 || data == null) {
        throw Exception(
          'Upload link refused ($status) for $prefix/$path: ${data?['error']}',
        );
      }
      return (url: data['uploadUrl'] as String, path: data['path'] as String);
    }
    throw Exception('Upload link refused (401) for $prefix/$path');
  }

  /// Uploads [bytes] as an object at [path] (under this bucket's prefix),
  /// overwriting any existing object.
  ///
  /// Mirrors `StorageFileApi.uploadBinary`. Returns the path the object was
  /// stored at — pass that to [getPublicUrl] (for an avatar it is placed under
  /// the user's folder). Throws on a refused link or a non-2xx upload, or
  /// when it takes longer than [_uploadTimeout] (the request is cancelled, so
  /// the connection is freed).
  Future<String> uploadBinary(
    String path,
    Uint8List bytes, {
    MediaFileOptions fileOptions = const MediaFileOptions(),
  }) async {
    final contentType = fileOptions.contentType ?? 'image/jpeg';
    final link = await _uploadLink(path, contentType);
    final cancel = CancelToken();
    final deadline = Timer(
      _uploadTimeout(bytes.length),
      () => cancel.cancel('upload timed out'),
    );
    final Response<dynamic> response;
    try {
      response = await _dio.put<dynamic>(
        link.url,
        // A Stream<List<int>> body bypasses dio's request transformer so the
        // raw bytes are sent verbatim (required for binary uploads).
        data: Stream<List<int>>.fromIterable([bytes]),
        cancelToken: cancel,
        options: Options(
          headers: <String, dynamic>{
            Headers.contentLengthHeader: bytes.length,
            Headers.contentTypeHeader: contentType,
            if (fileOptions.cacheControl != null)
              'Cache-Control': 'max-age=${fileOptions.cacheControl}',
          },
          followRedirects: false,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
    } finally {
      deadline.cancel();
    }
    if (response.statusCode == null || response.statusCode! >= 300) {
      throw Exception(
        'OCI media upload failed (${response.statusCode}) for $prefix/$path',
      );
    }
    return link.path;
  }

  /// Returns the public (anonymous-read) URL for the object at [path].
  ///
  /// Mirrors `StorageFileApi.getPublicUrl`.
  String getPublicUrl(String path) =>
      '${MediaStorage._readBase}/o/${_encodedObject(path)}';
}

/// {@template media_file_options}
/// Upload options the app sets. [cacheControl] is a string number of seconds,
/// emitted as `Cache-Control: max-age=<seconds>`.
/// {@endtemplate}
class MediaFileOptions {
  /// {@macro media_file_options}
  const MediaFileOptions({this.contentType, this.cacheControl});

  /// MIME type of the uploaded object, e.g. `image/jpeg`.
  final String? contentType;

  /// Cache max-age in seconds, as a string.
  final String? cacheControl;
}
