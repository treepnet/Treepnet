import 'dart:async';

import 'package:collection/collection.dart';
import 'package:database_client/database_client.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared/shared.dart' show Story;

/// Every active story the viewer may see, grouped by author, from ONE live
/// query shared by every story ring in the app.
///
/// Each avatar with a story ring (post cards, comments, chat, search, profile
/// lists, the stories tray) used to open its own live query for its author's
/// stories — even for people with no story — and the tray loaded every story
/// a second time. Active stories are few (they last 24 hours), so one query
/// for all of them is cheap, and each ring picks its author's from it.
///
/// The query is open while anything listens and closes after the last
/// listener leaves. A story drops out when its 24 hours are up, on time: the
/// query itself only re-runs when a table changes, so a timer re-filters at
/// the next expiry.
class ActiveStories {
  /// Reads through [databaseClient].
  ActiveStories(DatabaseClient databaseClient)
    : _byAuthor = databaseClient
          .activeStories()
          .switchMap(_untilExpired)
          .publishReplay(maxSize: 1)
          .refCount();

  final Stream<Map<String, List<Story>>> _byAuthor;

  /// The active stories of [authorId], oldest first; emits only when they
  /// change.
  Stream<List<Story>> of(String authorId) => _byAuthor
      .map((byAuthor) => byAuthor[authorId] ?? const <Story>[])
      .distinct(const ListEquality<Story>().equals);

  /// [stories] grouped by author, re-emitted without each one as it expires.
  static Stream<Map<String, List<Story>>> _untilExpired(List<Story> stories) {
    Timer? timer;
    late final StreamController<Map<String, List<Story>>> controller;

    void emitLive() {
      final now = DateTime.now();
      final byAuthor = <String, List<Story>>{};
      DateTime? nextExpiry;
      for (final story in stories) {
        if (!story.expiresAt.isAfter(now)) continue;
        (byAuthor[story.author.id] ??= []).add(story);
        if (nextExpiry == null || story.expiresAt.isBefore(nextExpiry)) {
          nextExpiry = story.expiresAt;
        }
      }
      controller.add(byAuthor);
      if (nextExpiry != null) {
        timer = Timer(
          nextExpiry.difference(now) + const Duration(seconds: 1),
          emitLive,
        );
      }
    }

    controller = StreamController<Map<String, List<Story>>>(
      onListen: emitLive,
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }
}
