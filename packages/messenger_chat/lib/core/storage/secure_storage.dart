part of messenger_chat;

mixin _SecureStorage {
  static final String baseUrl = 'baseUrl';
  static final String messageKeyList = 'messageKeyList';
  static final String userUuid = 'userUuid';
  static final String xApp = 'x-app';
  static final String deviceId = 'device-id';
  static final String deviceName = 'device-name';
  static final String deviceType = 'device-type';
  static final String lang = 'lang';
  static final String firstTime = 'first-time';

  static final storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Reads [key], or '' when the store can't be read. On an Android phone
  /// restored from a backup the encrypted store's Keystore key is gone, so
  /// every read threw (and chat broke): the store is wiped then, and starts
  /// over empty (the chat signs in again on its own).
  static Future<String> _read(String key) async {
    try {
      return await storage.read(key: key) ?? '';
    } catch (e) {
      await _heal(e);
      return '';
    }
  }

  static Future<void> _write(String key, String value) async {
    try {
      await storage.write(key: key, value: value);
    } catch (e) {
      await _heal(e);
      try {
        await storage.write(key: key, value: value);
      } catch (_) {
        // Still unusable: the chat works without it this run.
      }
    }
  }

  static Future<void> _heal(Object error) async {
    _ChatLogger.failure('Secure storage unreadable, wiping it: $error');
    try {
      await storage.deleteAll();
    } catch (_) {
      // Nothing more to do here.
    }
  }

  static Future<String> getBaseUrl() async {
    return _read(baseUrl);
  }

  static Future<void> setBaseUrl(String value) async {
    await _write(baseUrl, value);
  }

  static Future<String> getUserUuid() async {
    return _read(userUuid);
  }

  static Future<void> setUserUuid(String value) async {
    if (value.isNotEmpty) await _write(userUuid, value);
  }

  static Future<String> getXApp() async {
    return _read(xApp);
  }

  static Future<void> setXApp(String value) async {
    await _write(xApp, value);
  }

  static Future<String> getDeviceId() async {
    return _read(deviceId);
  }

  static Future<void> setDeviceId(String value) async {
    await _write(deviceId, value);
  }

  static Future<String> getDeviceName() async {
    return _read(deviceName);
  }

  static Future<void> setDeviceName(String value) async {
    await _write(deviceName, value);
  }

  static Future<String> getDeviceType() async {
    return _read(deviceType);
  }

  static Future<void> setLang(String value) async {
    await _write(lang, value);
  }

  static Future<String> getLang() async {
    return _read(lang);
  }

  static Future<void> setFirstTime(String value) async {
    final first = await getFirstTime();
    if (first.isNotEmpty) return;

    await _write(firstTime, value);
  }

  static Future<String> getFirstTime() async {
    return _read(firstTime);
  }

  static Future<void> setDeviceType(String value) async {
    await _write(deviceType, value);
  }

  //TODO (change if version change)
  static int get versionCode => 8;

  //TODO (change if version change)
  static String get versionName => '1.0.8';

  static Future<void> deleteAllData() async {
    try {
      await storage.delete(key: userUuid);
      await storage.delete(key: deviceType);
      await storage.delete(key: deviceName);
      await storage.delete(key: deviceId);
      await storage.delete(key: messageKeyList);
    } catch (e) {
      // Unreadable store (see [_read]): wiped whole instead.
      await _heal(e);
    }
  }
}
