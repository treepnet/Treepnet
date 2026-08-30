part of messenger_chat;

mixin _MessageController {
  static  ValueNotifier<_MessageControllerData> controller = ValueNotifier(
    _MessageControllerData.initial,
  );

 static ValueNotifier<_MessageControllerData> updateStatus(_MessageControllerData data) {
   controller.value = controller.value.copyWith(status: data.status, progress: data.progress);
   return controller;
  }
}

class _MessageControllerData {
  _MessageControllerData({required this.progress, required this.status});

  final double progress;
  final MessageStatus status;

  static _MessageControllerData get initial =>
      _MessageControllerData(progress: 0, status: MessageStatus.delivered);

  _MessageControllerData copyWith({double? progress, MessageStatus? status}) =>
      _MessageControllerData(progress: progress ?? this.progress, status: status ?? this.status);
}
