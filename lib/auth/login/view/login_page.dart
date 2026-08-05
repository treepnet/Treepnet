import 'package:app_ui/app_ui.dart';
import 'package:treepnet/auth/login/view/forgot_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/auth/login/cubit/login_cubit.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/auth/login/widgets/login_form.dart';
import 'package:treepnet/auth/login/widgets/sign_in_button.dart';
import 'package:treepnet/auth/login/widgets/widgets.dart';
import 'package:user_repository/user_repository.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          LoginCubit(userRepository: context.read<UserRepository>()),
      child: const LoginView(),
    );
  }
}

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return TreepNetAmbientBackground(
      child: AuthShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LoginForm(),
                  const Gap.v(AppSpacing.md),
                  const SignInButton(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      ),
                      child: Text(
                        context.l10n.forgotPasswordText,
                        style: context.bodyMedium?.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Gap.v(AppSpacing.xlg),
            const SignUpNewAccountButton(),
          ],
        ),
      ),
    );
  }
}
