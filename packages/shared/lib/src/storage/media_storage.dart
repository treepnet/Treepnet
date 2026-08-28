import 'dart:typed_data';

import 'package:dio/dio.dart';

/// {@template media_storage}
/// Minimal OCI Object Storage client that mirrors the tiny slice of the
/// Supabase Storage API the app relies on (`from(bucket).uploadBinary(...)`
/// and `getPublicUrl(...)`), so the media call sites stay unchanged after
/// moving off Azure Blob Storage.
///
/// The app uses ONE OCI bucket. Each legacy "bucket" name the call sites pass
/// (`avatars`, `stories`, `posts`) becomes a top-level object-name prefix
/// inside that single bucket.
///
/// Reads are anonymous: the bucket's visibility is Public (ObjectRead), so the
/// native object URL is a stable public link and needs no signing — the same
/// model the Azure containers used. Writes go through a bucket-scoped
/// Pre-Authenticated Request (PAR) whose token, embedded in the URL, is the
/// write credential — the OCI analogue of the old Azure SAS.
///
/// TODO(treepnet): before real production, mint short-lived per-user PARs from
/// a backend instead of shipping one long-lived bucket write PAR in the
/// client, and move `_writePar` into env rather than source.
/// {@endtemplate}
class MediaStorage {
  MediaStorage._();

  /// Shared instance — mirrors `Supabase.instance.client.storage`.
  static final MediaStorage instance = MediaStorage._();

  /// Bucket-scoped write PAR (Pre-Authenticated Request) URL.
  ///
  /// This is the full URL OCI gives you when you create a PAR with:
  ///   • Target: "Bucket"  • Access: "Permit object writes"  • long expiry.
  /// Shape (single line):
  ///   `https://objectstorage.{region}.oraclecloud.com/p/{token}/n/{ns}/b/{bucket}/o/`
  ///
  /// Everything else (region, namespace, bucket, and the public-read base URL)
  /// is derived from this single value.
  static const _writePar =
      'https://objectstorage.eu-frankfurt-1.oraclecloud.com'
      '/p/3qzWuaJDL3XxoiWzffw42H6kPYUPOgFbm75so906blXJp3LAEUdZibZvCimLbec0'
      '/n/fryarohmp0gm/b/treepnet-media/o/';

  /// Returns a handle scoped to [bucket] — the legacy container name, used here
  /// as the object-name prefix inside the single OCI bucket.
  MediaBucket from(String bucket) =>
      MediaBucket(writePar: _writePar, prefix: bucket);
}

/// {@template media_bucket}
/// A handle to one logical media "bucket" (object-name prefix) inside the single
/// OCI bucket, exposing the subset of the Supabase `StorageFileApi` used across
/// the app.
/// {@endtemplate}
class MediaBucket {
  /// {@macro media_bucket}
  MediaBucket({
    required this.writePar,
    required this.prefix,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// Bucket-scoped write PAR URL (see [MediaStorage._writePar]).
  final String writePar;

  /// Legacy container name (`avatars` | `stories` | `posts`), used as the
  /// top-level object-name prefix.
  final String prefix;

  final Dio _dio;

  /// Write base: the PAR URL with any trailing `/o/` (or `/o`) removed, leaving
  /// `https://objectstorage.{region}.oraclecloud.com/p/{token}/n/{ns}/b/{bucket}`.
  String get _writeBase {
    var b = writePar;
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    if (b.endsWith('/o')) b = b.substring(0, b.length - 2);
    return b;
  }

  /// Public-read base: the write base with the `/p/{token}` PAR segment
  /// removed, leaving
  /// `https://objectstorage.{region}.oraclecloud.com/n/{ns}/b/{bucket}`.
  /// Requires the bucket's visibility to be Public (ObjectRead).
  String get _readBase {
    final b = _writeBase;
    final pIdx = b.indexOf('/p/');
    final nIdx = b.indexOf('/n/');
    if (pIdx != -1 && nIdx > pIdx) {
      return b.substring(0, pIdx) + b.substring(nIdx);
    }
    return b;
  }

  /// Object name (`<prefix>/<path>`) with each path segment percent-encoded but
  /// the `/` separators preserved, so timestamps/colons in [path] are URL-safe.
  /// Upload and [getPublicUrl] share this so the stored URL always matches the
  /// object that was written.
  String _encodedObject(String path) =>
      '$prefix/$path'.split('/').map(Uri.encodeComponent).join('/');

  /// Uploads [bytes] as an object at [path] (under this bucket's prefix),
  /// overwriting any existing object.
  ///
  /// Mirrors `StorageFileApi.uploadBinary`; returns [path] on success and throws
  /// on a non-2xx response.
  Future<String> uploadBinary(
    String path,
    Uint8List bytes, {
    MediaFileOptions fileOptions = const MediaFileOptions(),
  }) async {
    final object = _encodedObject(path);
    final url = '$_writeBase/o/$object';
    final response = await _dio.put<dynamic>(
      url,
      // A Stream<List<int>> body bypasses dio's request transformer so the raw
      // bytes are sent verbatim (required for binary uploads).
      data: Stream<List<int>>.fromIterable([bytes]),
      options: Options(
        headers: <String, dynamic>{
          Headers.contentLengthHeader: bytes.length,
          if (fileOptions.contentType != null)
            Headers.contentTypeHeader: fileOptions.contentType,
          if (fileOptions.cacheControl != null)
            'Cache-Control': 'max-age=${fileOptions.cacheControl}',
        },
        followRedirects: false,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    if (response.statusCode == null || response.statusCode! >= 300) {
      throw Exception(
        'OCI media upload failed (${response.statusCode}) for $prefix/$path',
      );
    }
    return path;
  }

  /// Returns the public (anonymous-read) URL for the object at [path].
  ///
  /// Mirrors `StorageFileApi.getPublicUrl`.
  String getPublicUrl(String path) => '$_readBase/o/${_encodedObject(path)}';
}

/// {@template media_file_options}
/// Upload options mirroring the fields of Supabase's `FileOptions` that the app
/// actually sets. [cacheControl] is a string number of seconds (as Supabase
/// expects) and is emitted as `Cache-Control: max-age=<seconds>`.
/// {@endtemplate}
class MediaFileOptions {
  /// {@macro media_file_options}
  const MediaFileOptions({this.contentType, this.cacheControl});

  /// MIME type of the uploaded object, e.g. `image/jpeg`.
  final String? contentType;

  /// Cache max-age in seconds, as a string (mirrors Supabase `FileOptions`).
  final String? cacheControl;
}
