import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/stories/bloc/story_ordering.dart';

/// A story posted [minutesAgo] minutes ago.
Story _story({required int minutesAgo, bool seen = false}) {
  final at = DateTime(2026, 7, 27, 12).subtract(Duration(minutes: minutesAgo));
  return Story(
    id: '$minutesAgo-$seen',
    contentUrl: '',
    createdAt: at,
    expiresAt: at.add(const Duration(hours: 24)),
    seen: seen,
  );
}

void main() {
  group('compareStoryAuthors', () {
    test('puts an author with unseen stories ahead of a fully seen one', () {
      final unseen = [_story(minutesAgo: 600)];
      final seen = [_story(minutesAgo: 1, seen: true)];
      // Ahead even though the seen one posted far more recently.
      expect(compareStoryAuthors(unseen, seen), lessThan(0));
      expect(compareStoryAuthors(seen, unseen), greaterThan(0));
    });

    test('orders two unseen authors newest first', () {
      final fresh = [_story(minutesAgo: 1)];
      final old = [_story(minutesAgo: 600)];
      expect(compareStoryAuthors(fresh, old), lessThan(0));
    });

    test('orders two fully seen authors newest first as well', () {
      final fresh = [_story(minutesAgo: 1, seen: true)];
      final old = [_story(minutesAgo: 600, seen: true)];
      expect(compareStoryAuthors(fresh, old), lessThan(0));
    });

    test('counts an author with one story left unseen as unseen', () {
      final partly = [
        _story(minutesAgo: 600, seen: true),
        _story(minutesAgo: 500),
      ];
      final allSeen = [_story(minutesAgo: 1, seen: true)];
      expect(compareStoryAuthors(partly, allSeen), lessThan(0));
    });

    test('ranks an author by their freshest story, not their oldest', () {
      final staleThenFresh = [
        _story(minutesAgo: 1000),
        _story(minutesAgo: 2),
      ];
      final single = [_story(minutesAgo: 10)];
      expect(compareStoryAuthors(staleThenFresh, single), lessThan(0));
    });

    test('sorts a whole grid the way the tab renders it', () {
      final feeds = <String, List<Story>>{
        'seen_fresh': [_story(minutesAgo: 2, seen: true)],
        'unseen_old': [_story(minutesAgo: 900)],
        'unseen_fresh': [_story(minutesAgo: 5)],
        'seen_old': [_story(minutesAgo: 1200, seen: true)],
      };
      final order = feeds.keys.toList()
        ..sort((a, b) => compareStoryAuthors(feeds[a]!, feeds[b]!));
      expect(order, [
        'unseen_fresh',
        'unseen_old',
        'seen_fresh',
        'seen_old',
      ]);
    });
  });

  group('newestStoryAt', () {
    test('is the latest createdAt in the list', () {
      final stories = [
        _story(minutesAgo: 300),
        _story(minutesAgo: 7),
        _story(minutesAgo: 90),
      ];
      expect(newestStoryAt(stories), DateTime(2026, 7, 27, 11, 53));
    });
  });
}
