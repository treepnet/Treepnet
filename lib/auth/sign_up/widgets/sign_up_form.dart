import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/auth/sign_up/cubit/sign_up_cubit.dart';
import 'package:treepnet/auth/sign_up/widgets/widgets.dart';
import 'package:treepnet/l10n/l10n.dart';

/// {@template sign_up_form}
/// Sign up form that contains email and password fields.
/// {@endtemplate}
class SignUpForm extends StatefulWidget {
  /// {@macro sign_up_form}
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  @override
  Widget build(BuildContext context) {
    return BlocListener<SignUpCubit, SignupState>(
      listener: (context, state) {
        if (state.submissionStatus.isError) {
          final l10n = context.l10n;
          final (String title, String? description) =
              switch (state.submissionStatus) {
                SignUpSubmissionStatus.emailAlreadyRegistered => (
                  l10n.emailAlreadyExistsText,
                  l10n.tryAnotherEmailText,
                ),
                SignUpSubmissionStatus.networkError => (
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
      listenWhen: (p, c) => p.submissionStatus != c.submissionStatus,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmailTextField(),
          gapH12,
          UsernameTextField(),
          gapH12,
          PasswordTextField(),
        ],
      ),
    );
  }
}
