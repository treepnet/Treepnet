import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/stories/story_date.dart';

void main() {
  test("a story's date is the phone's calendar day, not UTC's", () {
    // As a story's createdAt comes from the server.
    final at = DateTime.parse('2026-11-14 22:30:00Z');
    final local = at.toLocal();
    expect(
      storyShortDate(at),
      '${local.day}.${local.month.toString().padLeft(2, '0')}.${local.year}',
    );
  });

  test('day without a leading zero, month with one', () {
    expect(storyShortDate(DateTime(2026, 3, 5, 12)), '5.03.2026');
  });
}
