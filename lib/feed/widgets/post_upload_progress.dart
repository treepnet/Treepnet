import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Global, app-lifetime notifier that drives the "Posting…" progress banner
/// shown under the stories row on the home feed.
///
/// It replaces the old full-screen blocking loading overlay, so publishing a
/// post never freezes the UI — the user lands back on the feed immediately and
/// watches the upload progress instead.
class PostUploadProgress extends ChangeNotifier {
  /// Returns the shared singleton instance.
  factory PostUploadProgress() => _instance;
  PostUploadProgress._();
  static final PostUploadProgress _instance = PostUploadProgress._();

  bool _active = false;
  double _progress = 0;
  Uint8List? _thumbnail;
  Timer? _crawl;
  Timer? _hideTimer;

  /// Whether an upload is currently in progress (banner visible).
  bool get active => _active;

  /// Current progress in the `0.0 .. 1.0` range.
  double get progress => _progress;

  /// Small preview of the media being uploaded, if available.
  Uint8List? get thumbnail => _thumbnail;

  /// Begins a new upload. [thumbnail] is shown as a small preview.
  void begin({Uint8List? thumbnail}) {
    _hideTimer?.cancel();
    _crawl?.cancel();
    _active = true;
    _progress = 0.03;
    _thumbnail = thumbnail;
    notifyListeners();
    // Slowly crawl toward 0.9 so the bar keeps moving while we wait on the
    // network upload (Supabase storage gives no byte-level progress callback).
    _crawl = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_progress < 0.9) {
        _progress += (0.9 - _progress) * 0.08;
        notifyListeners();
      }
    });
  }

  /// Advances to at least [value] (never moves backwards).
  void to(double value) {
    if (!_active) return;
    if (value > _progress) {
      _progress = value.clamp(0.0, 1.0);
      notifyListeners();
    }
  }

  /// Marks the upload complete, then hides the banner shortly after.
  void complete() {
    if (!_active) return;
    _crawl?.cancel();
    _progress = 1;
    notifyListeners();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 900), _hide);
  }

  void _hide() {
    _active = false;
    _thumbnail = null;
    _progress = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _crawl?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }
}
