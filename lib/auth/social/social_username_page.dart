import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:form_fields/form_fields.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/app/services/fresh_account.dart';
import 'package:treepnet/auth/auth_error_text.dart';
import 'package:treepnet/auth/field_error_l10n.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/referral/pending_referral.dart';
import 'package:user_repository/user_repository.dart';

/// A Google/Apple sign-in with no Treepnet account yet: the new account's
/// username, then the account is made and signed in (the router goes on to
/// the intro). The field starts empty: the person picks the name.
class SocialUsernamePage extends StatefulWidget {
  const SocialUsernamePage({required this.ticket, super.key});

  /// The checked sign-in (see [SocialNeedsUsername.ticket]).
  final String ticket;

  @override
  State<SocialUsernamePage> createState() => _SocialUsernamePageState();
}

class _SocialUsernamePageState extends State<SocialUsernamePage> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = context.l10n;
    final username = Username.dirty(_controller.text.trim().toLowerCase());
    if (username.invalid) {
      setState(() => _error = usernameErrorText(context, username.validationError));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final users = context.read<UserRepository>();
    final navigator = Navigator.of(context);
    // Before signing in: the router sends the new account to the intro, not
    // the feed, from its first look (as a password sign-up does).
    FreshAccount.instance.start();
    try {
      await users.completeSocialSignUp(
        ticket: widget.ticket,
        username: username.value,
      );
      // A brand-new account is what counts an invite: the one captured from
      // a link or the install, here as in a password sign-up.
      final userId = users.currentUserId;
      if (userId != null) {
        await PendingReferral.redeemFor(users, userId: userId);
      }
      if (mounted && navigator.canPop()) navigator.pop();
    } catch (error) {
      FreshAccount.instance.end();
      if (!mounted) return;
      final code = authErrorCode(error);
      switch (code) {
        case 'username_taken':
          setState(() => _error = l10n.signUpUsernameTakenError);
        case 'invalid_username':
          setState(() => _error = l10n.usernameValidationText);
        case 'ticket_expired':
          // Back to sign in: the Google/Apple sign-in is too old to use.
          openSnackbar(
            SnackbarMessage.error(title: l10n.socialSignInExpiredText),
            clearIfQueue: true,
          );
          if (navigator.canPop()) navigator.pop();
        default:
          openSnackbar(
            SnackbarMessage.error(title: socialSignInErrorText(l10n, error)),
            clearIfQueue: true,
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_busy,
      child: TreepNetAmbientBackground(
        child: AuthShell(
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.chooseUsernameTitleText,
                  style: context.textTheme.titleLarge?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap.v(AppSpacing.xs),
                Text(
                  l10n.chooseUsernameSubtitleText,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Gap.v(AppSpacing.lg),
                _UsernameField(
                  controller: _controller,
                  enabled: !_busy,
                  errorText: _error,
                  onChanged: () {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: _submit,
                ),
                const Gap.v(AppSpacing.lg),
                _ContinueButton(busy: _busy, onTap: _submit),
                const Gap.v(AppSpacing.sm),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                  child: Text(l10n.backText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The username field, as on the sign-up form.
class _UsernameField extends StatelessWidget {
  const _UsernameField({
    required this.controller,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: AppColors.white.withValues(alpha: 0.1),
        width: 1.2,
      ),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.white, width: 1.5),
    );
    return AppTextField(
      textController: controller,
      filled: true,
      fillColor: AppColors.inputSpace,
      hintText: context.l10n.usernameText,
      textInputAction: TextInputAction.done,
      enabled: enabled,
      // Handles are lower-case; folded as typed (as on the sign-up form).
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_.]')),
        LengthLimitingTextInputFormatter(16),
        TextInputFormatter.withFunction(
          (_, newValue) => newValue.copyWith(text: newValue.text.toLowerCase()),
        ),
      ],
      prefixIcon: Icon(
        Icons.alternate_email_rounded,
        color: AppColors.white.withValues(alpha: 0.8),
        size: 22,
      ),
      enabledBorder: border,
      focusedBorder: focusedBorder,
      onChanged: (_) => onChanged(),
      onFieldSubmitted: (_) => onSubmitted(),
      errorMaxLines: 3,
      errorText: errorText,
    );
  }
}

/// The app's white auth button (as Log in / Continue on the sign-up form).
class _ContinueButton extends StatefulWidget {
  const _ContinueButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1, end: 0.96)
      .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.busy;
    return GestureDetector(
      onTapDown: busy ? null : (_) => _press.forward(),
      onTapUp: busy ? null : (_) => _press.reverse(),
      onTapCancel: busy ? null : _press.reverse,
      onTap: busy ? null : widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: busy
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.black),
                  ),
                )
              : Text(
                  context.l10n.continueText,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}
