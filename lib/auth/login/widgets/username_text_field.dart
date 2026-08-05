import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/auth/login/cubit/login_cubit.dart';
import 'package:treepnet/l10n/l10n.dart';

/// Sign-in identifier field. People sign in with the username they chose —
/// the auth client resolves it to the account's email behind the scenes.
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
    final cubit = context.read<LoginCubit>()..resetState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        cubit.onUsernameUnfocused();
      }
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usernameError = context.select(
      (LoginCubit cubit) => cubit.state.username.errorMessage,
    );
    final isLoading = context.select(
      (LoginCubit cubit) => cubit.state.status.isLoading,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textFieldFill = AppColors.inputSpace;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.1),
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
      key: const ValueKey('loginUsernameTextField'),
      filled: true,
      fillColor: textFieldFill,
      focusNode: _focusNode,
      hintText: context.l10n.usernameText,
      enabled: !isLoading,
      textInputAction: TextInputAction.next,
      textInputType: TextInputType.text,
      autofillHints: const [AutofillHints.username],
      inputFormatters: const [LowerCaseTextFormatter()],
      prefixIcon: Icon(
        Icons.alternate_email_rounded,
        color: isDark
            ? Colors.white.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8),
        size: 22,
      ),
      enabledBorder: inputBorder,
      focusedBorder: focusedInputBorder,
      onChanged: (v) =>
          _debouncer.run(() => context.read<LoginCubit>().onUsernameChanged(v)),
      errorText: usernameError,
    );
  }
}
