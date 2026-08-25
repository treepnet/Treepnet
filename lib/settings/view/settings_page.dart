import 'package:app_ui/app_ui.dart';
import 'package:entra_authentication_client/entra_authentication_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/selector/selector.dart';
import 'package:treepnet/stories/view/story_archive_page.dart';
import 'package:treepnet/settings/view/blocked_users_page.dart';
import 'package:treepnet/settings/view/privacy_page.dart';
import 'package:treepnet/settings/view/referral_page.dart';
import 'package:treepnet/settings/view/saved_posts_page.dart';
import 'package:treepnet/settings/view/security_page.dart';
import 'package:user_repository/user_repository.dart';

/// {@template settings_page}
/// The app settings screen (Figma "Settings"): a list of option rows plus
/// account actions at the bottom. Opened from the profile menu button.
/// {@endtemplate}
class SettingsPage extends StatelessWidget {
  /// {@macro settings_page}
  const SettingsPage({super.key});

  void _logout(BuildContext context) {
    context.confirmAction(
      fn: () => context.read<AppBloc>().add(const AppLogoutRequested()),
      title: context.l10n.logOutText,
      content: context.l10n.logOutConfirmationText,
      noText: context.l10n.cancelText,
      yesText: context.l10n.logOutText,
    );
  }

