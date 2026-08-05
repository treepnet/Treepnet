import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/auth/sign_up/cubit/sign_up_cubit.dart';
import 'package:treepnet/l10n/l10n.dart';

/// The one-time code that arrived by email, on the last sign-up screen.
class CodeTextField extends StatelessWidget {
  const CodeTextField({super.key});

  @override
  Widget build(BuildContext context) {
    final codeError = context.select(
      (SignUpCubit c) => c.state.code.errorMessage,
    );
    final isLoading = context.select(
      (SignUpCubit c) => c.state.submissionStatus.isLoading,
    );
    final codeLength = context.select((SignUpCubit c) => c.state.codeLength);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.1),
        width: 1.2,
      ),
    );

    return AppTextField(
      key: const ValueKey('signUpCodeTextField'),
      filled: true,
      fillColor: AppColors.inputSpace,
      hintText: context.l10n.codeHintText(codeLength),
      enabled: !isLoading,
      textInputType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(codeLength),
      ],
      prefixIcon: Icon(
        Icons.pin_outlined,
        size: 22,
        color: isDark
            ? Colors.white.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8),
      ),
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white : Colors.white,
          width: 1.5,
        ),
      ),
      onChanged: (v) => context.read<SignUpCubit>().onCodeChanged(v),
      errorText: codeError,
    );
  }
}
