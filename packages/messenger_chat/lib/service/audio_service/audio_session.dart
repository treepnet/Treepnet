part of messenger_chat;

class _AudioSessionManager {
  _AudioSessionManager._internal();

  factory _AudioSessionManager() => _instance;
  static final _AudioSessionManager _instance =
      _AudioSessionManager._internal();

  AudioSession? session;

  Future<void> initIfNeeded() async {
    if (session != null) return;

    session = await AudioSession.instance;

    await session!.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.videoChat,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidWillPauseWhenDucked: true,
      ),
    );

    await session!.setActive(true);
  }

  Future<void> deactivate() async {
    if (session != null) {
      await session!.setActive(false);
      session = null;
    }
  }
}
