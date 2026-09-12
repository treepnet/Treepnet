// ignore_for_file: lines_longer_than_80_chars, cascade_invocations

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the app posts errors. A tiny OCI service behind Caddy forwards them to
/// Treepnet's private Telegram bot — the bot token lives in the SERVER env, never
/// in this binary or the repo. `handle_path /log/*` strips the prefix, so the
/// service itself sees `/error`.
const String _endpoint = 'https://api.treepnet.com/log/error';

/// A weak shared secret that filters casual abuse of the public endpoint. It is
/// compiled into the app, so it is NOT real security — the server's rate-limit
/// and dedup are. Must match `LOG_APP_KEY` on the server.
const String _appKey = 'treepnet-log-2026';

/// Reports ONLY errors / crashes / bugs to Treepnet's own Telegram bot, via a
/// backend proxy. Deliberately narrow:
///
/// * No HTTP request/response logging, no info/warning spam, no analytics.
/// * No PII, no tokens, no request bodies — see [_buildPayload].
/// * Passive: it augments the app's existing error handlers, never replaces
///   them, and can never throw or block the UI (every path is guarded and
///   fire-and-forget).
///
/// Wired from `bootstrap.dart` into `FlutterError.onError`, `runZonedGuarded`
/// and `AppBlocObserver.onError`; call [report] directly from a `catch` block
/// for a bug you want to see even though it was handled.
class CrashReporter {
  CrashReporter._();

  /// The single shared instance.
  static final CrashReporter instance = CrashReporter._();

  /// Observe navigation so a report can name the screen the user was on. Add it
  /// to `GoRouter(observers: [...])`.
  final CrashRouteObserver navigatorObserver = CrashRouteObserver();

