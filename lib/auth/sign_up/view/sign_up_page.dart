import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/auth/sign_up/cubit/sign_up_cubit.dart';
import 'package:treepnet/auth/sign_up/widgets/widgets.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SignUpCubit(
        userRepository: context.read<UserRepository>(),
      ),
      child: const SignUpView(),
    );
  }
}

/// Sign-up in three screens: details → email → emailed code.
///
/// Entra's native authentication API backs each step, so the whole flow stays
/// inside the app — no browser hand-off.
class SignUpView extends StatelessWidget {
  const SignUpView({super.key});

  @override
  Widget build(BuildContext context) {
    return TreepNetAmbientBackground(
      child: BlocConsumer<SignUpCubit, SignupState>(
        listenWhen: (p, c) => p.submissionStatus != c.submissionStatus,
        listener: (context, state) {
          if (state.submissionStatus.isError) {
            final l10n = context.l10n;
            final title = switch (state.error) {
              SignUpError.invalidFields => l10n.signUpInvalidFieldsError,
              SignUpError.usernameTaken => l10n.signUpUsernameTakenError,
              SignUpError.invalidEmail => l10n.signUpInvalidEmailError,
              SignUpError.invalidCode => l10n.signUpInvalidCodeError,
              SignUpError.weakPassword => l10n.signUpWeakPasswordError,
              // No local cause: the identity service explained why.
              null => state.errorMessage ?? l10n.signUpGenericError,
            };
            openSnackbar(
              SnackbarMessage.error(title: title),
              clearIfQueue: true,
            );
          }
        },
        builder: (context, state) {
          return AuthShell(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  _StepIndicator(step: state.step),
                  const Gap.v(AppSpacing.md),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StepTitle(step: state.step, email: state.email.value),
                        const Gap.v(AppSpacing.lg),
                        switch (state.step) {
                          SignUpStep.details => const _DetailsStep(),
                          SignUpStep.email => const _EmailStep(),
                          SignUpStep.code => const _CodeStep(),
                        },
                        const Gap.v(AppSpacing.lg),
                        const SignUpButton(),
                        if (state.step != SignUpStep.details) ...[
                          const Gap.v(AppSpacing.sm),
                          TextButton(
                            onPressed: state.submissionStatus.isLoading
                                ? null
                                : () => context.read<SignUpCubit>().backStep(),
                            child: Text(context.l10n.backText),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Gap.v(AppSpacing.lg),
                  const SignInIntoAccountButton(),
                ],
              ),
          );
        },
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Sign-up asks for a username only — no full name.
      UsernameTextField(),
      Gap.v(AppSpacing.md),
      PasswordTextField(),
      PasswordStrengthMeter(),
    ],
  );
}

class _EmailStep extends StatelessWidget {
  const _EmailStep();

  @override
  Widget build(BuildContext context) => const EmailTextField();
}

class _CodeStep extends StatelessWidget {
  const _CodeStep();

  @override
  Widget build(BuildContext context) => const CodeTextField();
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.step, required this.email});

  final SignUpStep step;
  final String email;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, subtitle) = switch (step) {
      SignUpStep.details => (
        l10n.signUpDetailsTitle,
        l10n.signUpDetailsSubtitle,
      ),
      SignUpStep.email => (l10n.signUpEmailTitle, l10n.signUpEmailSubtitle),
      SignUpStep.code => (
        l10n.signUpCodeTitle,
        l10n.signUpCodeSubtitle(email),
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.titleLarge?.copyWith(
            color: context.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Gap.v(AppSpacing.xs),
        Text(
          subtitle,
          style: context.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final SignUpStep step;

  @override
  Widget build(BuildContext context) {
    final index = SignUpStep.values.indexOf(step);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(SignUpStep.values.length, (i) {
        final active = i <= index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 4,
          width: active ? 28 : 16,
          decoration: BoxDecoration(
            color: active
                ? AppColors.white
                : AppColors.glassBackgroundLight,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
