import 'dart:async';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:treepnet/referral/pending_referral.dart';
import 'package:treepnet/referral/referral_config.dart';

/// Captures referral invite links and PERSISTS the handle for the sign-up flow
/// to redeem.
///
/// Three sources feed it, all funnelled through [ReferralConfig]:
///   * `https://<domain>/invite/<handle>` — auto-verified App Link (needs
///     assetlinks.json on the domain);
///   * `treepnet://invite/<handle>` — custom scheme, always opens the app;
///   * the Play Store **install referrer** — the deferred case, so an invite
///     still counts when the app wasn't installed at tap time (Android only;
///     iOS deferred is a later phase).
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

  /// Reads the Play Store install referrer exactly once per install. If a link
  /// was tapped before the app existed, the invite handle rides along in the
  /// referrer string and is picked up here on first launch.
  Future<void> _checkInstallReferrer() async {
    try {
      final details = await AndroidPlayInstallReferrer.installReferrer;
      final handle = ReferralConfig.handleFromReferrer(details.installReferrer);
      if (handle == null) return;
      await PendingReferral.save(handle);
    } catch (_) {
      // No Play install (sideload, iOS, emulator) — nothing to read.
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
