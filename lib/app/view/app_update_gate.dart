import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_ui/app_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Server-controlled app-update gate.
///
/// On start, and when the app comes back to the foreground (at most hourly),
/// it reads a small per-platform config from the backend:
///
/// ```json
/// { "android": { "minBuild": 8, "latestBuild": 9, "storeUrl": "https://…" },
///   "ios":     { "minBuild": 0, "latestBuild": 9, "storeUrl": "https://…" } }
/// ```
///
/// * installed build < `minBuild` → a full-screen "Update required" page
///   covers the app;
/// * installed build < `latestBuild` → a dismissible "New version available"
///   card, shown once per `latestBuild`;
/// * otherwise nothing.
///
/// It fails OPEN: no network, a timeout or a bad value never blocks anyone.
/// This code ships in the app and can't be fixed from the server, so it stays
/// minimal and compares integer build numbers only. Raise `minBuild` only once
/// that build is fully live on the store — and lower it to undo a block.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key});

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

enum _Prompt { none, optional, required }

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  static const _configUrl = 'https://api.treepnet.com/app-config/version.json';
  static const _recheckAfter = Duration(hours: 1);

  /// The `latestBuild` whose "New version available" card was dismissed.
  static const _dismissedKey = 'treepnet_update_dismissed_build';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  _Prompt _prompt = _Prompt.none;
  String _storeUrl = '';
  int _latestBuild = 0;
  DateTime? _lastCheck;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastCheck;
    if (last == null || DateTime.now().difference(last) >= _recheckAfter) {
      unawaited(_check());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dio.close();
    super.dispose();
  }

  static int _int(Object? value) => switch (value) {
    final int v => v,
    final num v => v.toInt(),
    _ => int.tryParse('$value') ?? 0,
  };

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    _lastCheck = DateTime.now();
    try {
      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
          ? 'ios'
          : null;
      if (platform == null) return;
      final build = int.tryParse(
        (await PackageInfo.fromPlatform()).buildNumber,
      );
      if (build == null) return;

      final response = await _dio.get<dynamic>(_configUrl);
      final config = response.data;
      final entry = config is Map ? config[platform] : null;
      if (entry is! Map) return;
      final minBuild = _int(entry['minBuild']);
      final latestBuild = _int(entry['latestBuild']);
      final storeUrl = entry['storeUrl'];
      // Without a store to send people to, never block or nag.
      if (storeUrl is! String || !storeUrl.startsWith('https://')) return;

      var prompt = _Prompt.none;
      if (build < minBuild) {
        prompt = _Prompt.required;
      } else if (build < latestBuild) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getInt(_dismissedKey) != latestBuild) {
          prompt = _Prompt.optional;
        }
      }
      if (!mounted) return;
      setState(() {
        _prompt = prompt;
        _storeUrl = storeUrl;
        _latestBuild = latestBuild;
      });
    } catch (_) {
      // Fail open: a failed check never blocks or nags (and keeps whatever the
      // last successful check decided).
    } finally {
      _checking = false;
    }
  }

  Future<void> _openStore() async {
    try {
      await launchUrl(
        Uri.parse(_storeUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Nothing to fall back to; the button stays for another try.
    }
  }

  Future<void> _dismiss() async {
    setState(() => _prompt = _Prompt.none);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_dismissedKey, _latestBuild);
    } catch (_) {
      // Only means the card may show again next time.
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_prompt) {
      _Prompt.none => const SizedBox.shrink(),
      _Prompt.required => Positioned.fill(
        child: _UpdateRequired(onUpdate: _openStore),
      ),
      _Prompt.optional => Positioned(
        left: AppSpacing.md,
        right: AppSpacing.md,
        // Above the bottom navigation bar.
        bottom:
            MediaQuery.paddingOf(context).bottom +
            kBottomNavigationBarHeight +
            AppSpacing.md,
        child: _UpdateAvailable(onUpdate: _openStore, onLater: _dismiss),
      ),
    };
  }
}

class _UpdateRequired extends StatelessWidget {
  const _UpdateRequired({required this.onUpdate});

  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: context.theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxlg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.system_update_outlined,
                size: 80,
                color: context.adaptiveColor,
              ),
              const Gap.v(AppSpacing.lg),
              Text(
                l10n.updateRequiredTitle,
                style: context.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const Gap.v(AppSpacing.md),
              Text(
                l10n.updateRequiredDescription,
                style: context.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Gap.v(AppSpacing.xlg),
              AppButton(text: l10n.updateText, onPressed: onUpdate),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateAvailable extends StatelessWidget {
  const _UpdateAvailable({required this.onUpdate, required this.onLater});

  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      elevation: 6,
      color: context.theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.updateAvailableTitle, style: context.titleMedium),
            const Gap.v(AppSpacing.xs),
            Text(l10n.updateAvailableDescription, style: context.bodyMedium),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  TextButton(onPressed: onLater, child: Text(l10n.laterText)),
                  TextButton(onPressed: onUpdate, child: Text(l10n.updateText)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
