// ignore_for_file: prefer_constructors_over_static_methods

import 'package:database_client/database_client.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

/// {@template search_repository}
/// A package that manages search result data flow.
/// {@endtemplate}
class SearchRepository {
  /// {@macro search_repository}
  SearchRepository({required DatabaseClient databaseClient})
    : _databaseClient = databaseClient;

  final DatabaseClient _databaseClient;

  /// Cache of SUCCESSFUL, NON-EMPTY results keyed by (query, limit, offset).
  ///
  /// Empty and failed results are deliberately NOT cached. The old cache stored
  /// the result (including empties and errors) forever: a search run before the
  /// matching profiles had synced locally — or one that errored — poisoned that
  /// key with an empty list for the whole session, so the same query kept
  /// coming back empty. That is why some users (e.g. a specific handle) were
  /// findable on one search screen but not another: the two screens populate
  /// slightly different cache keys (one trims the query, one debounces
  /// differently), so a poisoned-empty entry on one key survived next to a good
  /// entry on the other. Not caching empties lets a later search re-query once
  /// the data is there.
  final _usersHashedQueryResults = <String, List<User>>{};

  /// Searches users by handle / name. Caches only non-empty successful results.
  Future<List<User>> searchUsers({
    required String query,
    int limit = 8,
    int offset = 0,
    String? excludeUserIds,
  }) async {
    if (query.trim().isEmpty) return <User>[];

    final hash = generateHash([query, limit, offset]);
    final cached = _usersHashedQueryResults[hash];
    if (cached != null) return cached;

    try {
      final users = await _databaseClient.searchUsers(
        limit: limit,
        offset: offset,
        query: query,
      );
      if (users.isNotEmpty) _usersHashedQueryResults[hash] = users;
      return users;
    } catch (_) {
      // Don't cache a failure — let the next search try again.
      return <User>[];
    }
  }
}
