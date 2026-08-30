part of messenger_chat;

class _VoiceRecorder {
  factory _VoiceRecorder() => _instance;

  _VoiceRecorder._internal();

  static final _VoiceRecorder _instance = _VoiceRecorder._internal();

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  DateTime? _startTime;

  final ValueNotifier<_VoiceServiceData> audioData =
      ValueNotifier(_VoiceServiceData());

  String? _path;

  Function(String path)? onVoiceSend;

  Offset _startPosition = Offset.zero;

  void onLongPressStart(Offset position) async {
    _startPosition = position;

    audioData.value = audioData.value.copyWith(
      isCancelled: false,
      isLocked: false,
      isRecording: false,
      dragLeftOffset: 0.0,
      dragTopOffset: 0.0,
    );

    await AppPermissionManager.requestPermission(
      permission: Permission.microphone,
      onGranted: () async {
        await startRecording();
      },
      onDenied: () {},
      onPermanentlyDenied: () {},
    );
  }

  Future<void> onLongPressMoveUpdate(
      BuildContext context, Offset position) async {
    final dx = position.dx - _startPosition.dx;
    final dy = position.dy - _startPosition.dy;

    const double minDragLeftOffset = -100.0;
    const double maxDragLeftOffset = 0.0;

    const double minDragTopOffset = -30.0;
    const double maxDragTopOffset = 0.0;

    final bool isLeftSwipeActive = dx.abs() > 30 && dx < 0;
    final bool isTopSwipeActive = dy.abs() > 5 && dy < 0;

    if (isLeftSwipeActive && !isTopSwipeActive) {
      final newLeftOffset = dx.clamp(minDragLeftOffset, maxDragLeftOffset);

      if (audioData.value.dragLeftOffset != newLeftOffset) {
        audioData.value =
            audioData.value.copyWith(dragLeftOffset: newLeftOffset);
      }
    } else if (isTopSwipeActive && !isLeftSwipeActive) {
      final newTopOffset = dy.clamp(minDragTopOffset, maxDragTopOffset);

      if (!audioData.value.isLocked &&
          audioData.value.dragTopOffset != newTopOffset) {
        audioData.value = audioData.value.copyWith(dragTopOffset: newTopOffset);
      }
    } else if (!isLeftSwipeActive && !isTopSwipeActive) {
      final newLeftOffset = dx.clamp(minDragLeftOffset, maxDragLeftOffset);

      final newTopOffset = dy.clamp(minDragTopOffset, maxDragTopOffset);

      if (audioData.value.dragLeftOffset != newLeftOffset) {
        audioData.value =
            audioData.value.copyWith(dragLeftOffset: newLeftOffset);
      }

      if (!audioData.value.isLocked &&
          audioData.value.dragTopOffset != newTopOffset) {
        audioData.value = audioData.value.copyWith(dragTopOffset: newTopOffset);
      }
    }

    if (audioData.value.dragLeftOffset <= (minDragLeftOffset + 30) &&
        !audioData.value.isCancelled &&
        !audioData.value.isLocked) {
      audioData.value = audioData.value.copyWith(isCancelled: true);
      cancelRecording();
    }

    if (audioData.value.dragTopOffset <= minDragTopOffset &&
        !audioData.value.isLocked &&
        !audioData.value.isCancelled) {
      audioData.value = audioData.value.copyWith(isLocked: true);
      await Vibration.vibrate(duration: 100);
    }
  }

  void onLongPressEnd(BuildContext context, {required Function() success}) {
    final current = audioData.value;
    audioData.value = audioData.value.copyWith(dragLeftOffset: 0.0);
    if (current.isRecording && !current.isLocked && !current.isCancelled) {
      sendRecording(context, success: success);
    }
  }

  void onTap(BuildContext context) {
    final current = audioData.value;

    if (current.isLocked && current.isRecording) {
      sendRecording(context, success: () {});
    }
  }

