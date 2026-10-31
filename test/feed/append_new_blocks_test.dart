import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

PostSmallBlock _post(String id) => PostSmallBlock(
  id: id,
  author: const PostAuthor(id: 'a', avatarUrl: '', username: 'author'),
  createdAt: DateTime(2026, 10, 31),
  media: const [],
  caption: '',
);

List<String> _ids(List<InstaBlock> blocks) =>
    [for (final b in blocks) b is PostBlock ? b.id : b.type];

void main() {
  group('appendNew', () {
    test('adds a page after the blocks shown', () {
      final shown = <InstaBlock>[_post('1'), _post('2')];
      expect(_ids(shown.appendNew([_post('3'), _post('4')])), [
        '1',
        '2',
        '3',
        '4',
      ]);
    });

    test('skips a post already shown (the page shifted by one)', () {
      final shown = <InstaBlock>[_post('new'), _post('1'), _post('2')];
      expect(_ids(shown.appendNew([_post('2'), _post('3')])), [
        'new',
        '1',
        '2',
        '3',
      ]);
    });

    test('a post twice within the page goes in once', () {
      expect(_ids(<InstaBlock>[].appendNew([_post('1'), _post('1')])), ['1']);
    });

    test('blocks that are not posts always go in', () {
      const header = SectionHeaderBlock(
        sectionType: SectionHeaderBlockType.suggested,
      );
      final shown = <InstaBlock>[header, _post('1')];
      expect(shown.appendNew([header, _post('1')]).length, 3);
    });

    test('the shown list itself is left as it was', () {
      final shown = <InstaBlock>[_post('1')]..appendNew([_post('2')]);
      expect(_ids(shown), ['1']);
    });
  });
}
