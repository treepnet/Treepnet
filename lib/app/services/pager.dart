import 'package:flutter/foundation.dart';

/// A list fetched [pageSize] at a time — [fetch] with an offset and a limit —
/// for a screen that loads more as it is scrolled to the end ([loadMore]).
/// The saved posts and a post's likers used to stop at a fixed 80 and 100.
class Pager<T> extends ChangeNotifier {
  Pager({required this.fetch, required this.idOf, this.pageSize = 30});

  final Future<List<T>> Function(int offset, int limit) fetch;

  /// What tells two items apart (a page that shifted repeats one).
  final String Function(T item) idOf;

  final int pageSize;

  final List<T> _items = [];
  final Set<String> _ids = {};

  /// Where the next page starts in the server's list.
  int _offset = 0;

  /// Bumped by [refresh], so a page asked for before it is dropped.
  int _generation = 0;

  List<T> get items => List.unmodifiable(_items);

  /// The first page hasn't come yet.
  bool loading = true;

  bool loadingMore = false;

  /// The last page was full: there may be more.
  bool hasMore = true;

  /// From the first page — the list then shows what it can't load.
  Object? error;

  /// Starts again from the first page.
  Future<void> refresh() async {
    final generation = ++_generation;
    loadingMore = false;
    try {
      final page = await fetch(0, pageSize);
      if (generation != _generation) return;
      _items.clear();
      _ids.clear();
      _offset = 0;
      _add(page);
      error = null;
    } catch (e) {
      if (generation != _generation) return;
      error = e;
    }
    loading = false;
    notifyListeners();
  }

  /// The next page, unless one is on its way or there is no more.
  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    final generation = _generation;
    loadingMore = true;
    notifyListeners();
    try {
      final page = await fetch(_offset, pageSize);
      if (generation != _generation) return;
      _add(page);
    } catch (_) {
      // The next scroll to the end tries again.
    }
    if (generation != _generation) return;
    loadingMore = false;
    notifyListeners();
  }

  /// [id] left the list elsewhere (a post unsaved): it goes, and the next
  /// page starts one earlier, as the server's list now does.
  void remove(String id) {
    if (!_ids.remove(id)) return;
    _items.removeWhere((item) => idOf(item) == id);
    if (_offset > 0) _offset--;
    notifyListeners();
  }

  /// Whether [id] is in the list.
  bool contains(String id) => _ids.contains(id);

  void _add(List<T> page) {
    _offset += page.length;
    hasMore = page.length >= pageSize;
    for (final item in page) {
      if (_ids.add(idOf(item))) _items.add(item);
    }
  }
}
