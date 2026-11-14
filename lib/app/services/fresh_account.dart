import 'dart:async';

import 'package:flutter/foundation.dart';

/// A sign-up has just finished and the new profile is on its way.
///
/// Signing in gives the app the account at once but its profile row a moment
/// (on a slow network, seconds) later, and only the row says the intro is
/// still to come. In between, the router sent a brand-new account to the
/// feed, then pulled it into the intro as the row arrived. While this is
/// [active] it goes straight to the intro, which waits for the row there.
/// After [_wait] it lets go, whatever has arrived (the feed, as before).
class FreshAccount extends ChangeNotifier {
  FreshAccount._();

  /// The one the router and sign-up share.
  static final FreshAccount instance = FreshAccount._();

  static const _wait = Duration(seconds: 20);

  bool _active = false;
  Timer? _timer;

  bool get active => _active;

  /// A new account is being made (set before it is signed in, so the router
  /// sees it on its first look).
  void start() {
    _timer?.cancel();
    _timer = Timer(_wait, end);
    if (_active) return;
    _active = true;
    notifyListeners();
  }

  /// Signing up failed, or the wait is over.
  void end() {
    _timer?.cancel();
    _timer = null;
    if (!_active) return;
    _active = false;
    notifyListeners();
  }
}
