import 'package:app_ui/app_ui.dart';
import 'package:firebase_authentication_client/firebase_authentication_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/auth/auth_error_text.dart';
import 'package:treepnet/auth/social/social_username_page.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

/// "Or", then "Continue with Apple / Google" for each offered on this phone
/// (none: nothing at all). A Google/Apple account with no Treepnet account
/// yet goes on to pick a username; otherwise it is signed in and the router
/// takes it from there.
class SocialSignInButtons extends StatefulWidget {
  const SocialSignInButtons({super.key});

  @override
  State<SocialSignInButtons> createState() => _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends State<SocialSignInButtons> {
  /// The sign-in under way; the buttons wait for it.
  SocialProvider? _busy;

  Future<void> _signIn(SocialProvider provider) async {
    if (_busy != null) return;
    final users = context.read<UserRepository>();
    setState(() => _busy = provider);
    try {
      final result = await users.signInWithSocial(provider);
      if (!mounted) return;
      if (result is SocialNeedsUsername) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SocialUsernamePage(ticket: result.ticket),
          ),
        );
      }
    } on SocialSignInCanceled {
      // The sheet was closed: nothing to say.
    } catch (error) {
      if (!mounted) return;
      openSnackbar(
        SnackbarMessage.error(
          title: socialSignInErrorText(context.l10n, error),
        ),
        clearIfQueue: true,
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = context.read<UserRepository>();
    // Apple's first where it is offered (the iPhone), as Apple asks it be no
    // less prominent than the others.
    final providers = [
      for (final provider in const [SocialProvider.apple, SocialProvider.google])
        if (users.isSocialSignInAvailable(provider)) provider,
    ];
    if (providers.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OrDivider(),
        const Gap.v(AppSpacing.md),
        for (final (i, provider) in providers.indexed) ...[
          if (i > 0) const Gap.v(AppSpacing.sm),
          _SocialButton(
            provider: provider,
            busy: _busy == provider,
            enabled: _busy == null,
            onTap: () => _signIn(provider),
          ),
        ],
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1, color: AppColors.white.withValues(alpha: 0.15)),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            context.l10n.orText,
            style: context.bodyMedium?.copyWith(
              color: AppColors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// A "Continue with ..." button: the app's white auth button (as Log in),
/// with Apple's or Google's own mark.
class _SocialButton extends StatefulWidget {
  const _SocialButton({
    required this.provider,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final SocialProvider provider;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton>
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
    final l10n = context.l10n;
    final apple = widget.provider == SocialProvider.apple;
    final label = apple ? l10n.continueWithAppleText : l10n.continueWithGoogleText;
    final enabled = widget.enabled;
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _press.forward() : null,
        onTapUp: enabled ? (_) => _press.reverse() : null,
        onTapCancel: enabled ? _press.reverse : null,
        onTap: enabled ? widget.onTap : null,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled || widget.busy ? 1 : 0.6,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: widget.busy
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.black,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (apple)
                          const Icon(
                            Icons.apple,
                            color: AppColors.black,
                            size: 24,
                          )
                        else
                          Assets.icons.google.svg(width: 20, height: 20),
                        const Gap.h(AppSpacing.sm + 2),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
