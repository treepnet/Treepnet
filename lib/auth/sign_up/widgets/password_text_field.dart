import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/auth/sign_up/cubit/sign_up_cubit.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:shared/shared.dart';

class PasswordTextField extends StatefulWidget {
  const PasswordTextField({super.key});

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  final _debouncer = Debouncer();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final cubit = context.read<SignUpCubit>();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        cubit.onPasswordUnfocused();
      }
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (SignUpCubit cubit) => cubit.state.submissionStatus.isLoading,
    );
    final passwordError = context.select(
      (SignUpCubit cubit) => cubit.state.password.errorMessage,
    );
    final showPassword = context.select(
      (SignUpCubit cubit) => cubit.state.showPassword,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textFieldFill = AppColors.inputSpace;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
        width: 1.2,
      ),
    );

    final focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: isDark ? Colors.white : Colors.white,
        width: 1.5,
      ),
    );

    return AppTextField(
      filled: true,
      fillColor: textFieldFill,
      focusNode: _focusNode,
      textInputAction: TextInputAction.done,
      textInputType: TextInputType.visiblePassword,
      autofillHints: const [AutofillHints.password],
      prefixIcon: Icon(
        Icons.lock_outline_rounded,
        color: isDark ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.8),
        size: 22,
      ),
      enabledBorder: inputBorder,
      focusedBorder: focusedInputBorder,
      onFieldSubmitted: (_) => context.read<SignUpCubit>().submitDetails(),
      hintText: context.l10n.passwordText,
      enabled: !isLoading,
      obscureText: !showPassword,
      onChanged: (v) => context.read<SignUpCubit>().onPasswordChanged(v),
      errorText: passwordError,
      suffixIcon: Tappable.faded(
        backgroundColor: AppColors.transparent,
        onTap: isLoading
            ? null
            : context.read<SignUpCubit>().changePasswordVisibility,
        child: Icon(
          !showPassword ? Icons.visibility : Icons.visibility_off,
          color: AppColors.white,
        ),
      ),
    );
  }
}
