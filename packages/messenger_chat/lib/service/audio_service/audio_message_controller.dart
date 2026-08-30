part of messenger_chat;

class _AudioMessageController {
  _AudioMessageController() {
    _subscribeToStreams();
  }

  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<_AudioMessageData> audioMessage = ValueNotifier(
    _AudioMessageData(),
  );

  final List<StreamSubscription> _subscriptions = [];
  bool _isDisposed = false;
  bool _isAudioLoaded = false;
  bool average = false;
  String _currentAsset = '';
  Future<void>? _loadingFuture;

  void _subscribeToStreams() {
    _subscriptions.add(
      _player.positionStream.listen(_safe(_onPositionChanged)),
    );
    _subscriptions.add(
      _player.playerStateStream.listen(_safe(_onPlayerStateChanged)),
    );
    _subscriptions.add(
      _player.durationStream.listen(_safe(_onDurationChanged)),
    );
  }

  /// Wraps a callback to safely ignore if disposed
  Function(T) _safe<T>(void Function(T) fn) => (event) {
    if (_isDisposed) return;
    fn(event);
  };

  void _onPositionChanged(Duration position) {
    if (_isDisposed) return;
    final duration = _player.duration ?? Duration.zero;
    final newValue = duration.inMilliseconds > 0
        ? audioMessage.value.copyWith(
            remainingDuration: duration - position,
            progress: position.inMilliseconds / duration.inMilliseconds,
          )
        : audioMessage.value.copyWith(remainingDuration: Duration.zero);

    audioMessage.value = newValue;
  }

  void _onPlayerStateChanged(PlayerState state) async {
    if (_isDisposed) return;

    audioMessage.value = audioMessage.value.copyWith(
      isPlaying: _player.playing,
    );

    if (state.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      await _player.pause();
      await _AudioPlayerManager().pauseIfPlaying();
    }
  }

  void _onDurationChanged(Duration? duration) {
    if (_isDisposed) return;

    audioMessage.value = audioMessage.value.copyWith(
      remainingDuration: Duration.zero,
    );
  }

  Future<void> loadAudio(String url) async {
    if (_isDisposed) return;

    if (_isAudioLoaded && _currentAsset == url && _loadingFuture == null)
      return;

    if (_loadingFuture != null) {
      await _loadingFuture;
      return;
    }

    _loadingFuture = () async {
      try {
        _currentAsset = url;

        await _player.setUrl(url);

        _isAudioLoaded = true;
      } catch (e, st) {
        debugPrint('[AudioMessageController] ❌ Error loading audio: $e\n$st');
        _isAudioLoaded = false;
      } finally {
        _loadingFuture = null;
      }
    }();

    await _loadingFuture;
  }

  Future<void> togglePlay(String assetPath) async {
    if (_isDisposed) return;
    try {
      await loadAudio(assetPath);
      _ChatLogger.print('[AudioMessageController] Audio loaded: $assetPath');

      if (_isDisposed) return;

      if (_player.playing) {
        await _player.pause();
      } else {
        await _AudioPlayerManager().setActive(_player);
        await _player.play();
      }
    } catch (e, st) {
      _ChatLogger.print(
        '[AudioMessageController] ❌ Error loading audio: $e\n$st',
      );
    }
  }

  Future<void> seekByTap(double dx, double width, String assetPath) async {
    if (_isDisposed) return;
    await loadAudio(assetPath);

    if (_isDisposed) return;

    if (_player.processingState != ProcessingState.ready) {
      _ChatLogger.print('Player is not ready yet.');
      return;
    }

    final duration = _player.duration;
    if (duration == null) {
      _ChatLogger.print('Duration is null');
      return;
    }

    final relative = (dx / width).clamp(0.0, 1.0);
    final position = Duration(
      milliseconds: (duration.inMilliseconds * relative).round(),
    );

    _ChatLogger.print('[MilliyChat] Seek position: $position');

    await _AudioPlayerManager().setActive(_player);

    await _player.seek(position);
    await _player.play();
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    for (final sub in _subscriptions) {
      sub.cancel();
    }

    if (_player.playing) {
      _player.stop();
    }
    // _AudioWaveformService.dispose();

    _player.dispose();
    audioMessage.dispose();
  }
}
