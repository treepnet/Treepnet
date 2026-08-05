import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/auth/sign_up/cubit/sign_up_cubit.dart';
import 'package:treepnet/l10n/l10n.dart';

/// Primary action of the sign-up flow. Its label and action follow the current
/// [SignUpStep]: continue → send the code → verify it.
class SignUpButton extends StatefulWidget {
  const SignUpButton({super.key});

  @override
  State<SignUpButton> createState() => _SignUpButtonState();
}

class _SignUpButtonState extends State<SignUpButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (SignUpCubit bloc) => bloc.state.submissionStatus.isLoading,
    );
    final step = context.select((SignUpCubit bloc) => bloc.state.step);

    final label = switch (step) {
      SignUpStep.details => context.l10n.continueText,
      SignUpStep.email => context.l10n.sendCodeText,
      SignUpStep.code => context.l10n.verifyText,
    };

    void submit() {
      final cubit = context.read<SignUpCubit>();
      switch (step) {
        case SignUpStep.details:
          cubit.submitDetails();
        case SignUpStep.email:
          cubit.submitEmail();
        case SignUpStep.code:
          cubit.submitCode();
      }
    }

    return GestureDetector(
      onTapDown: (_) => isLoading ? null : _controller.forward(),
      onTapUp: (_) => isLoading ? null : _controller.reverse(),
      onTapCancel: () => isLoading ? null : _controller.reverse(),
      onTap: isLoading ? null : submit,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}
