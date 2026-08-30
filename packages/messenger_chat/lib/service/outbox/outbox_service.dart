part of messenger_chat;

class _OutboxService {
  _OutboxService._();
  static final _OutboxService _instance = _OutboxService._();
  factory _OutboxService() => _instance;

  static const String boxName = 'crm_outbox';
  static Box? _box;

  Future<void> init() async {
    if (_box != null) return;
    try {
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        Hive.init(dir.path);
      }
      _box = await Hive.openBox(boxName);
      _ChatLogger.print('📦 Outbox initialized');
    } catch (e) {
      _ChatLogger.failure('❌ Outbox init error: $e');
    }
  }

  Future<void> addMessage(String key, Map<String, dynamic> data) async {
    await _box?.put(key, jsonEncode(data));
    _ChatLogger.print('📥 Message added to outbox: $key');
  }

  Future<void> removeMessage(String key) async {
    await _box?.delete(key);
    _ChatLogger.print('🗑️ Message removed from outbox: $key');
  }

  List<Map<String, dynamic>> getAll() {
    if (_box == null) return [];
    return _box!.values
        .map((v) => jsonDecode(v as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> clear() async {
    await _box?.clear();
  }

  bool get isEmpty => _box?.isEmpty ?? true;
}
