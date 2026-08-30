part of messenger_chat;

/// Ma'lumot manbai. Tarmoq bilan bevosita ishlamaydi - hamma narsa ilova
/// bergan [ChatTransport] orqali o'tadi.
abstract class _ChatNetworkDataSource {
  factory _ChatNetworkDataSource() => _$ChatNetworkDataSource();

  Future<_MessageResponse> getMessages(_ParamsGetMessage params);

  Future<_UploadResponse> uploadMessage(_UploadParams params);
}

final class _$ChatNetworkDataSource implements _ChatNetworkDataSource {
  ChatTransport get _transport => _ChatRuntime.instance.transport;

  String get _myId => _ChatRuntime.instance.me.id;

  @override
  Future<_MessageResponse> getMessages(_ParamsGetMessage params) =>
      _handleRequest(() async {
        final page = params.page ?? 1;
        final size = params.size ?? 25;

        final result = await _transport.loadHistory(page: page, size: size);

        return _MessageResponse(
          messages: _MessageModel.fromHistory(result, myId: _myId),
          currentPage: page,
          totalPage: result.hasMore ? page + 1 : page,
          totalItems: result.messages.length,
          hasNextPage: result.hasMore,
          hasPreviousPage: page > 1,
        );
      });

  @override
  Future<_UploadResponse> uploadMessage(_UploadParams file) =>
      _handleRequest(() async {
        final kind = _ContentType.fromPath(file.file).kind;

        final result = await _transport.uploadAttachment(
          filePath: file.file,
          clientKey: file.key,
          kind: kind,
          onProgress: file.onSendProgress,
        );

        return _UploadResponse(
          url: result.url,
          waveformUrl: result.waveformUrl ?? '',
          thumbnailUrl: result.thumbnailUrl ?? '',
          duration: result.duration ?? '',
          size: result.size ?? '',
        );
      });
}