  T platformConfig<T>({required T android, required T ios}) {
    if (Platform.isAndroid) {
      return android;
    } else if (Platform.isIOS) {
      return ios;
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  Future<void> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        _ChatLogger.warning('Recording started');

        await _AudioPlayerManager().pauseIfPlaying();

        await Vibration.vibrate(duration: 100);
        final AudioEncoder encoder = platformConfig<AudioEncoder>(
          ios: AudioEncoder.aacLc,
          android: AudioEncoder.aacLc,
        );

        if (!await _recorder.isEncoderSupported(encoder)) return;

        final config = RecordConfig(encoder: encoder, numChannels: 1);

        _path = await _getFilePath();

        await _AudioSessionManager().initIfNeeded();

        await _recorder.start(config, path: _path ?? '');

        _startTime = DateTime.now();

        audioData.value = audioData.value
            .copyWith(isRecording: true, currentDuration: '0:00');

        _timer?.cancel();

        _timer = Timer.periodic(const Duration(milliseconds: 30), (_) async {
          if (_startTime == null) return;
          final duration = DateTime.now().difference(_startTime!);

          final minutes = duration.inMinutes;
          final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

          final amp = await _recorder.getAmplitude();
          final double scale = _normalizeAmplitude(amp.current);

          audioData.value = audioData.value.copyWith(
            amplitude: scale,
            currentDuration: '$minutes:$seconds',
          );
        });
      }
    } catch (e) {
      _ChatLogger.failure('[VoiceRecorder Error] ❌ $e');
    }
  }

  Future<String?> stopRecording() async {
    try {
      final result = await _recorder.stop();
      await _AudioSessionManager().deactivate();
      _stopTimer();
      audioData.value = audioData.value.copyWith(isRecording: false);
      await Vibration.vibrate(duration: 100);

      _ChatLogger.success(result ?? 'Unknown path');
      return result;
    } catch (e) {
      _ChatLogger.failure('[VoiceRecorder Error - stopRecording] ❌ $e');

      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      await _AudioSessionManager().deactivate();
      _stopTimer();
      _path = null;
      audioData.value = audioData.value.initialValue.copyWith(
        isCancelled: true,
        isRecording: false,
      );
      await Vibration.vibrate(duration: 50);
      _ChatLogger.warning('Recording cancelled');
    } catch (e) {
      _ChatLogger.failure('[VoiceRecorder Error - cancelRecording] ❌ $e');
    }
  }

  Future<void> sendRecording(BuildContext context,
      {required Function() success}) async {
    final result = await stopRecording();
    if (result == null || audioData.value.isCancelled) return;

    final file = File(result);
    final bytes = await file.length();
    final String sizeInMb = (bytes / (1024 * 1024)).toStringAsFixed(2);
    if (file.existsSync()) {
      BlocProvider.of<ChatCubit>(
        context,
      ).sendFileMessage(result, '$sizeInMb Mb',
          downScrollCallback: success, context: context);

      onVoiceSend?.call(result);
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _startTime = null;

    audioData.value =
        audioData.value.copyWith(currentDuration: '0:00', amplitude: 0.0);
  }

  Future<String> _getFilePath() async {
    final dir = await getTemporaryDirectory();
    final String extension = platformConfig(ios: '.m4a', android: '.m4a');
    return '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}$extension';
  }

  /// Chat ekrani yopilganda chaqiriladi.
  ///
  /// [_VoiceRecorder] - singleton, shuning uchun [audioData] ni yo'q
  /// qilmaymiz: aks holda chat qayta ochilganda vidjetlar allaqachon
  /// dispose qilingan ValueNotifier ga obuna bo'lmoqchi bo'ladi va butun
  /// ekran qulaydi. Buning o'rniga holatni boshlang'ich ko'rinishga
  /// qaytaramiz.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _startTime = null;

    if (audioData.value.isRecording) {
      // Yozib olish davom etayotgan bo'lsa - to'xtatamiz.
      unawaited(_recorder.stop().catchError((_) => null));
    }

    audioData.value = _VoiceServiceData();
  }
}

double _normalizeAmplitude(double rawAmplitude) {
  final double normalizedAmp = rawAmplitude.abs();
  final double normalized = (normalizedAmp / 40.0).clamp(0.0, 1.0);
  return 2.5 - (normalized * 1.5);
}
