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
    iOptions: const IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static Future<String> getBaseUrl() async {
    final value = await storage.read(key: baseUrl);
    return value ?? '';
  }

  static Future<void> setBaseUrl(String value) async {
    await storage.write(key: baseUrl, value: value);
  }

  static Future<void> setMessageKeyList(List<String> values) async {
    final encoded = jsonEncode(values);
    await storage.write(key: messageKeyList, value: encoded);
  }

  static Future<List<String>> getMessageKeyList() async {
    final value = await storage.read(key: messageKeyList);
    if (value == null) return [];
    return List<String>.from(jsonDecode(value));
  }

  static Future<String> getUserUuid() async {
    final value = await storage.read(key: userUuid);
    return value ?? '';
  }

  static Future<void> setUserUuid(String value) async {
    if (value.isNotEmpty) await storage.write(key: userUuid, value: value);
  }

  static Future<String> getXApp() async {
    final value = await storage.read(key: xApp);
    return value ?? '';
  }

  static Future<void> setXApp(String value) async {
    await storage.write(key: xApp, value: value);
  }

  static Future<String> getDeviceId() async {
    final value = await storage.read(key: deviceId);
    return value ?? '';
  }

  static Future<void> setDeviceId(String value) async {
    await storage.write(key: deviceId, value: value);
  }

  static Future<String> getDeviceName() async {
    final value = await storage.read(key: deviceName);
    return value ?? '';
  }

  static Future<void> setDeviceName(String value) async {
    await storage.write(key: deviceName, value: value);
  }

  static Future<String> getDeviceType() async {
    final value = await storage.read(key: deviceType);
    return value ?? '';
  }

  static Future<void> setLang(String value) async {
    await storage.write(key: lang, value: value);
  }

  static Future<String> getLang() async {
    final value = await storage.read(key: lang);
    return value ?? '';
  }

  static Future<void> setFirstTime(String value) async {
    final first = await getFirstTime();
    if (first.isNotEmpty) return;

    await storage.write(key: firstTime, value: value);
  }

  static Future<String> getFirstTime() async {
    final value = await storage.read(key: firstTime);

    return value ?? '';
  }

  static Future<void> setDeviceType(String value) async {
    await storage.write(key: deviceType, value: value);
  }

  //TODO (change if version change)
  static int get versionCode => 8;

  //TODO (change if version change)
  static String get versionName => '1.0.8';


  static Future<void> deleteAllData() async {
    await storage.delete(key: userUuid);
    await storage.delete(key: deviceType);
    await storage.delete(key: deviceName);
    await storage.delete(key: deviceId);
    await storage.delete(key: messageKeyList);
  }
}
