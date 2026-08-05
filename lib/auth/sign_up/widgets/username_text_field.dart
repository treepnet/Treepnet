import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/auth/sign_up/cubit/sign_up_cubit.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:shared/shared.dart';

class UsernameTextField extends StatefulWidget {
  const UsernameTextField({super.key});

  @override
  State<UsernameTextField> createState() => _UsernameTextFieldState();
}

class _UsernameTextFieldState extends State<UsernameTextField> {
  final _debouncer = Debouncer();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final cubit = context.read<SignUpCubit>();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        cubit.onUsernameUnfocused();
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
    final usernameError = context.select(
      (SignUpCubit cubit) => cubit.state.username.errorMessage,
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
      hintText: context.l10n.usernameText,
      textInputAction: TextInputAction.next,
      enabled: !isLoading,
      // Handles are lower-case; fold the input as it is typed rather than
      // rejecting the person after the fact.
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_.]')),
        LengthLimitingTextInputFormatter(16),
        TextInputFormatter.withFunction(
          (_, newValue) => newValue.copyWith(text: newValue.text.toLowerCase()),
        ),
      ],
      prefixIcon: Icon(
        Icons.alternate_email_rounded,
        color: isDark ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.8),
        size: 22,
      ),
      enabledBorder: inputBorder,
      focusedBorder: focusedInputBorder,
      onChanged: (v) => context.read<SignUpCubit>().onUsernameChanged(v),
      errorMaxLines: 3,
      errorText: usernameError,
    );
  }
}
