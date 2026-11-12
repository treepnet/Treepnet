import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_plus/src/prepare_files.dart';

void main() {
  final files = [for (var i = 0; i < 5; i++) File('/photo$i.jpg')];

  test('two at a time, results in the order of the files', () async {
    var running = 0;
    var most = 0;
    final done = await prepareTwoAtATime(files, (file) async {
      running++;
      most = running > most ? running : most;
      // Later files finish first: the order must still hold.
      await Future<void>.delayed(
        Duration(milliseconds: 20 - files.indexOf(file) * 3),
      );
      running--;
      return file.path;
    });
    expect(most, 2);
    expect(done.results, [for (final f in files) f.path]);
    expect(done.failed, isEmpty);
  });

  test('a file that fails is listed, the others still come through', () async {
    final done = await prepareTwoAtATime(files, (file) async {
      if (file.path == '/photo1.jpg' || file.path == '/photo4.jpg') {
        throw const FileSystemException('cannot decode');
      }
      return file.path;
    });
    expect(done.failed.map((f) => f.path), ['/photo1.jpg', '/photo4.jpg']);
    expect(done.results, [
      '/photo0.jpg',
      null,
      '/photo2.jpg',
      '/photo3.jpg',
      null,
    ]);
  });

  test('nothing to do', () async {
    final done = await prepareTwoAtATime<String>([], (_) async => 'x');
    expect(done.results, isEmpty);
    expect(done.failed, isEmpty);
  });
}
