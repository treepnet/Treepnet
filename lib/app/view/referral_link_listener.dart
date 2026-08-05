import 'dart:async';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:app_links/app_links.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/referral/referral_config.dart';
import 'package:user_repository/user_repository.dart';

/// Captures referral invite links and records the referral once the user is
/// authenticated.
///
/// Three sources feed it, all funnelled through [ReferralConfig]:
///   * `https://<domain>/invite/<handle>` — auto-verified App Link (needs
///     assetlinks.json on the domain);
///   * `treepnet://invite/<handle>` — custom scheme, always opens the app;
///   * the Play Store **install referrer** — the deferred case, so an invite
///     still counts when the app wasn't installed at tap time (Android only;
///     iOS deferred is handled by Branch, wired separately).
///
/// The handle is held until the user is signed in, then sent to
/// [UserRepository.redeemReferral]. Renders nothing.
class ReferralLinkListener extends StatefulWidget {
  /// {@macro referral_link_listener}
  const ReferralLinkListener({super.key});

  @override
  State<ReferralLinkListener> createState() => _ReferralLinkListenerState();
}

class _ReferralLinkListenerState extends State<ReferralLinkListener> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// The most recent invite handle awaiting an authenticated user.
  String? _pendingHandle;
  bool _redeeming = false;

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
    _pendingHandle = handle;
    _tryRedeem();
  }

  /// Reads the Play Store install referrer exactly once per install. If a link
  /// was tapped before the app existed, the invite handle rides along in the
  /// referrer string and is picked up here on first launch.
  Future<void> _checkInstallReferrer() async {
    try {
      final details = await AndroidPlayInstallReferrer.installReferrer;
      final handle = ReferralConfig.handleFromReferrer(
        details.installReferrer,
      );
      if (handle == null) return;
      // Only if a direct link hasn't already provided one.
      _pendingHandle ??= handle;
      _tryRedeem();
    } catch (_) {
      // No Play install (sideload, iOS, emulator) — nothing to read.
    }
  }

  Future<void> _tryRedeem() async {
    final handle = _pendingHandle;
    if (handle == null || _redeeming) return;
    if (context.read<AppBloc>().state.status != AppStatus.authenticated) return;

    _redeeming = true;
    // Read before the await; the widget may be gone when it returns.
    final title = context.l10n.inviteLinkAcceptedText;
    try {
      final status = await context.read<UserRepository>().redeemReferral(
        handle: handle,
      );
      // Any definitive answer means we're done with this handle.
      _pendingHandle = null;
      if (status == 'ok') {
        openSnackbar(SnackbarMessage.success(title: title));
      }
    } catch (_) {
      // Keep _pendingHandle so a later retry (e.g. next auth change) can run.
    } finally {
      _redeeming = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // When the user finishes signing in, redeem any handle captured earlier.
    return BlocListener<AppBloc, AppState>(
      listenWhen: (previous, current) =>
          previous.status != AppStatus.authenticated &&
          current.status == AppStatus.authenticated,
      listener: (_, __) => _tryRedeem(),
      child: const SizedBox.shrink(),
    );
  }
}
