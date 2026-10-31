part of messenger_chat;

/// The offline queue ("outbox") is gone. It saved unsent messages without the
/// conversation they belonged to and re-sent them, after a reconnect or a
/// restart, through whichever chat was open next — to the wrong person. A
/// message that doesn't reach the server now stays in its own chat marked
/// failed, with Retry / Delete.
///
/// This only deletes the queue an older version left on the phone, so nothing
/// in it is ever sent. Runs once per app start.
Future<void> _removeLegacyOutbox() => _legacyOutboxRemoval ??= () async {
  try {
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
    }
    await Hive.deleteBoxFromDisk('crm_outbox');
    // Also an old version's list of every sent message's key, rewritten in
    // the keychain on each message and never used.
    await _SecureStorage.storage.delete(key: _SecureStorage.messageKeyList);
  } catch (e) {
    _ChatLogger.failure('Old outbox not removed: $e');
  }
}();

Future<void>? _legacyOutboxRemoval;
