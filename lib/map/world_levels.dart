import 'package:flutter/foundation.dart';

/// Levels of detail of the whole world (one per decimation step), each built
/// in the background the first time it is wanted.
///
/// The globe used to build a level on the UI thread inside paint: every ring
/// of every country and province turned into points on the sphere, 80–170 ms
/// on a mid-range Android, the first time the globe showed and on each first
/// zoom into a finer level. Now [at] answers at once with the closest level
/// already built (coarser first, as a stand-in for a moment) and asks [build]
/// for the wanted one; listeners hear when it lands, and the globe repaints.
class WorldLevels<T> extends ChangeNotifier {
  /// [steps] are the decimation steps, coarsest first.
  WorldLevels({required this.steps, required this.build});

  final List<double> steps;

  /// Builds the level for a step — off the UI thread (an isolate).
  final Future<T> Function(double step) build;

  final _built = <double, T>{};
  final _building = <double>{};
  bool _disposed = false;

  /// Starts building [wanted] steps ahead of need.
  void prefetch(Iterable<double> wanted) => wanted.forEach(_request);

  /// The level for [step] if built; otherwise the closest one built —
  /// coarser first, else finer — while [step] is built. Null before any.
  T? at(double step) {
    final exact = _built[step];
    if (exact != null) return exact;
    _request(step);
    final i = steps.indexOf(step);
    if (i < 0) return null;
    for (var j = i - 1; j >= 0; j--) {
      final coarser = _built[steps[j]];
      if (coarser != null) return coarser;
    }
    for (var j = i + 1; j < steps.length; j++) {
      final finer = _built[steps[j]];
      if (finer != null) return finer;
    }
    return null;
  }

  /// Whether [step] is built.
  bool has(double step) => _built.containsKey(step);

  void _request(double step) {
    if (_built.containsKey(step) || !_building.add(step)) return;
    build(step).then(
      (level) {
        _building.remove(step);
        if (_disposed) return;
        _built[step] = level;
        notifyListeners();
      },
      onError: (Object _) {
        // Asked again on the next paint that wants it.
        _building.remove(step);
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
