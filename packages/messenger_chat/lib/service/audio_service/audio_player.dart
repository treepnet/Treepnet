part of messenger_chat;

class _AudioPlayerManager {
  factory _AudioPlayerManager() => _instance;

  _AudioPlayerManager._internal();

  static final _AudioPlayerManager _instance = _AudioPlayerManager._internal();

  AudioPlayer? _activePlayer;
  _AudioSessionManager? _audioSessionManager;

  Future<void> init() async {
    _audioSessionManager = _AudioSessionManager();
    await _audioSessionManager!.initIfNeeded();
  }

  Future<void> setActive(AudioPlayer player) async {
    if (_activePlayer != null && _activePlayer != player) {
      await _activePlayer!.pause();
    }
    _activePlayer = player;

    if (_audioSessionManager == null) {
      await init();
    }

    await _audioSessionManager!.session?.setActive(true);
  }

  Future<void> pauseIfPlaying() async {
    if (_activePlayer != null) {
      await _activePlayer!.pause();
    }
  }

  void clearActive(AudioPlayer player) {
    if (_activePlayer == player) {
      _activePlayer = null;
    }
  }
}
