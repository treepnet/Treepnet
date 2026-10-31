part of messenger_chat;

/// Ma'lumot manbai. Tarmoq bilan bevosita ishlamaydi - hamma narsa ilova
/// bergan [ChatTransport] orqali o'tadi.
abstract class _ChatNetworkDataSource {
  factory _ChatNetworkDataSource() => _$ChatNetworkDataSource();

  Future<_MessageResponse> getMessages(_ParamsGetMessage params);

  /// Telefonda saqlangan oxirgi xabarlar ([ChatTransport.cachedHistory]).
  Future<_MessageResponse?> getCachedMessages();
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
  Future<_MessageResponse?> getCachedMessages() async {
    try {
      final result = await _transport.cachedHistory();
      if (result == null || result.messages.isEmpty) return null;
      return _MessageResponse(
        messages: _MessageModel.fromHistory(result, myId: _myId),
        currentPage: 1,
        totalPage: 1,
        totalItems: result.messages.length,
        // Older pages come from the network once it answers.
        hasNextPage: false,
        hasPreviousPage: false,
      );
    } catch (_) {
      return null;
    }
  }
}
