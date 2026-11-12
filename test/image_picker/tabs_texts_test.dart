import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_plus/image_picker_plus.dart';

void main() {
  test('copyWith keeps the translated texts and replaces only the title', () {
    const ru = TabsTexts(
      noPhotoAccessText: 'Нет доступа к фото.',
      openSettingsText: 'Открыть настройки',
      selectMorePhotosText: 'Выбрать ещё фото',
      newPostText: 'Новая публикация',
    );
    final story = ru.copyWith(newPostText: 'Новая история');
    expect(story.newPostText, 'Новая история');
    expect(story.noPhotoAccessText, 'Нет доступа к фото.');
    expect(story.openSettingsText, 'Открыть настройки');
    expect(story.selectMorePhotosText, 'Выбрать ещё фото');
  });
}
