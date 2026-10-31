import 'dart:async';

import 'package:flutter/material.dart';
import 'package:treepnet/l10n/l10n.dart';

/// "Send the code again", counting down ("Send again in 0:45") until [wait]
/// has passed since [sentAt] — a new code sooner would only void the one on
/// its way. Used on the sign-up and password-reset code screens.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({
    required this.sentAt,
    required this.wait,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  /// When the last code was sent; null — not sent yet (available at once).
  final DateTime? sentAt;
  final Duration wait;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  Timer? _ticker;

  Duration get _left {
    final sentAt = widget.sentAt;
    if (sentAt == null) return Duration.zero;
    final left = widget.wait - DateTime.now().difference(sentAt);
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void initState() {
    super.initState();
    _tick();
  }

  @override
  void didUpdateWidget(covariant ResendCodeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sentAt != widget.sentAt) _tick();
  }

  /// Rebuilds every second while counting down.
  void _tick() {
    _ticker?.cancel();
    if (_left == Duration.zero) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {});
      if (_left == Duration.zero) timer.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _left;
    final waiting = left > Duration.zero;
    final seconds = left.inSeconds + (left.inMilliseconds % 1000 > 0 ? 1 : 0);
    final label = waiting
        ? context.l10n.resendCodeInText(
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
          )
        : context.l10n.sendCodeAgainText;
    return TextButton(
      onPressed: waiting || !widget.enabled ? null : widget.onPressed,
      child: Text(label),
    );
  }
}
