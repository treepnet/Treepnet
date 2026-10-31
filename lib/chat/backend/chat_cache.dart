import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// The chat as it was last seen, kept on the phone so it opens without a
/// connection: the inbox list, the unread count, our chat-backend id and the
/// latest messages of recently opened conversations.
///
/// Stored as the server's own JSON, in the app's private support directory,
/// one folder per account (`chat_cache/<profile id>/`). Only one account's
/// folder is ever kept: starting the chat for an account removes the others,
/// and signing out removes everything ([clear]) — one account's messages must
/// never show up for the next one signed in on this phone.
///
/// Best-effort throughout: a read that fails is treated as "nothing saved",
/// a write that fails is skipped.
class ChatCache {
  ChatCache._();

  static final ChatCache instance = ChatCache._();

  /// Messages kept per conversation, newest first.
  static const messagesPerConversation = 50;

  /// Conversations whose messages are kept; the least recently saved go first.
  static const conversationsKept = 10;

  /// Root folder, overridable in tests.
  @visibleForTesting
  Future<Directory> Function() rootDirectory = () async =>
      Directory('${(await getApplicationSupportDirectory()).path}/chat_cache');

  /// Writes to one file run one after another, never interleaved.
  final Map<String, Future<void>> _writes = {};

  /// Bumped by [clear], so a write started before a sign-out doesn't put the
  /// signed-out account's data back.
  int _generation = 0;

  Future<Directory> _accountDir(String uuid) async {
    // Profile ids are UUIDs; anything else must not walk out of the folder.
    final safe = uuid.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
    return Directory('${(await rootDirectory()).path}/$safe');
  }

  /// The chat is starting for [uuid]: every other account's data goes.
  Future<void> useAccount(String uuid) async {
    if (uuid.isEmpty) return;
    try {
      final root = await rootDirectory();
      if (!root.existsSync()) return;
      final keep = (await _accountDir(uuid)).path;
      for (final entry in root.listSync()) {
        if (entry.path != keep) await entry.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Signed out: nothing of the account stays.
  Future<void> clear() async {
    _generation++;
    try {
      // Let writes already under way finish, so none lands after the delete.
      await Future.wait(_writes.values);
      final root = await rootDirectory();
      if (root.existsSync()) await root.delete(recursive: true);
    } catch (_) {}
  }

  /// The inbox as last loaded for [uuid], or null.
  Future<ChatInboxSnapshot?> readInbox(String uuid) async {
    final json = await _read(File('${(await _accountDir(uuid)).path}/inbox'));
    if (json is! Map) return null;
    final conversations = json['conversations'];
    return ChatInboxSnapshot(
      myUserId: json['myUserId']?.toString() ?? '',
      conversations: conversations is List
          ? conversations.whereType<Map<dynamic, dynamic>>().toList()
          : const [],
      unread: (json['unread'] as num?)?.toInt() ?? 0,
    );
  }

  /// Saves the inbox. A null [conversations] keeps the saved ones (only the
  /// unread count or our id changed).
  Future<void> writeInbox(
    String uuid, {
    required String myUserId,
    required int unread,
    List<Map<dynamic, dynamic>>? conversations,
  }) async {
    final file = File('${(await _accountDir(uuid)).path}/inbox');
    await _queue(file.path, () async {
      final saved = conversations == null ? await _read(file) : null;
      await _write(file, {
        'myUserId': myUserId,
        'unread': unread,
        'conversations':
            conversations ??
            (saved is Map ? saved['conversations'] : null) ??
            const <Object?>[],
      });
    });
  }

  /// The latest saved messages of [conversationId] (newest first), or null.
  Future<List<Map<dynamic, dynamic>>?> readMessages(
    String uuid,
    String conversationId,
  ) async {
    final json = await _read(await _messagesFile(uuid, conversationId));
    if (json is! List) return null;
    return json.whereType<Map<dynamic, dynamic>>().toList();
  }

  /// Saves [messages] (newest first) as [conversationId]'s latest ones.
  Future<void> writeMessages(
    String uuid,
    String conversationId,
    List<Map<dynamic, dynamic>> messages,
  ) async {
    final file = await _messagesFile(uuid, conversationId);
    await _queue(file.path, () async {
      await _write(file, messages.take(messagesPerConversation).toList());
      await _pruneConversations(file.parent);
    });
  }

  /// Changes [conversationId]'s saved messages with [update] (no-op when
  /// nothing is saved for it yet).
  Future<void> updateMessages(
    String uuid,
    String conversationId,
    List<Map<dynamic, dynamic>> Function(List<Map<dynamic, dynamic>> saved)
    update,
  ) async {
    final file = await _messagesFile(uuid, conversationId);
    await _queue(file.path, () async {
      final saved = await _read(file);
      if (saved is! List) return;
      final next = update(saved.whereType<Map<dynamic, dynamic>>().toList());
      await _write(file, next.take(messagesPerConversation).toList());
    });
  }

  Future<File> _messagesFile(String uuid, String conversationId) async {
    final safe = conversationId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
    return File('${(await _accountDir(uuid)).path}/c_$safe');
  }

  /// Keeps the [conversationsKept] most recently saved conversations.
  Future<void> _pruneConversations(Directory dir) async {
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.uri.pathSegments.last.startsWith('c_'))
            .toList()
          ..sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );
    for (final old in files.skip(conversationsKept)) {
      await old.delete();
    }
  }

  Future<void> _queue(String path, Future<void> Function() write) {
    final generation = _generation;
    final previous = _writes[path] ?? Future<void>.value();
    final next = previous.then((_) async {
      if (generation != _generation) return;
      try {
        await write();
      } catch (_) {}
    });
    _writes[path] = next;
    unawaited(
      next.whenComplete(() {
        if (identical(_writes[path], next)) _writes.remove(path);
      }),
    );
    return next;
  }

  Future<Object?> _read(File file) async {
    try {
      if (!file.existsSync()) return null;
      return jsonDecode(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  /// Through a temporary file, so a crash mid-write never leaves half a file.
  Future<void> _write(File file, Object json) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(json), flush: true);
    await temp.rename(file.path);
  }
}

/// What [ChatCache.readInbox] returns.
class ChatInboxSnapshot {
  const ChatInboxSnapshot({
    required this.myUserId,
    required this.conversations,
    required this.unread,
  });

  /// Our chat-backend id (decides which side a message is drawn on).
  final String myUserId;

  /// The server's conversation objects, as the inbox last loaded them.
  final List<Map<dynamic, dynamic>> conversations;
  final int unread;
}
