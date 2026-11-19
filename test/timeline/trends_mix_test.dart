import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/timeline/timeline.dart';

PostSmallBlock _post(String id, String author) => PostSmallBlock(
  id: id,
  author: PostAuthor(id: author, avatarUrl: '', username: author),
  createdAt: DateTime(2026),
  media: const [],
  caption: '',
);

/// [authors] as posts, one each, numbered from [from]: 'ab' → a-0, b-1.
List<PostBlock> _page(String authors, {int from = 0}) => [
  for (final (i, author) in authors.split('').indexed)
    _post('$author-${from + i}', author),
];

/// How many times the same person's posts come one after another.
int _pairs(List<PostBlock> posts) {
  var pairs = 0;
  for (var i = 1; i < posts.length; i++) {
    if (posts[i].author.id == posts[i - 1].author.id) pairs++;
  }
  return pairs;
}

/// The fewest such pairs any order of [posts] can have.
int _fewestPairs(List<PostBlock> posts) {
  final counts = <String, int>{};
  for (final post in posts) {
    counts[post.author.id] = (counts[post.author.id] ?? 0) + 1;
  }
  // Greedy is optimal for "no two alike in a row": always the most left that
  // differs from the one before.
  var pairs = 0;
  String? before;
  for (var n = posts.length; n > 0; n--) {
    final options = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final pick = options.firstWhere(
      (e) => e.key != before,
      orElse: () => options.first,
    );
    if (pick.key == before) pairs++;
    counts[pick.key] = pick.value - 1;
    before = pick.key;
  }
  return pairs;
}

/// Trends' Maps tab's order: recommendations, the same person's posts never
/// one after another while someone else's can come between.
void main() {
  test('one person with three of five: never two in a row', () {
    for (var seed = 0; seed < 50; seed++) {
      final mix = TrendsMix(random: math.Random(seed));
      final order = mix.order(_page('aaabc'));
      expect(
        _pairs(order),
        0,
        reason:
            'seed $seed: ${[for (final post in order) post.author.id].join()}',
      );
    }
  });

  test('any page: none in a row where none need be', () {
    final dice = math.Random(42);
    for (var round = 0; round < 400; round++) {
      final people = 'abcdef'.substring(0, 1 + dice.nextInt(6));
      final page = String.fromCharCodes([
        for (var i = 0; i < 1 + dice.nextInt(24); i++)
          people.codeUnitAt(
            // Skewed: the first people post the most.
            math.min(dice.nextInt(people.length), dice.nextInt(people.length)),
          ),
      ]);
      final posts = _page(page);
      final order = TrendsMix(random: math.Random(round)).order(posts);
      expect(order.toSet(), posts.toSet());
      if (_fewestPairs(posts) == 0) expect(_pairs(order), 0, reason: page);
    }
  });

  test('the posts already placed keep their places; new ones after', () {
    final mix = TrendsMix(random: math.Random(1));
    final first = mix.order(_page('abcab'));
    final next = mix.order([..._page('abcab'), ..._page('ccd', from: 5)]);
    List<String> ids(Iterable<PostBlock> posts) => [
      for (final post in posts) post.id,
    ];
    expect(ids(next.take(5)), ids(first));
    expect(next.skip(5).map((post) => post.id).toSet(), {'c-5', 'c-6', 'd-7'});
  });

  test('a post gone from Trends drops out, the rest as they were', () {
    final mix = TrendsMix(random: math.Random(3));
    final posts = _page('abcde');
    final first = mix.order(posts);
    final gone = first[2];
    final after = mix.order([...posts]..remove(gone));
    expect(after, [...first]..remove(gone));
  });
}
