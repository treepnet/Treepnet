part of messenger_chat;

class _AudioMessageData {
  _AudioMessageData({
    this.isPlaying = false,
    this.progress = 0.0,
    this.remainingDuration = Duration.zero,
    this.waveform,
  });

  final bool isPlaying;
  final double progress;
  final Duration remainingDuration;
  final Float32List? waveform;

  String get duration {
    final double totalSeconds = remainingDuration.inMicroseconds / 1000000.0;
    final int displaySeconds = totalSeconds.ceil();

    final minutes = (displaySeconds ~/ 60).toString();
    final seconds = (displaySeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  _AudioMessageData copyWith({
    bool? isPlaying,
    double? progress,
    Duration? remainingDuration,
    Float32List? waveform,
  }) => _AudioMessageData(
    isPlaying: isPlaying ?? this.isPlaying,
    progress: progress ?? this.progress,
    remainingDuration: remainingDuration ?? this.remainingDuration,
    waveform: waveform ?? this.waveform,
  );
}
