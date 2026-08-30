part of messenger_chat;

final class _UploadParams extends Equatable {
  const _UploadParams(this.file, this.key, {required this.onSendProgress});

  final String key;
  final String file;
  final Function(int sent, int total) onSendProgress;

  @override
  List<Object?> get props => [file, key, onSendProgress];
}
