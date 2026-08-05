import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/app/view/presence_heartbeat.dart';
import 'package:treepnet/app/view/referral_link_listener.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/notifications/push/push_notification_listener.dart';
import 'package:treepnet/selector/selector.dart';
import 'package:shared/shared.dart';

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    final routerConfig = AppRouter(context.read<AppBloc>()).router;

    return BlocBuilder<LocaleBloc, Locale>(
      builder: (context, locale) {
        return BlocBuilder<ThemeModeBloc, ThemeMode>(
          builder: (context, themeMode) {
            return AnimatedSwitcher(
              duration: 350.ms,
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                title: 'Treepnet',
                routerConfig: routerConfig,
                builder: (context, child) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => initUtilities(context, locale),
                  );

                  return MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.noScaling),
                    child: Stack(
                      children: [
                        child!,
                        const PresenceHeartbeat(),
                        const ReferralLinkListener(),
                        const PushNotificationListener(),
                        AppSnackbar(key: snackbarKey),
                        AppLoadingIndeterminate(key: loadingIndeterminateKey),
                      ],
                    ),
                  );
                },
                themeMode: themeMode,
                theme: const AppTheme().theme,
                darkTheme: const AppDarkTheme().theme,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              ),
            );
          },
        );
      },
    );
  }
}
