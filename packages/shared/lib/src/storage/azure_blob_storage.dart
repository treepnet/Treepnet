import 'dart:typed_data';

import 'package:dio/dio.dart';

/// {@template azure_blob_storage}
/// Minimal Azure Blob Storage client that mirrors the tiny slice of the
/// Supabase Storage API the app relies on (`from(bucket).uploadBinary(...)` and
/// `getPublicUrl(...)`), so call sites migrate off Supabase Storage with a
/// one-line change of the storage source.
///
/// Reads are anonymous (the containers grant public blob read), so only the
/// write path needs credentials. Uploads authenticate with a container-scoped
/// SAS token appended to the blob URL.
///
/// TODO(treepnet): move [_sas] to env, scope it tighter with a shorter expiry,
/// and ideally have a backend issue short-lived SAS per user before production.
/// {@endtemplate}
class AzureBlobStorage {
  AzureBlobStorage._();

  /// Shared instance — mirrors `Supabase.instance.client.storage`.
  static final AzureBlobStorage instance = AzureBlobStorage._();

  /// Azure Storage account name. Blob endpoint host is
  /// `<account>.blob.core.windows.net`.
  static const account = 'treepnetstorage';

  /// Account SAS granting create/write/add on blob objects (read stays public).
  static const _sas =
      'se=2030-01-01T00%3A00%3A00Z&sp=wac&spr=https&sv=2026-04-06&ss=b&srt=o&sig=Oe9NVHu838Rd1A60c9ZnX2gZMi%2BV7HYt5sZmWg1se3s%3D';

  /// Returns a handle scoped to [container] (the Blob analogue of a Supabase
  /// Storage bucket).
  AzureBlobBucket from(String container) =>
      AzureBlobBucket(account: account, container: container, sas: _sas);
}

/// {@template azure_blob_bucket}
/// A handle to one Azure Blob container, exposing the subset of the Supabase
/// `StorageFileApi` used across the app.
/// {@endtemplate}
class AzureBlobBucket {
  /// {@macro azure_blob_bucket}
  AzureBlobBucket({
    required this.account,
    required this.container,
    required this.sas,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// Azure Storage account name.
  final String account;

  /// Blob container name.
  final String container;

  /// SAS query string (without a leading `?`) authorising writes.
  final String sas;

  final Dio _dio;

  String get _containerUrl =>
      'https://$account.blob.core.windows.net/$container';

  /// Uploads [bytes] as a block blob at [path], overwriting any existing blob.
  ///
  /// Mirrors `StorageFileApi.uploadBinary`; returns the object [path] on
  /// success and throws on a non-2xx response.
  Future<String> uploadBinary(
    String path,
    Uint8List bytes, {
    AzureFileOptions fileOptions = const AzureFileOptions(),
  }) async {
    final url = '$_containerUrl/$path?$sas';
    final response = await _dio.put<dynamic>(
      url,
      // A Stream<List<int>> body bypasses dio's request transformer so the raw
      // bytes are sent verbatim (required for binary uploads).
      data: Stream<List<int>>.fromIterable([bytes]),
      options: Options(
        headers: <String, dynamic>{
          'x-ms-blob-type': 'BlockBlob',
          Headers.contentLengthHeader: bytes.length,
          if (fileOptions.contentType != null)
            Headers.contentTypeHeader: fileOptions.contentType,
          if (fileOptions.cacheControl != null)
            'x-ms-blob-cache-control': 'max-age=${fileOptions.cacheControl}',
        },
        followRedirects: false,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    if (response.statusCode == null || response.statusCode! >= 300) {
      throw Exception(
        'Azure Blob upload failed (${response.statusCode}) for $container/$path',
      );
    }
    return path;
  }

  /// Returns the public (anonymous-read) URL for the blob at [path].
  ///
  /// Mirrors `StorageFileApi.getPublicUrl`.
  String getPublicUrl(String path) => '$_containerUrl/$path';
}

/// {@template azure_file_options}
/// Upload options mirroring the fields of Supabase's `FileOptions` that the app
/// actually sets. [cacheControl] is a string number of seconds (as Supabase
/// expects) and is emitted as `Cache-Control: max-age=<seconds>`.
/// {@endtemplate}
class AzureFileOptions {
  /// {@macro azure_file_options}
  const AzureFileOptions({this.contentType, this.cacheControl});

  /// MIME type of the uploaded blob, e.g. `image/jpeg`.
  final String? contentType;

  /// Cache max-age in seconds, as a string (mirrors Supabase `FileOptions`).
  final String? cacheControl;
}
