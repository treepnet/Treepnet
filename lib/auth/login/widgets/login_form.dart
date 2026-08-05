import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/auth/login/cubit/login_cubit.dart';
import 'package:treepnet/auth/login/widgets/widgets.dart';
import 'package:treepnet/l10n/l10n.dart';

/// {@template login_form}
/// Login form that contains email and password fields.
/// {@endtemplate}
class LoginForm extends StatefulWidget {
  /// {@macro login_form}
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  @override
  void initState() {
    super.initState();
    context.read<LoginCubit>().resetState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<LoginCubit>().resetState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginCubit, LoginState>(
      listener: (context, state) {
        if (state.status.isError) {
          final l10n = context.l10n;
          final (String title, String? description) = switch (state.status) {
            LogInSubmissionStatus.invalidCredentials => (
              l10n.incorrectCredentialsText,
              null,
            ),
            LogInSubmissionStatus.userNotFound => (
              l10n.userNotFoundText,
              l10n.tryToSignUpText,
            ),
            LogInSubmissionStatus.googleLogInFailure => (
              l10n.googleLoginFailedText,
              l10n.tryAgainLaterText,
            ),
            LogInSubmissionStatus.networkError => (
              l10n.internetConnectionErrorText,
              l10n.checkInternetConnectionText,
            ),
            _ => (l10n.somethingWentWrongText, l10n.tryAgainLaterText),
          };
          openSnackbar(
            SnackbarMessage.error(title: title, description: description),
            clearIfQueue: true,
          );
        }
      },
      listenWhen: (p, c) => p.status != c.status,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [UsernameTextField(), gapH12, PasswordTextField()],
      ),
    );
  }
}
