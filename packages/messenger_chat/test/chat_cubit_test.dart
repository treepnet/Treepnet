import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_chat/messenger_chat.dart';

/// A transport the test drives: events go out when the test says, history is
/// whatever the test sets.
class _FakeTransport implements ChatTransport {
  final _events = StreamController<ChatTransportEvent>.broadcast();
  List<ChatIncomingMessage> history = const [];

  void emit(ChatTransportEvent event) => _events.add(event);

  @override
  Future<void> connect() async {}

  @override
  Future<ChatHistoryPage> loadHistory({
    required int page,
    required int size,
  }) async => ChatHistoryPage(messages: history, hasMore: false);

  @override
  Future<ChatHistoryPage?> cachedHistory() async => null;

  @override
  Future<void> send(ChatOutgoingMessage message) async {}

  @override
  Future<void> sendTyping({required bool isTyping, ChatMessageKind? kind}) async {}

  @override
  Future<void> markRead({String? messageId}) async {}

  @override
  Future<void> editMessage({
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage({required String messageId}) async {}

  @override
  Stream<ChatTransportEvent> get events => _events.stream;

  @override
  Future<void> dispose() async => _events.close();
}

const _me = ChatUser(id: 'me', name: 'Me');
const _peer = 'peer';

ChatIncomingMessage _msg(
  String id, {
  String from = _peer,
  String text = 'hi',
  String? key,
  bool isRead = false,
  bool isEdited = false,
}) => ChatIncomingMessage(
  id: id,
  senderId: from,
  kind: ChatMessageKind.text,
  content: text,
  sentAt: DateTime(2026, 11, 15, 12),
  clientKey: key,
  isRead: isRead,
  isEdited: isEdited,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTransport transport;
  late ChatCubit cubit;

  /// The thread's messages, newest first, as id → text.
  List<(String, String)> shown() => [
    for (final dynamic m in cubit.state.messages.messages)
      (m.id as String, m.content.content as String),
  ];

  setUp(() async {
    transport = _FakeTransport();
    await MessengerChat.init(transport: transport, me: _me);
    cubit = ChatCubit(ChatRepositoryImpl());
    await MessengerChat.connectTransport(cubit: cubit);
  });

  tearDown(() async {
    await MessengerChat.release();
    await cubit.close();
  });

  Future<void> settle() => pumpEventQueue();

  test('a received message is added once, however often it comes', () async {
    transport.emit(ChatMessageReceived(_msg('1')));
    await settle();
    transport.emit(ChatMessageReceived(_msg('1')));
    await settle();
    expect(shown(), [('1', 'hi')]);
  });

  test('newest first', () async {
    transport
      ..emit(ChatMessageReceived(_msg('1', text: 'first')))
      ..emit(ChatMessageReceived(_msg('2', text: 'second')));
    await settle();
    expect(shown(), [('2', 'second'), ('1', 'first')]);
  });

  test('an edit replaces the message in its place', () async {
    transport
      ..emit(ChatMessageReceived(_msg('1', text: 'old', key: 'k1')))
      ..emit(ChatMessageReceived(_msg('2', text: 'next')));
    await settle();
    transport.emit(
      ChatMessageUpdated(_msg('1', text: 'new', key: 'k1', isEdited: true)),
    );
    await settle();
    expect(shown(), [('2', 'next'), ('1', 'new')]);
  });

  test('my own message coming back replaces its copy, not added twice', () async {
    transport.emit(ChatMessageReceived(_msg('1', from: 'me', key: 'k1')));
    await settle();
    transport.emit(
      ChatMessageReceived(_msg('1', from: 'me', key: 'k1', text: 'hi!')),
    );
    await settle();
    expect(shown(), [('1', 'hi!')]);
  });

  test('read: all of mine become read', () async {
    transport
      ..emit(ChatMessageReceived(_msg('1', from: 'me', key: 'k1')))
      ..emit(ChatMessageReceived(_msg('2', from: 'me', key: 'k2')));
    await settle();
    transport.emit(const ChatMessagesRead(all: true));
    await settle();
    expect(
      [for (final dynamic m in cubit.state.messages.messages) m.isRead],
      [true, true],
    );
  });

  test('read: one message by its id', () async {
    transport
      ..emit(ChatMessageReceived(_msg('1', from: 'me', key: 'k1')))
      ..emit(ChatMessageReceived(_msg('2', from: 'me', key: 'k2')));
    await settle();
    transport.emit(const ChatMessagesRead(messageId: '1'));
    await settle();
    expect(
      {
        for (final dynamic m in cubit.state.messages.messages)
          m.id as String: m.isRead as bool,
      },
      {'1': true, '2': false},
    );
  });

  test('back online: new messages on top, the shown ones kept', () async {
    transport
      ..emit(ChatMessageReceived(_msg('1', text: 'one')))
      ..emit(ChatMessageReceived(_msg('2', text: 'two')));
    await settle();
    // Newest first, as the server pages: 3 arrived while away, 2 meets.
    transport.history = [
      _msg('3', text: 'three'),
      _msg('2', text: 'two'),
    ];
    await cubit.getMessagesWhenOnline();
    await settle();
    expect(shown(), [('3', 'three'), ('2', 'two'), ('1', 'one')]);
  });
}
