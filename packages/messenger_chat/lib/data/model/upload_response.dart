part of messenger_chat;

/// Fayl yuklashning ichki natijasi.
class _UploadResponse {
  const _UploadResponse({
    required this.url,
    this.waveformUrl = '',
    this.thumbnailUrl = '',
    this.duration = '',
    this.size = '',
  });

  /// Yuklangan faylning to'liq manzili.
  final String url;

  /// Ovozli xabar to'lqin shakli (SVG) manzili.
  final String waveformUrl;

  /// Video uchun thumbnail manzili.
  final String thumbnailUrl;

  final String duration;
  final String size;

  UploadResult get result =>
      url.isNotEmpty ? UploadResult.success : UploadResult.error;

  _UploadResponse copyWith({
    String? url,
    String? waveformUrl,
    String? thumbnailUrl,
    String? duration,
    String? size,
  }) => _UploadResponse(
    url: url ?? this.url,
    waveformUrl: waveformUrl ?? this.waveformUrl,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    duration: duration ?? this.duration,
    size: size ?? this.size,
  );
}

enum UploadResult {
  success,
  error;

  bool get isSuccess => this == UploadResult.success;

  bool get isError => this == UploadResult.error;
}
