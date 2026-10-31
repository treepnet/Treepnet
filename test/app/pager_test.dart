import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/app/services/pager.dart';

void main() {
  /// A server list of [count] items, `0`, `1`, …; records each request.
  ({Pager<String> pager, List<(int, int)> asked}) pagerOver(
    List<String> list, {
    int pageSize = 3,
  }) {
    final asked = <(int, int)>[];
    final pager = Pager<String>(
      fetch: (offset, limit) async {
        asked.add((offset, limit));
        return list.skip(offset).take(limit).toList();
      },
      idOf: (item) => item,
      pageSize: pageSize,
    );
    return (pager: pager, asked: asked);
  }

  test('loads a page at a time until a short one', () async {
    final (:pager, :asked) = pagerOver(['a', 'b', 'c', 'd', 'e']);
    expect(pager.loading, isTrue);
    await pager.refresh();
    expect(pager.items, ['a', 'b', 'c']);
    expect(pager.hasMore, isTrue);
    await pager.loadMore();
    expect(pager.items, ['a', 'b', 'c', 'd', 'e']);
    expect(pager.hasMore, isFalse);
    await pager.loadMore();
    expect(asked, [(0, 3), (3, 3)]);
  });

  test('a removed item steps the next page back', () async {
    final list = ['a', 'b', 'c', 'd', 'e'];
    final (:pager, :asked) = pagerOver(list);
    await pager.refresh();
    // "b" unsaved: gone here and from the server's list.
    list.remove('b');
    pager.remove('b');
    expect(pager.items, ['a', 'c']);
    await pager.loadMore();
    expect(asked.last, (2, 3));
    expect(pager.items, ['a', 'c', 'd', 'e']);
  });

  test('an item a shifted page repeats is shown once', () async {
    final list = ['a', 'b', 'c', 'd'];
    final pager = pagerOver(list).pager;
    await pager.refresh();
    // A new one at the top pushes "c" onto the next page.
    list.insert(0, 'z');
    await pager.loadMore();
    expect(pager.items, ['a', 'b', 'c', 'd']);
  });

  test('refresh starts over', () async {
    final list = ['a', 'b', 'c', 'd'];
    final pager = pagerOver(list).pager;
    await pager.refresh();
    await pager.loadMore();
    list.insert(0, 'z');
    await pager.refresh();
    expect(pager.items, ['z', 'a', 'b']);
    expect(pager.hasMore, isTrue);
  });
}
