import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:database_client/database_client.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared/shared.dart';
import 'package:storage/storage.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:user_repository/user_repository.dart' show User;

part 'stories_storage.dart';

/// {@template stories_repository}
/// A repository that manages stories data flow.
/// {@endtemplate}
class StoriesRepository extends StoriesBaseRepository {
  /// {@macro stories_repository}
  const StoriesRepository({
    required DatabaseClient databaseClient,
    required StoriesStorage storage,
  }) : _databaseClient = databaseClient,
       _storage = storage;

  final DatabaseClient _databaseClient;
  final StoriesStorage _storage;

  @override
  Future<void> createStory({
    required User author,
    required StoryContentType contentType,
    required String contentUrl,
    String? id,
    int? duration,
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) => _databaseClient.createStory(
    id: id,
    author: author,
    contentType: contentType,
    contentUrl: contentUrl,
    duration: duration,
    locationName: locationName,
    locationLat: locationLat,
    locationLng: locationLng,
  );

  @override
  Future<String> uploadStoryMedia({
    required String storyId,
    required File imageFile,
    required Uint8List imageBytes,
  }) => _databaseClient.uploadStoryMedia(
    storyId: storyId,
    imageFile: imageFile,
    imageBytes: imageBytes,
  );

  @override
  Future<void> deleteStory({required String id}) =>
      _databaseClient.deleteStory(id: id);

  /// Records that [viewerId] has seen the story [storyId].
  Future<void> recordStoryView({
    required String storyId,
    required String viewerId,
  }) => _databaseClient.recordStoryView(storyId: storyId, viewerId: viewerId);

  /// Live count of viewers of [storyId].
  Stream<int> storyViewsCountOf({required String storyId}) =>
      _databaseClient.storyViewsCountOf(storyId: storyId);

  /// The people who have viewed [storyId] (author-only, per sync rules).
  Stream<List<User>> storyViewersOf({required String storyId}) =>
      _databaseClient.storyViewersOf(storyId: storyId);

  /// Toggles a like by [userId] on [storyId].
  Future<void> likeStory({required String storyId, required String userId}) =>
      _databaseClient.likeStory(storyId: storyId, userId: userId);

  /// Whether [userId] has liked [storyId].
  Stream<bool> isStoryLiked({
    required String storyId,
    required String userId,
  }) => _databaseClient.isStoryLiked(storyId: storyId, userId: userId);

  /// Live like count of [storyId].
  Stream<int> storyLikesCountOf({required String storyId}) =>
      _databaseClient.storyLikesCountOf(storyId: storyId);

  @override
  Stream<List<Story>> getStories({
    required String userId,
    bool includeAuthor = true,
  }) =>
      _databaseClient.getStories(userId: userId, includeAuthor: includeAuthor);

  /// Every story the user has posted, newest first — the Archive. Author only.
  /// A story appears here as soon as it is uploaded, not once it expires.
  Stream<List<Story>> archivedStoriesOf({required String userId}) =>
      _databaseClient.archivedStoriesOf(userId: userId);

  /// Broadcasts stories from database and local storage. Combines and merges
  /// into a single stories data flow.
  Stream<List<Story>> mergedStories({
    required String authorId,
    String? userId,
  }) => Rx.combineLatest2(
    getStories(userId: authorId, includeAuthor: false),
    _storage._seenStoriesStreamController,
    (dbStories, localStories) => _storage.mergeStories(
      dbStories,
      userId: _databaseClient.currentUserId,
      list2: localStories
          .firstWhereOrNull((seenStories) => seenStories.userId == userId)
          ?.stories,
    ),
  ).asBroadcastStream();

  /// Stories hand-pinned to one place on [userId]'s travel map.
  @override
  Stream<List<Story>> locationStoriesOf({
    required String userId,
    required String regionIso,
    double? lat,
    double? lng,
    double radiusDegrees = 0.02,
  }) => _databaseClient.locationStoriesOf(
    userId: userId,
    regionIso: regionIso,
    lat: lat,
    lng: lng,
    radiusDegrees: radiusDegrees,
  );

  /// Pins an archived story to a place. Doing it twice is a no-op.
  Future<void> pinStoryToLocation({
    required String userId,
    required String storyId,
    required String regionIso,
    double? lat,
    double? lng,
  }) => _databaseClient.pinStoryToLocation(
    userId: userId,
    storyId: storyId,
    regionIso: regionIso,
    lat: lat,
    lng: lng,
  );

  /// Takes a pinned story back off a place.
  Future<void> unpinStoryFromLocation({
    required String userId,
    required String storyId,
    required String regionIso,
    double? lat,
    double? lng,
  }) => _databaseClient.unpinStoryFromLocation(
    userId: userId,
    storyId: storyId,
    regionIso: regionIso,
    lat: lat,
    lng: lng,
  );

  /// One live feed per author in [authorIds], combined into a single stream —
  /// element `i` holds the stories of `authorIds[i]`.
  ///
  /// Emits again whenever ANY of them posts, has a story expire, or has one
  /// marked seen, which is what lets the stories grid re-sort itself instead of
  /// showing a snapshot taken when the tab opened.
  Stream<List<List<Story>>> mergedStoriesOfAll(List<String> authorIds) =>
      authorIds.isEmpty
      ? Stream.value(const [])
      : Rx.combineLatestList(
          authorIds.map((id) => mergedStories(authorId: id)),
        );

  /// Updates in-memory [story] as seen.
  Future<void> setUserStorySeen({
    required Story story,
    required String userId,
  }) => _storage.setUserStorySeen(story, userId);

  /// The user's story highlights, newest first.
  Stream<List<StoryHighlight>> storyHighlightsOf({required String userId}) =>
      _databaseClient.storyHighlightsOf(userId: userId);

  /// Stories inside a highlight, in playback order.
  Stream<List<Story>> highlightStoriesOf({required String highlightId}) =>
      _databaseClient.highlightStoriesOf(highlightId: highlightId);

  /// Creates a highlight from [storyIds]; the first story becomes the cover.
  Future<void> createStoryHighlight({
    required String userId,
    required String name,
    required List<String> storyIds,
    String? coverUrl,
  }) => _databaseClient.createStoryHighlight(
    userId: userId,
    name: name,
    storyIds: storyIds,
    coverUrl: coverUrl,
  );

  /// Removes a highlight and its items.
  Future<void> deleteStoryHighlight({required String highlightId}) =>
      _databaseClient.deleteStoryHighlight(highlightId: highlightId);

  /// Adds an existing story to an existing highlight.
  Future<void> addStoryToHighlight({
    required String highlightId,
    required String storyId,
  }) => _databaseClient.addStoryToHighlight(
    highlightId: highlightId,
    storyId: storyId,
  );

  /// Sets a story's own location so it shows on the owner's map at that place.
  Future<void> setStoryLocation({
    required String storyId,
    required double lat,
    required double lng,
    String? name,
  }) => _databaseClient.setStoryLocation(
    storyId: storyId,
    lat: lat,
    lng: lng,
    name: name,
  );

  /// Whether the story is pinned to any place or highlight.
  Future<bool> isStoryPinned({required String storyId}) =>
      _databaseClient.isStoryPinned(storyId: storyId);

  /// Unpins the story from every place and highlight (keeps the story).
  Future<void> unpinStoryEverywhere({required String storyId}) =>
      _databaseClient.unpinStoryEverywhere(storyId: storyId);
}
