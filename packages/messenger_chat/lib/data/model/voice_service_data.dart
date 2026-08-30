part of messenger_chat;

class _VoiceServiceData {
  _VoiceServiceData({
    this.isRecording = false,
    this.isLocked = false,
    this.isCancelled = false,
    this.currentDuration = '0:00',
    this.amplitude = 0.0,
    this.dragLeftOffset = 0.0,
    this.dragTopOffset = 0.0,
  });

  final bool isRecording;
  final bool isLocked;
  final bool isCancelled;
  final String currentDuration;
  final double amplitude;
  final double dragLeftOffset;
  final double dragTopOffset;

  _VoiceServiceData copyWith({
    bool? isRecording,
    bool? isLocked,
    bool? isCancelled,
    String? currentDuration,
    double? amplitude,
    double? dragLeftOffset,
    double? dragTopOffset,
  }) =>
      _VoiceServiceData(
        isRecording: isRecording ?? this.isRecording,
        isLocked: isLocked ?? this.isLocked,
        isCancelled: isCancelled ?? this.isCancelled,
        currentDuration: currentDuration ?? this.currentDuration,
        amplitude: amplitude ?? this.amplitude,
        dragLeftOffset: dragLeftOffset ?? this.dragLeftOffset,
        dragTopOffset: dragTopOffset ?? this.dragTopOffset,
      );

  _VoiceServiceData get initialValue => _VoiceServiceData();
}
