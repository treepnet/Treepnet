import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/auth/login/cubit/login_cubit.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:shared/shared.dart';

class AuthProviderSignInButton extends StatelessWidget {
  const AuthProviderSignInButton({
    required this.provider,
    required this.onPressed,
    super.key,
  });

  final AuthProvider provider;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInProgress = context.select(
      (LoginCubit cubit) => switch (provider) {
        AuthProvider.google => cubit.state.status.isGoogleAuthInProgress,
        AuthProvider.github => cubit.state.status.isGithubAuthInProgress,
      },
    );
    final effectiveIcon = switch (provider) {
      AuthProvider.github => Assets.icons.github.svg(
          colorFilter: ColorFilter.mode(
            isDark ? Colors.white : Colors.black,
            BlendMode.srcIn,
          ),
        ),
      AuthProvider.google => Assets.icons.google.svg(),
    };
    final icon = SizedBox.square(dimension: 20, child: effectiveIcon);

    final btnBgColor = isDark 
        ? Colors.white.withOpacity(0.03) 
        : Colors.black.withOpacity(0.02);

    final borderColor = isDark 
        ? Colors.white.withOpacity(0.08) 
        : Colors.black.withOpacity(0.1);

    return Container(
      constraints: BoxConstraints(
        minWidth: switch (context.screenWidth) {
          > 600 => context.screenWidth * .6,
          _ => double.infinity,
        },
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: btnBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: 1.0,
          ),
        ),
        child: Tappable.faded(
          throttle: true,
          throttleDuration: 650.ms,
          backgroundColor: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          onTap: isInProgress ? null : onPressed,
          child: isInProgress
              ? Center(child: AppCircularProgress(context.adaptiveColor))
              : Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      gapW12,
                      Text(
                        context.l10n.signInWithText(provider.value),
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

enum AuthProvider {
  github('Github'),
  google('Google');

  const AuthProvider(this.value);

  final String value;
}