  /// Two gates before anything is deleted: a plain-language warning, then the
  /// account password. Only a correct password actually erases the account.
  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.deleteAccountText),
        content: Text(context.l10n.deleteAccountWarningText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(context.l10n.continueText),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Hand the auth client the *username*, exactly as the normal login screen
    // does — it resolves the handle to the account's canonical Entra email
    // itself. The profile's `email` field can be stale or differ from the
    // sign-in address, and passing it straight to re-auth fails with
    // AADSTS50126 ("invalid username or password") even on a correct password.
    final user = context.read<AppBloc>().state.user;
    final identifier = (user.username != null && user.username!.isNotEmpty)
        ? user.username!
        : (user.email ?? '');
    debugPrint('DELETE_ACCT identifier=$identifier');
    if (identifier.isEmpty) {
      openSnackbar(
        SnackbarMessage.error(
          title: context.l10n.couldNotIdentifyAccountText,
        ),
      );
      return;
    }

    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountPasswordDialog(),
    );
    if (password == null || password.isEmpty || !context.mounted) return;

    final userRepository = context.read<UserRepository>();
    try {
      await userRepository.deleteAccount(
        email: identifier,
        password: password,
      );
      // A successful delete signs out; AppBloc routes back to login on its own.
    } on LogInWithPasswordFailure catch (error, stackTrace) {
      // The password step failed. Usually a wrong password, but network
      // errors land here too — show the real reason rather than assuming.
      debugPrint('DELETE_ACCT password step failed: $error\n$stackTrace');
      openSnackbar(SnackbarMessage.error(title: _shortError(error)));
    } catch (error, stackTrace) {
      // Password was accepted but the delete itself failed (RPC/permission).
      debugPrint('DELETE_ACCT delete step failed: $error\n$stackTrace');
      openSnackbar(
        SnackbarMessage.error(title: context.l10n.deleteFailedText(_shortError(error))),
      );
    }
  }

  /// Trims the wrapper noise off an exception so the snackbar is readable.
  static String _shortError(Object error) {
    final text = error.toString().replaceAll('Instance of ', '');
    final match = RegExp(r'\((.+)\)$', dotAll: true).firstMatch(text);
    final inner = (match?.group(1) ?? text).trim();
    return inner.length > 140 ? '${inner.substring(0, 140)}…' : inner;
  }

  @override
  Widget build(BuildContext context) {
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: AppColors.transparent,
        appBar: _SettingsAppBar(title: context.l10n.settingsText),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    children: [
                      TreepNetGlassListTile(
                        icon: Icons.bookmark_border_rounded,
                        label: context.l10n.savedText,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const SavedPostsPage(),
                          ),
                        ),
                      ),
                      const Gap.v(AppSpacing.md),
                      TreepNetGlassListTile(
                        icon: Icons.history_rounded,
                        // Stories only — posts are never archived.
                        label: context.l10n.archiveText,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const StoryArchivePage(),
                          ),
                        ),
                      ),
                      const Gap.v(AppSpacing.md),
                      TreepNetGlassListTile(
                        icon: Icons.person_add_alt_1_outlined,
                        label: context.l10n.inviteFriendsText,
                        showDot: true,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const ReferralPage(),
                          ),
                        ),
                      ),
                      const Gap.v(AppSpacing.md),
                      TreepNetGlassListTile(
                        icon: Icons.translate_rounded,
                        label: context.l10n.languageText,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const SettingsLanguagePage(),
                          ),
                        ),
                      ),
                      const Gap.v(AppSpacing.md),
                      TreepNetGlassListTile(
                        icon: Icons.shield_outlined,
                        label: context.l10n.securityText,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const SecurityPage(),
                          ),
                        ),
                      ),
                      const Gap.v(AppSpacing.md),
                      TreepNetGlassListTile(
                        icon: Icons.lock_outline,
                        label: context.l10n.privacyText,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPage(),
                          ),
                        ),
                      ),
                      const Gap.v(AppSpacing.md),
                      TreepNetGlassListTile(
                        icon: Icons.back_hand_outlined,
                        label: context.l10n.blockedUsersText,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const BlockedUsersPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _SettingsPlainRow(
                  icon: Icons.logout_rounded,
                  label: context.l10n.logOutText,
                  onTap: () => _logout(context),
                ),
                _SettingsPlainRow(
                  icon: Icons.delete_outline_rounded,
                  label: context.l10n.deleteAccountText,
                  color: AppColors.red,
                  onTap: () => _deleteAccount(context),
                ),
                const Gap.v(AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Back / centered-title app bar shared by the settings screens.
class _SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SettingsAppBar({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.transparent,
      surfaceTintColor: AppColors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: context.colorScheme.onSurface),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        title,
        style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}


/// A borderless bottom action row (Add account / Log out).
class _SettingsPlainRow extends StatelessWidget {
  const _SettingsPlainRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Row tint. Defaults to the normal on-surface colour; the destructive
  /// "Delete account" row passes red.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, color: tint, size: 24),
            const Gap.h(AppSpacing.md),
            Text(
              label,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for the account password before a delete. Returns the typed password
/// on confirm, or null on cancel. Kept minimal on purpose — the actual
/// password check happens in the repository, so this only collects it.
class _DeleteAccountPasswordDialog extends StatefulWidget {
  const _DeleteAccountPasswordDialog();

  @override
  State<_DeleteAccountPasswordDialog> createState() =>
      _DeleteAccountPasswordDialogState();
}

class _DeleteAccountPasswordDialogState
    extends State<_DeleteAccountPasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.confirmPasswordText),
      content: TextField(
        controller: _controller,
        obscureText: _obscure,
        autofocus: true,
        decoration: InputDecoration(
          hintText: context.l10n.accountPasswordText,
          suffixIcon: IconButton(
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.white,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          style: TextButton.styleFrom(foregroundColor: AppColors.red),
          child: Text(context.l10n.deleteText),
        ),
      ],
    );
  }
}

/// {@template settings_language_page}
/// Language picker (Figma "settings Language"): selects the app locale via
/// [LocaleBloc]. The active language shows a check.
/// {@endtemplate}
class SettingsLanguagePage extends StatelessWidget {
  /// {@macro settings_language_page}
  const SettingsLanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<LocaleBloc>().state;
    // `null` locale = follow the device language. It's the first option so a
    // user who never picked a language sees it selected by default.
    final languages = <({String label, Locale? locale})>[
      (label: context.l10n.systemDefaultText, locale: null),
      (label: 'English', locale: const Locale('en', 'US')),
      (label: 'Русский', locale: const Locale('ru', 'RU')),
    ];
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: AppColors.transparent,
        appBar: _SettingsAppBar(title: context.l10n.languageText),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              children: [
                for (final lang in languages) ...[
                  TreepNetGlassListTile(
                    label: lang.label,
                    trailing: _isSelected(current, lang.locale)
                        ? Icon(Icons.check_rounded, color: context.colorScheme.primary)
                        : null,
                    onTap: () {
                      context.read<LocaleBloc>().add(
                        LocaleChanged(lang.locale),
                      );
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const Gap.v(AppSpacing.md),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Whether [option] is the active selection. `null` [option] is the
  /// "follow device" entry, active only when the user has made no choice.
  bool _isSelected(Locale? current, Locale? option) {
    if (option == null) return current == null;
    return current?.languageCode == option.languageCode;
  }
}


