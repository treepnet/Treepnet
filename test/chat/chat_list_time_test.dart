import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/chat/chat_inbox_page.dart';

void main() {
  // Local times: the inbox reads the phone's clock.
  final now = DateTime(2026, 11, 15, 12);
  String at(DateTime local) =>
      chatListTime(local.toUtc(), yesterday: 'Yesterday', now: now);

  test('today shows the time', () {
    expect(at(DateTime(2026, 11, 15, 9, 5)), '09:05');
  });

  test('yesterday says so, even just after midnight', () {
    expect(at(DateTime(2026, 11, 14, 23, 59)), 'Yesterday');
    expect(at(DateTime(2026, 11, 14, 0, 1)), 'Yesterday');
  });

  test('earlier this year is day and month', () {
    expect(at(DateTime(2026, 11, 13, 10)), '13.11');
  });

  test('another year carries the year', () {
    expect(at(DateTime(2025, 11, 13, 10)), '13.11.25');
  });

  test('yesterday across a month and a year boundary', () {
    final jan1 = DateTime(2027, 1, 1, 8);
    expect(
      chatListTime(
        DateTime(2026, 12, 31, 22).toUtc(),
        yesterday: 'Yesterday',
        now: jan1,
      ),
      'Yesterday',
    );
  });
}
