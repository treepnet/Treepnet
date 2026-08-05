import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:treepnet/l10n/l10n.dart';

/// {@template security_page}
/// Settings → Security.
///
/// Credentials live in Microsoft Entra, not in Treepnet, so there is no
/// in-app password form: the account password is changed from the hosted
/// sign-in page via its "Forgot password?" link.
/// {@endtemplate}
class SecurityPage extends StatelessWidget {
  /// {@macro security_page}
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: Colors.transparent,
        releaseFocus: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            context.l10n.securityText,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap.v(AppSpacing.xlg),
              Icon(
                Icons.shield_outlined,
                size: 56,
                color: context.colorScheme.onSurface,
              ),
              const Gap.v(AppSpacing.lg),
              Text(
                context.l10n.passwordManagedText,
                textAlign: TextAlign.center,
                style: context.textTheme.titleLarge?.copyWith(
                  color: context.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap.v(AppSpacing.md),
              Text(
                context.l10n.passwordSecurityDescriptionText,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