  /// Returns the current user's profile id, or null when logged out. Set once
  /// the app has an `AppBloc` — kept as a callback so this file needn't depend
  /// on the app layer, and so no id is ever cached across sign-out.
  String? Function()? userIdProvider;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'x-app-key': _appKey},
    ),
  );

  // Device / app context, gathered once in [init].
  String _env = 'prod';
  String? _appVersion;
  String? _build;
  String? _device;
  String? _os;
  bool _initialised = false;

  // Client-side dedup: signature -> last-sent time. Prevents an error storm
  // from flooding Telegram / draining the battery.
  final Map<String, DateTime> _recent = {};
  static const Duration _dedupWindow = Duration(seconds: 60);

  // Session rate-limit: at most N reports per rolling minute.
  final List<DateTime> _sent = [];
  static const int _maxPerMinute = 20;

  static const String _queueKey = 'crash_reporter.offline_queue';
  static const int _queueCap = 50;

  /// Gathers app/device context once and flushes anything queued while offline.
  /// Safe to call more than once. Never throws.
  Future<void> init({required String env}) async {
    try {
      _env = env;
      if (!kIsWeb) {
        final info = await PackageInfo.fromPlatform();
        _appVersion = info.version;
        _build = info.buildNumber;
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isIOS) {
          final ios = await deviceInfo.iosInfo;
          _device = ios.utsname.machine; // e.g. iPhone15,2
          _os = 'iOS ${ios.systemVersion}';
        } else if (Platform.isAndroid) {
          final android = await deviceInfo.androidInfo;
          _device = android.model;
          _os = 'Android ${android.version.release} (SDK ${android.version.sdkInt})';
        }
      }
      _initialised = true;
      unawaited(_flushQueue());
    } catch (_) {
      // Context is best-effort; a report without it is still useful.
    }
  }

  /// Reports [error] (with optional [stack]) as one of the [kind]s
  /// `flutter | zone | bloc | manual`. Fire-and-forget: it returns immediately
  /// and never throws, so callers can add it beside their existing handling
  /// without a try/catch of their own.
  void report(
    Object error,
    StackTrace? stack, {
    required String kind,
  }) {
    // The whole body is guarded: the reporter must never become the crash.
    unawaited(_report(error, stack, kind));
  }

  Future<void> _report(Object error, StackTrace? stack, String kind) async {
    try {
      // Send the full error message and the full stack — the backend splits a
      // long report across several Telegram messages so nothing is lost. Only a
      // generous safety cap remains so one payload can't be unbounded.
      final message = _truncate(error.toString(), 4000);
      final frames = _allFrames(stack, maxChars: 8000);
      final signature = '$kind|${_truncate(message, 120)}|${frames.isEmpty ? '' : frames.first}';

      final now = DateTime.now();
      if (_isDuplicate(signature, now) || _isRateLimited(now)) return;

      final payload = _buildPayload(
        kind: kind,
        message: message,
        stack: frames.join('\n'),
        signature: signature,
        ts: now.toUtc().toIso8601String(),
      );

      if (kDebugMode) {
        debugPrint('CrashReporter[$kind]: $message');
      }

      await _send(payload);
    } catch (_) {
      // Reporting must never surface an error of its own.
    }
  }

  Map<String, dynamic> _buildPayload({
    required String kind,
    required String message,
    required String stack,
    required String signature,
    required String ts,
  }) {
    // Safe fields ONLY. No headers, no auth tokens, no request/response bodies,
    // no name/email/phone. `userId` is just the anonymous profile UUID (or null).
    return {
      'kind': kind,
      'message': message,
      'stack': stack,
      'screen': navigatorObserver.currentRouteName,
      'appVersion': _appVersion,
      'build': _build,
      'platform': kIsWeb
          ? 'web'
          : (Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other')),
      'os': _os,
      'device': _device,
      'env': _env,
      'userId': _safeUserId(),
      'ts': ts,
      'signature': signature,
    };
  }

  String? _safeUserId() {
    try {
      final id = userIdProvider?.call();
      if (id == null || id.isEmpty) return null;
      return id;
    } catch (_) {
      return null;
    }
  }

  /// Posts one payload. On any network failure the payload is queued so [init]
  /// can retry it later; it never retries in a tight loop.
  Future<void> _send(Map<String, dynamic> payload) async {
    try {
      await _dio.post<void>(_endpoint, data: payload);
    } catch (_) {
      await _enqueue(payload);
    }
  }

  bool _isDuplicate(String signature, DateTime now) {
    final last = _recent[signature];
    if (last != null && now.difference(last) < _dedupWindow) return true;
    _recent[signature] = now;
    // Keep the map from growing without bound.
    if (_recent.length > 100) {
      _recent.removeWhere((_, t) => now.difference(t) > _dedupWindow);
    }
    return false;
  }

  bool _isRateLimited(DateTime now) {
    _sent.removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
    if (_sent.length >= _maxPerMinute) return true;
    _sent.add(now);
    return false;
  }

  Future<void> _enqueue(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_queueKey) ?? <String>[];
      queue.add(jsonEncode(payload));
      // Drop the oldest if we exceed the cap — recent errors matter more.
      while (queue.length > _queueCap) {
        queue.removeAt(0);
      }
      await prefs.setStringList(_queueKey, queue);
    } catch (_) {
      // If even the queue write fails, drop it silently.
    }
  }

  /// Sends anything queued while offline. Stops at the first failure so a dead
  /// backend can never cause a retry storm.
  Future<void> _flushQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_queueKey) ?? <String>[];
      if (queue.isEmpty) return;

      final remaining = <String>[...queue];
      for (final raw in queue) {
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          await _dio.post<void>(_endpoint, data: data);
          remaining.remove(raw);
        } catch (_) {
          break; // Still offline — keep the rest for next time.
        }
      }
      await prefs.setStringList(_queueKey, remaining);
    } catch (_) {
      // Best-effort flush.
    }
  }

  /// All stack frames (not just the top few), bounded only by a large safety
  /// cap on the total characters so a payload can't grow without limit.
  List<String> _allFrames(StackTrace? stack, {required int maxChars}) {
    if (stack == null) return const [];
    final frames = stack
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final kept = <String>[];
    var total = 0;
    for (final f in frames) {
      total += f.length + 1;
      if (total > maxChars) break;
      kept.add(f);
    }
    return kept;
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  /// Exposed only so a debug/test build can fire a synthetic error end-to-end.
  @visibleForTesting
  bool get isInitialised => _initialised;
}

/// Tracks the top-most route name so a report can say which screen the user was
/// on. Reads `route.settings.name`; unnamed routes leave it unchanged.
class CrashRouteObserver extends NavigatorObserver {
  String? currentRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRouteName = route.settings.name ?? currentRouteName;
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentRouteName = newRoute?.settings.name ?? currentRouteName;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRouteName = previousRoute?.settings.name ?? currentRouteName;
    super.didPop(route, previousRoute);
  }
}
