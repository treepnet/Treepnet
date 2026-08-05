import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

/// {@template privacy_page}
/// Settings → Privacy. Currently exposes the "Private account" switch: when on,
/// only followers can see the user's posts, stories and travel map.
/// {@endtemplate}
class PrivacyPage extends StatelessWidget {
  /// {@macro privacy_page}
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AppBloc>().state.user.id;
    final repo = context.read<UserRepository>();
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: Colors.transparent,
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
            context.l10n.privacyText,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
        body: StreamBuilder<User>(
          stream: repo.profile(id: userId),
          builder: (context, snapshot) {
            final isPrivate = snapshot.data?.isPrivate ?? false;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.glassBackgroundLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.divider,
                    ),
                  ),
                  child: SwitchListTile(
                    value: isPrivate,
                    onChanged: snapshot.hasData
                        ? (value) => repo.updatePrivacy(
                            userId: userId,
                            isPrivate: value,
                          )
                        : null,
                    secondary: Icon(
                      Icons.lock_outline,
                      color: context.colorScheme.onSurface,
                    ),
                    title: Text(
                      context.l10n.privateAccountText,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: context.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      context.l10n.privateAccountDescriptionText,
                      style: context.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
