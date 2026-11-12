import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_chat/platform/presantation/cubit/read_marks.dart';

typedef _M = ({String id, String status});

_M _m(String id, String status) => (id: id, status: status);

List<_M> _read(List<_M> messages, {String? id}) => markRead<_M>(
  messages,
  idOf: (m) => m.id,
  asRead: (m) => (id: m.id, status: 'seen'),
  id: id,
);

void main() {
  group('markRead', () {
    test("the peer's read doesn't touch messages not sent yet or failed", () {
      final thread = [
        _m('', 'error'), // refused (blocked) or timed out
        _m('', 'sending'),
        _m('7', 'sent'),
      ];
      expect(_read(thread), [
        _m('', 'error'),
        _m('', 'sending'),
        _m('7', 'seen'),
      ]);
    });

    test('one message by id: only that one', () {
      final thread = [_m('7', 'sent'), _m('8', 'sent'), _m('', 'error')];
      expect(_read(thread, id: '8'), [
        _m('7', 'sent'),
        _m('8', 'seen'),
        _m('', 'error'),
      ]);
    });
  });

  group('keepsRead', () {
    test("a read message's server update stays read", () {
      expect(keepsRead(wasRead: true, updateIsLocal: false), isTrue);
    });

    test('a failure shows, even on one marked read before', () {
      expect(keepsRead(wasRead: true, updateIsLocal: true), isFalse);
    });

    test('nothing read, nothing kept', () {
      expect(keepsRead(wasRead: false, updateIsLocal: false), isFalse);
    });
  });
}
