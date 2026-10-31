import 'dart:async';
import 'dart:io';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treepnet/app/bloc/app_bloc.dart';
import 'package:treepnet/referral/pending_referral.dart';
import 'package:treepnet/referral/referral_config.dart';
import 'package:user_repository/user_repository.dart';

/// Captures referral invite links and PERSISTS the handle for the sign-up flow
/// to redeem.
///
/// Three sources feed it, all funnelled through [ReferralConfig]:
///   * `https://<domain>/invite/<handle>` — auto-verified App Link (needs
///     assetlinks.json on the domain);
///   * `treepnet://invite/<handle>` — custom scheme, always opens the app;
///   * the Play Store **install referrer** — Android's deferred case, so an
///     invite still counts when the app wasn't installed at tap time;
///   * the **clipboard** — iOS's deferred case: the invite landing copies
///     `treepnet_invite=<handle>` on the App Store tap, and this reads it once
///     on the first launch after install (iOS has no Play install referrer).
///
/// It only *stores* the handle (see [PendingReferral]); the referral is
/// redeemed exactly once, when a brand-new account is created (sign-up cubit).
/// An already-registered user who taps an invite link — or simply logs back in
/// — therefore never counts, so re-tapping a link can't inflate invite counts.
/// Renders nothing.
class ReferralLinkListener extends StatefulWidget {
  /// {@macro referral_link_listener}
  const ReferralLinkListener({super.key});

  @override
  State<ReferralLinkListener> createState() => _ReferralLinkListenerState();
}

class _ReferralLinkListenerState extends State<ReferralLinkListener> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _appLinks.uriLinkStream.listen(_onUri, onError: (_) {});
    // Cold start: the link that launched the app (if any).
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _onUri(uri);
    });
    _checkInstallReferrer();
    _checkIosClipboard();
    // A redeem that couldn't reach the server at sign-up: finish it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _retryRedeem());
  }

  void _retryRedeem() {
    if (!mounted) return;
    final state = context.read<AppBloc>().state;
    if (state.status != AppStatus.authenticated) return;
    unawaited(
      PendingReferral.retryFor(context.read<UserRepository>(), state.user.id),
    );
  }

  static const _kIosClipChecked = 'ios_referral_clip_checked';
  static const _iosReferralChannel = MethodChannel('treepnet/referral');

  /// iOS deferred attribution: on the FIRST launch after install, read the
  /// invite URL the web landing copied to the clipboard (on the App Store tap).
  ///
  /// Uses a native `detectValues(for: [.probableWebURL])` bridge (iOS 16+) which
  /// returns a clipboard URL WITHOUT the "Allow Paste?" prompt — reading
  /// `Clipboard.getData` directly would nag the user (default = deny) and lose
  /// most referrals. Guarded by a flag so it runs exactly once.
  Future<void> _checkIosClipboard() async {
    if (!Platform.isIOS) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kIosClipChecked) ?? false) return;
      // Mark first (even if the read fails) so it never repeats.
      await prefs.setBool(_kIosClipChecked, true);

      final url = await _iosReferralChannel.invokeMethod<String>('readInviteUrl');
      if (url == null || url.isEmpty) return;
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      final handle = ReferralConfig.handleFromUri(uri);
      if (handle == null || handle.isEmpty) return;
      await PendingReferral.save(handle);
      // Consume it so it can't be re-read or leak.
      await Clipboard.setData(const ClipboardData(text: ''));
    } catch (_) {
      // Channel unavailable / clipboard restricted — nothing to capture.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onUri(Uri uri) {
    final handle = ReferralConfig.handleFromUri(uri);
    if (handle == null || handle.isEmpty) return;
    unawaited(PendingReferral.save(handle));
  }

  static const _kPlayReferrerChecked = 'play_referrer_checked';

  /// Reads the Play Store install referrer exactly once per install. If a link
  /// was tapped before the app existed, the invite handle rides along in the
  /// referrer string and is picked up here on first launch.
  ///
  /// It used to run on every launch: the install's referrer came back after
  /// the first account had used it (so a second account made on this phone
  /// counted again) and overwrote an invite link tapped later.
  Future<void> _checkInstallReferrer() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kPlayReferrerChecked) ?? false) return;
      final details = await AndroidPlayInstallReferrer.installReferrer;
      // Read successfully: never again for this install.
      await prefs.setBool(_kPlayReferrerChecked, true);
      final handle = ReferralConfig.handleFromReferrer(details.installReferrer);
      if (handle == null) return;
      // A link tapped since (more recent, and deliberate) wins.
      if (await PendingReferral.read() != null) return;
      await PendingReferral.save(handle);
    } catch (_) {
      // No Play install (sideload, emulator) or not ready — try next launch.
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<AppBloc, AppState>(
    listenWhen: (previous, current) =>
        previous.status != AppStatus.authenticated &&
        current.status == AppStatus.authenticated,
    listener: (_, __) => _retryRedeem(),
    child: const SizedBox.shrink(),
  );
}
