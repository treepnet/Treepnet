part of messenger_chat;

class MessengerChatConfig {
  MessengerChatConfig({
    required this.baseUrl,
    required this.userUuid,
    required this.xApp,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.lang,
  });
  final String baseUrl;
  final String userUuid;
  final String xApp;
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final String lang;

  MessengerChatConfig copyWith({
    String? baseUrl,
    String? userUuid,
    String? xApp,
    String? deviceId,
    String? deviceName,
    String? deviceType,
    String? lang,
  }) =>
      MessengerChatConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        userUuid: userUuid ?? this.userUuid,
        xApp: xApp ?? this.xApp,
        deviceId: deviceId ?? this.deviceId,
        deviceName: deviceName ?? this.deviceName,
        deviceType: deviceType ?? this.deviceType,
        lang: lang ?? this.lang,
      );
}

class MessengerChatController {
  MessengerChatController._();
  static final MessengerChatController _instance = MessengerChatController._();
  factory MessengerChatController() => _instance;

  final _stream = StreamController<MessengerChatConfig>.broadcast();
  MessengerChatConfig? _config;

  Stream<MessengerChatConfig> get stream => _stream.stream;
  MessengerChatConfig? get value => _config;

  Future<void> initializeFromStorage() async {
    final baseUrl = await _SecureStorage.getBaseUrl();
    final userUuid = await _SecureStorage.getUserUuid();
    final xApp = await _SecureStorage.getXApp();
    final deviceId = await _SecureStorage.getDeviceId();
    final deviceName = await _SecureStorage.getDeviceName();
    final deviceType = await _SecureStorage.getDeviceType();
    final lang = await _SecureStorage.getLang();
    await _OutboxService().init();
    if (baseUrl.isEmpty) return;
    setConfig(
      baseUrl: baseUrl,
      userUuid: userUuid,
      xApp: xApp,
      deviceId: deviceId,
      deviceName: deviceName,
      deviceType: deviceType,
      lang: lang.isEmpty ? 'ru' : lang,
    );
  }

  Future<void> setConfig({
    required String baseUrl,
    required String userUuid,
    required String xApp,
    required String deviceId,
    required String deviceName,
    required String deviceType,
    required String lang,
  }) async {
    _config = MessengerChatConfig(
      baseUrl: baseUrl,
      userUuid: userUuid,
      xApp: xApp,
      deviceId: deviceId,
      deviceName: deviceName,
      deviceType: deviceType,
      lang: lang,
    );
    await _OutboxService().init();
    _stream.add(_config!);
    await _SecureStorage.storage.write(
      key: _SecureStorage.baseUrl,
      value: baseUrl,
    );
    await _SecureStorage.storage.write(
      key: _SecureStorage.userUuid,
      value: userUuid,
    );
    await _SecureStorage.storage.write(key: _SecureStorage.xApp, value: xApp);
    await _SecureStorage.storage.write(
      key: _SecureStorage.deviceId,
      value: deviceId,
    );
    await _SecureStorage.storage.write(
      key: _SecureStorage.deviceName,
      value: deviceName,
    );
    await _SecureStorage.storage.write(
      key: _SecureStorage.deviceType,
      value: deviceType,
    );
    await _SecureStorage.storage.write(key: _SecureStorage.lang, value: lang);
  }

  void dispose() {
    _stream.close();
  }
}
