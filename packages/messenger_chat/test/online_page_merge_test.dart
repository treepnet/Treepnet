import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_chat/platform/presantation/cubit/online_page_merge.dart';

typedef _M = ({String id, String key});

_M _m(String id, [String key = '']) => (id: id, key: key);

({List<_M> messages, bool gap}) _merge(List<_M> current, List<_M> page) =>
    mergeOnlinePage<_M>(
      current: current,
      page: page,
      idOf: (m) => m.id,
      keyOf: (m) => m.key,
    );

List<String> _ids(List<_M> messages) => [for (final m in messages) m.id];

/// What a thread shows after it reconnects (messages newest first).
void main() {
  test('new messages that meet the shown ones go on top', () {
    final r = _merge(
      [_m('3'), _m('2'), _m('1')],
      [_m('5'), _m('4'), _m('3'), _m('2')],
    );
    expect(r.gap, isFalse);
    expect(_ids(r.messages), ['5', '4', '3', '2', '1']);
  });

  test('a page that doesn\'t meet the shown ones replaces them: no hole', () {
    // 30 arrived while away: the newest page (25) starts above message 3.
    final page = [for (var i = 33; i >= 9; i--) _m('$i')];
    final r = _merge([_m('3'), _m('2'), _m('1')], page);
    expect(r.gap, isTrue);
    expect(_ids(r.messages), _ids(page));
  });

  test('a message still being sent survives a gap, unless it arrived', () {
    final r = _merge(
      [_m('', 'k-sent'), _m('', 'k-pending'), _m('2'), _m('1')],
      [_m('40', 'k-sent'), _m('39')],
    );
    expect(r.gap, isTrue);
    expect(r.messages, [_m('', 'k-pending'), _m('40', 'k-sent'), _m('39')]);
  });

  test('the server\'s copy replaces a shown or pending message in place', () {
    final r = _merge(
      [_m('', 'k'), _m('2', 'a'), _m('1')],
      [_m('3', 'k'), _m('2', 'a')],
    );
    expect(r.gap, isFalse);
    expect(r.messages, [_m('3', 'k'), _m('2', 'a'), _m('1')]);
  });

  test('an empty thread just takes the page', () {
    final r = _merge(const [], [_m('2'), _m('1')]);
    expect(r.gap, isFalse);
    expect(_ids(r.messages), ['2', '1']);
  });
}
