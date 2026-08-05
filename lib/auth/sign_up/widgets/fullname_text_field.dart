import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/auth/sign_up/cubit/sign_up_cubit.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:shared/shared.dart';

class FullNameTextField extends StatefulWidget {
  const FullNameTextField({super.key});

  @override
  State<FullNameTextField> createState() => _FullNameTextFieldState();
}

class _FullNameTextFieldState extends State<FullNameTextField> {
  final _debouncer = Debouncer();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final cubit = context.read<SignUpCubit>();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        cubit.onFullNameUnfocused();
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
    final fullNameError = context.select(
      (SignUpCubit cubit) => cubit.state.fullName.errorMessage,
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
      hintText: context.l10n.fullNameText,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      autofillHints: const [AutofillHints.givenName],
      enabled: !isLoading,
      prefixIcon: Icon(
        Icons.person_outline_rounded,
        color: isDark ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.8),
        size: 22,
      ),
      enabledBorder: inputBorder,
      focusedBorder: focusedInputBorder,
      onChanged: (v) => context.read<SignUpCubit>().onFullNameChanged(v),
      errorText: fullNameError,
      errorMaxLines: 3,
    );
  }
}
