import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/chat/backend/chat_cache.dart';
import 'package:treepnet/chat/backend/dm_api.dart';

Map<String, Object?> _message(String id, {String? key, String text = 'hi'}) => {
  'id': id,
  'conversationId': 'c1',
  'senderId': '7',
  'content': text,
  'contentType': 'text',
  'key': key,
  'date': '2026-11-01T10:00:00.000Z',
};

void main() {
  late Directory root;
  final cache = ChatCache.instance;

  setUp(() {
    root = Directory.systemTemp.createTempSync('chat_cache_test');
    cache.rootDirectory = () async => Directory('${root.path}/chat_cache');
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('the inbox comes back; a count-only save keeps the list', () async {
    await cache.writeInbox(
      'me',
      myUserId: '42',
      unread: 3,
      conversations: [
        {'id': 'c1', 'unreadCount': 3},
      ],
    );
    await cache.writeInbox('me', myUserId: '42', unread: 1);

    final saved = await cache.readInbox('me');
    expect(saved!.myUserId, '42');
    expect(saved.unread, 1);
    expect(saved.conversations.single['id'], 'c1');
  });

  test("another account's chat goes when this one's starts", () async {
    await cache.writeInbox('alice', myUserId: '1', unread: 2);
    await cache.writeMessages('alice', 'c1', [_message('m1')]);
    await cache.writeInbox('bob', myUserId: '2', unread: 0);

    await cache.useAccount('bob');

    expect(await cache.readInbox('alice'), isNull);
    expect(await cache.readMessages('alice', 'c1'), isNull);
    expect(await cache.readInbox('bob'), isNotNull);
  });

  test('signing out removes everything, a late write included', () async {
    await cache.writeInbox('me', myUserId: '42', unread: 5);
    final late = cache.writeMessages('me', 'c1', [_message('m1')]);
    await cache.clear();
    await late;

    expect(await cache.readInbox('me'), isNull);
    expect(await cache.readMessages('me', 'c1'), isNull);
    expect(Directory('${root.path}/chat_cache').existsSync(), isFalse);
  });

  test('keeps the newest 50 messages, the 10 latest chats', () async {
    await cache.writeMessages('me', 'c0', [
      for (var i = 0; i < 80; i++) _message('m$i'),
    ]);
    expect((await cache.readMessages('me', 'c0'))!.length, 50);

    final dir = Directory('${root.path}/chat_cache/me');
    // c0 is the oldest, so it's the first to go.
    File('${dir.path}/c_c0').setLastModifiedSync(DateTime(2020));
    for (var i = 1; i <= 11; i++) {
      await cache.writeMessages('me', 'c$i', [_message('x$i')]);
    }
    final kept = dir
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((n) => n.startsWith('c_'))
        .toSet();
    expect(kept.length, 10);
    expect(kept.contains('c_c0'), isFalse);
  });

  test('a live message replaces its copy or goes on top', () async {
    await cache.writeMessages('me', 'c1', [
      _message('m2', key: 'k2'),
      _message('m1'),
    ]);
    await cache.updateMessages(
      'me',
      'c1',
      (saved) => [_message('m3'), ...saved],
    );
    await cache.updateMessages('me', 'c1', (saved) {
      final i = saved.indexWhere((m) => m['key'] == 'k2');
      return [...saved]..[i] = _message('m2', key: 'k2', text: 'edited');
    });

    final saved = await cache.readMessages('me', 'c1');
    expect([for (final m in saved!) m['id']], ['m3', 'm2', 'm1']);
    expect(saved[1]['content'], 'edited');
  });

  test('an odd account id cannot reach outside the cache folder', () async {
    await cache.writeInbox('../../escape', myUserId: '1', unread: 0);
    expect(File('${root.path}/inbox').existsSync(), isFalse);
    expect(await cache.readInbox('../../escape'), isNotNull);
  });

  test('a message survives the trip through the cache', () {
    final original = DmMessage.fromJson({
      ..._message('m1', key: 'k1'),
      'isEdited': true,
      'replyToId': 'm0',
      'replyToContent': 'earlier',
    });
    final back = DmMessage.fromJson(original.toJson());
    expect(back.id, 'm1');
    expect(back.key, 'k1');
    expect(back.isEdited, isTrue);
    expect(back.replyToContent, 'earlier');
    expect(back.date, original.date);
  });
}
