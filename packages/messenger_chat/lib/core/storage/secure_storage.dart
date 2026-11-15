part of messenger_chat;

mixin _SecureStorage {
  static final String messageKeyList = 'messageKeyList';
  static final String userUuid = 'userUuid';
  static final String deviceId = 'device-id';
  static final String deviceName = 'device-name';
  static final String deviceType = 'device-type';

  static final storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// The store couldn't be read: on an Android phone restored from a backup
  /// its Keystore key is gone. Wiped, it starts over empty.
  static Future<void> _heal(Object error) async {
    _ChatLogger.failure('Secure storage unreadable, wiping it: $error');
    try {
      await storage.deleteAll();
    } catch (_) {
      // Nothing more to do here.
    }
  }

  static Future<void> deleteAllData() async {
    try {
      await storage.delete(key: userUuid);
      await storage.delete(key: deviceType);
      await storage.delete(key: deviceName);
      await storage.delete(key: deviceId);
      await storage.delete(key: messageKeyList);
    } catch (e) {
      // Unreadable store (see [_heal]): wiped whole instead.
      await _heal(e);
    }
  }
}
