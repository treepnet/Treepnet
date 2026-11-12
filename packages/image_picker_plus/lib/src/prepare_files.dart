import 'dart:io';

/// What [prepareTwoAtATime] made of each file.
class PreparedFiles<T> {
  const PreparedFiles(this.results, this.failed);

  /// One per input file, in the same order; null where it failed.
  final List<T?> results;

  /// The files [prepareTwoAtATime]'s step threw for.
  final List<File> failed;
}

/// Runs [prepare] on [files] two at a time (each photo crop decodes a
/// full-size image, so not all at once), keeping their order. A file whose
/// step throws is listed in [PreparedFiles.failed] instead of stopping the
/// rest.
Future<PreparedFiles<T>> prepareTwoAtATime<T>(
  List<File> files,
  Future<T> Function(File file) prepare,
) async {
  final results = List<T?>.filled(files.length, null);
  final failed = <File>[];
  for (var i = 0; i < files.length; i += 2) {
    await Future.wait([
      for (var j = i; j < i + 2 && j < files.length; j++)
        prepare(files[j]).then<void>(
          (value) => results[j] = value,
          onError: (Object _) => failed.add(files[j]),
        ),
    ]);
  }
  return PreparedFiles(results, failed);
}
