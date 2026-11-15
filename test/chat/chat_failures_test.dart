import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/chat/backend/dm_api.dart';
import 'package:treepnet/chat/chat_failures.dart';

void main() {
  final sent = <({Object error, String kind})>[];
  var clock = DateTime(2026, 11, 15, 12);

  setUp(() {
    sent.clear();
    clock = DateTime(2026, 11, 15, 12);
    ChatFailures.reset();
    ChatFailures.sink = (error, _, kind) =>
        sent.add((error: error, kind: kind));
    ChatFailures.now = () => clock;
  });

  test('a failure goes out as its kind, with the cause', () {
    ChatFailures.report('inbox', StateError('500'));
    expect(sent.single.kind, 'chat-inbox');
    expect(sent.single.error.toString(), contains('Chat inbox failed'));
    expect(sent.single.error.toString(), contains('500'));
  });

  test('offline and timeouts are expected, not reported', () {
    ChatFailures.report('inbox', const SocketException('no network'));
    ChatFailures.report('history', TimeoutException('slow'));
    expect(sent, isEmpty);
  });

  test('one report per kind every 10 minutes', () {
    ChatFailures.report('inbox', StateError('a'));
    ChatFailures.report('inbox', StateError('b'));
    ChatFailures.report('history', StateError('c'));
    expect(sent.map((s) => s.kind), ['chat-inbox', 'chat-history']);

    clock = clock.add(const Duration(minutes: 9));
    ChatFailures.report('inbox', StateError('d'));
    expect(sent, hasLength(2));

    clock = clock.add(const Duration(minutes: 1));
    ChatFailures.report('inbox', StateError('e'));
    expect(sent, hasLength(3));
  });

  test('watch reports a failed load and passes it on', () async {
    await expectLater(
      ChatFailures.watch<int>('inbox', () async => throw StateError('boom')),
      throwsStateError,
    );
    expect(sent.single.kind, 'chat-inbox');
    expect(await ChatFailures.watch('inbox', () async => 7), 7);
    expect(sent, hasLength(1));
  });

  test('a block or sending too fast is not a fault', () {
    DmSendResult answer(Map<String, dynamic> ack) => DmSendResult.fromAck(ack);
    expect(
      answer({'status': 'error', 'error': 'Blocked', 'code': 'BLOCKED'})
          .isExpectedRefusal,
      isTrue,
    );
    expect(
      answer({'status': 'error', 'error': 'rate limit exceeded'})
          .isExpectedRefusal,
      isTrue,
    );
    expect(
      answer({'status': 'error', 'error': 'server error'}).isExpectedRefusal,
      isFalse,
    );
  });
}
