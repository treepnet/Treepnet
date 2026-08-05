import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/auth/sign_up/cubit/sign_up_cubit.dart';
import 'package:treepnet/l10n/l10n.dart';

/// How good a password is, judged the way Microsoft Entra judges it: length
/// plus how many character classes are used.
enum PasswordStrength {
  /// Too short, or all one kind of character.
  weak,

  /// Long enough, but only two character classes.
  medium,

  /// Long, with at least three of: lower, upper, digit, symbol.
  strong;

  /// Rates [value]. Entra requires 8+ characters and three character classes,
  /// so only [strong] is accepted at sign-up.
  static PasswordStrength of(String value) {
    if (value.length < 8) return PasswordStrength.weak;
    var classes = 0;
    if (RegExp('[a-z]').hasMatch(value)) classes++;
    if (RegExp('[A-Z]').hasMatch(value)) classes++;
    if (RegExp('[0-9]').hasMatch(value)) classes++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) classes++;
    if (classes >= 3) return PasswordStrength.strong;
    if (classes >= 2) return PasswordStrength.medium;
    return PasswordStrength.weak;
  }

  /// Whether sign-up may proceed with a password of this strength.
  bool get isAcceptable => this == PasswordStrength.strong;
}

/// Strength readout under the password field: a message, then a bar that grows
/// and turns red → amber → green. Shows the verdict while the password is
/// being typed rather than after the identity service refuses it a screen
/// later.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key});

  @override
  Widget build(BuildContext context) {
    final password = context.select((SignUpCubit c) => c.state.password.value);
    // A password Entra refused (it keeps a banned-password list this meter
    // can't see). Say so right under the field being blamed.
    final rejection = context.select(
      (SignUpCubit c) =>
          c.state.step == SignUpStep.details ? c.state.errorMessage : null,
    );
    if (password.isEmpty && rejection == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final strength = PasswordStrength.of(password);
    final (color, message, fraction) = switch (strength) {
      PasswordStrength.weak => (
        AppColors.red,
        l10n.passwordNeedStrongerText,
        0.33,
      ),
      PasswordStrength.medium => (
        Colors.amber,
        l10n.passwordNeedStrongerText,
        0.66,
      ),
      PasswordStrength.strong => (
        Colors.green,
        l10n.passwordStrongText,
        1.0,
      ),
    };

    // Entra's verdict outranks the local guess: the bar may be green and the
    // password still refused.
    final showColor = rejection != null ? AppColors.red : color;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rejection ?? message,
            style: TextStyle(color: showColor, fontSize: 12.5),
          ),
          const Gap.v(AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            // No LayoutBuilder here: an ancestor in the sign-up layout measures
            // intrinsic height, and LayoutBuilder throws during that pass —
            // which blanked the whole screen the moment this meter appeared.
            // A FractionallySizedBox fills a fraction of the track without
            // needing the measured width.
            child: Stack(
              children: [
                Container(
                  height: 3,
                  width: double.infinity,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    tween: Tween<double>(
                      end: rejection != null ? 0.33 : fraction,
                    ),
                    builder: (context, value, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value.clamp(0.0, 1.0),
                      child: ColoredBox(color: showColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
