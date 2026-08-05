import 'dart:async';

import 'package:database_client/database_client.dart';
import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

/// {@template chats_repository}
/// A repository that manages the chats data data flow.
/// {@endtemplate}
class ChatsRepository implements ChatsBaseRepository {
  /// {@macro chats_repository}
  const ChatsRepository({required DatabaseClient databaseClient})
    : _databaseClient = databaseClient;

  final DatabaseClient _databaseClient;

  /// Watches the conversation's messages via PowerSync and invokes [callback]
  /// with each per-row change (new/old record), so the UI updates in real time
  /// without rebuilding the whole list. Cancel the subscription to stop.
  StreamSubscription<void> messagesUpdates({
    required String conversationId,
    required ValueSetter<
      ({Map<String, dynamic> newRecord, Map<String, dynamic> oldRecord})
    >
    callback,
  }) {
    return _databaseClient.onMessagesUpdates(
      conversationId: conversationId,
      callback: callback,
    );
  }

  @override
  Future<Message?> getRepliedMessage({required String messageId}) =>
      _databaseClient.getRepliedMessage(messageId: messageId);

  @override
  Future<List<Message>> getMessages({
    required String chatId,
    required int limit,
    required int offset,
  }) =>
      _databaseClient.getMessages(chatId: chatId, limit: limit, offset: offset);

  @override
  Stream<List<ChatInbox>> chatsOf({required String userId}) =>
      _databaseClient.chatsOf(userId: userId);

  @override
  Stream<int> unreadMessagesCount({required String userId}) =>
      _databaseClient.unreadMessagesCount(userId: userId);

  @override
  Stream<List<Message>> messagesOf({required String chatId}) =>
      _databaseClient.messagesOf(chatId: chatId);

  @override
  Future<String> createChat({
    required String userId,
    required String participantId,
  }) =>
      _databaseClient.createChat(userId: userId, participantId: participantId);

  @override
  Future<void> deleteChat({required String chatId, required String userId}) =>
      _databaseClient.deleteChat(chatId: chatId, userId: userId);

  @override
  Future<void> deleteMessage({required String messageId}) =>
      _databaseClient.deleteMessage(messageId: messageId);

  @override
  Future<void> readMessage({
    required String messageId,
  }) => _databaseClient.readMessage(messageId: messageId);

  @override
  Future<void> markConversationRead({
    required String chatId,
    required String userId,
  }) => _databaseClient.markConversationRead(chatId: chatId, userId: userId);

  @override
  Stream<DateTime?> otherReadAtOf({
    required String conversationId,
    required String excludeUserId,
  }) => _databaseClient.otherReadAtOf(
    conversationId: conversationId,
    excludeUserId: excludeUserId,
  );

  @override
  Future<void> setTyping({
    required String conversationId,
    required String userId,
  }) => _databaseClient.setTyping(
    conversationId: conversationId,
    userId: userId,
  );

  @override
  Stream<DateTime?> typingUpdatedAtOf({
    required String conversationId,
    required String excludeUserId,
  }) => _databaseClient.typingUpdatedAtOf(
    conversationId: conversationId,
    excludeUserId: excludeUserId,
  );

  @override
  Future<void> sendMessage({
    required String chatId,
    required User sender,
    required User receiver,
    required Message message,
    PostAuthor? postAuthor,
  }) => _databaseClient.sendMessage(
    chatId: chatId,
    sender: sender,
    receiver: receiver,
    message: message,
    postAuthor: postAuthor,
  );

  @override
  Future<void> editMessage({
    required Message oldMessage,
    required Message newMessage,
  }) => _databaseClient.editMessage(
    oldMessage: oldMessage,
    newMessage: newMessage,
  );
}
