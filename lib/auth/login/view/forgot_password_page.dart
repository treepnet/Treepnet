import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

/// {@template forgot_password_page}
/// Password recovery in three steps on one screen: identify the account, type
/// the code that was emailed, then choose a new password.
/// {@endtemplate}
class ForgotPasswordPage extends StatefulWidget {
  /// {@macro forgot_password_page}
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

enum _Step { identify, verify, done }

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _identifier = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  _Step _step = _Step.identify;
  String? _continuationToken;
  int _codeLength = 6;
  bool _busy = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  UserRepository get _users => context.read<UserRepository>();

  Future<void> _sendCode() async {
    final id = _identifier.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Enter your username or email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _users.resetPasswordSendCode(usernameOrEmail: id);
      if (!mounted) return;
      setState(() {
        _continuationToken = result.continuationToken;
        _codeLength = result.codeLength;
        _step = _Step.verify;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    final password = _password.text;
    if (code.length < _codeLength) {
      setState(() => _error = 'Enter the $_codeLength-digit code.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _users.resetPasswordSubmit(
        continuationToken: _continuationToken!,
        code: code,
        newPassword: password,
      );
      if (!mounted) return;
      setState(() => _step = _Step.done);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _message(Object error) {
    final text = error.toString();
    // Transport failures surface as a wall of Dio/HttpException detail; say
    // something a person can act on instead.
    if (text.contains('DioException') ||
        text.contains('SocketException') ||
        text.contains('HttpException') ||
        text.contains('connection abort')) {
      return l10nGlobal.networkProblemText;
    }
    // The failures carry a friendly sentence; strip the wrapper noise.
    final match = RegExp(r'\((.+)\)$', dotAll: true).firstMatch(text);
    final inner = match?.group(1) ?? text;
    return inner.replaceAll('Instance of ', '').trim();
  }

  @override
  Widget build(BuildContext context) {
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: AppColors.transparent,
        releaseFocus: true,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: AppColors.transparent,
          surfaceTintColor: AppColors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            context.l10n.resetPasswordText,
            style: context.titleMedium?.copyWith(
              fontWeight: AppFontWeight.semiBold,
            ),
          ),
        ),
        body: AuthShell(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (_step) {
            _Step.identify => _identifyStep(),
            _Step.verify => _verifyStep(),
            _Step.done => _doneStep(),
          },
        ),
      ),
    );
  }

  Widget _identifyStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.forgotPasswordSubtitleText,
        style: context.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      const Gap.v(AppSpacing.lg),
      _field(
        controller: _identifier,
        hint: context.l10n.usernameOrEmailText,
        icon: Icons.alternate_email,
      ),
      if (_error != null) _errorText(),
      const Gap.v(AppSpacing.lg),
      _primaryButton(label: context.l10n.sendCodeText, onTap: _sendCode),
    ],
  );

  Widget _verifyStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.emailedCodeText(_codeLength),
        style: context.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      const Gap.v(AppSpacing.lg),
      _field(
        controller: _code,
        hint: context.l10n.codeText,
        icon: Icons.mark_email_read_outlined,
        keyboardType: TextInputType.number,
      ),
      const Gap.v(AppSpacing.md),
      _field(
        controller: _password,
        hint: context.l10n.newPasswordText,
        icon: Icons.lock_outline,
        obscure: _obscure,
        suffix: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.white,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      if (_error != null) _errorText(),
      const Gap.v(AppSpacing.lg),
      _primaryButton(label: context.l10n.changePasswordText, onTap: _submit),
      const Gap.v(AppSpacing.md),
      TextButton(
        onPressed: _busy ? null : _sendCode,
        child: Text(context.l10n.sendCodeAgainText),
      ),
    ],
  );

  Widget _doneStep() => Column(
    children: [
      const Gap.v(AppSpacing.xlg),
      const Icon(Icons.check_circle, color: AppColors.success, size: 72),
      const Gap.v(AppSpacing.lg),
      Text(
        context.l10n.passwordChangedText,
        style: context.titleLarge?.copyWith(fontWeight: AppFontWeight.bold),
      ),
      const Gap.v(AppSpacing.sm),
      Text(
        context.l10n.passwordChangedDescriptionText,
        textAlign: TextAlign.center,
        style: context.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      const Gap.v(AppSpacing.xlg),
      _primaryButton(
        label: context.l10n.backToLoginText,
        onTap: () async => Navigator.of(context).maybePop(),
      ),
    ],
  );

  Widget _errorText() => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Text(
      _error!,
      style: context.bodyMedium?.copyWith(color: AppColors.red),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    enabled: !_busy,
    style: const TextStyle(color: AppColors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.grey),
      prefixIcon: Icon(icon, color: AppColors.white),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.inputSpace,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.white),
      ),
    ),
  );

  Widget _primaryButton({
    required String label,
    required Future<void> Function() onTap,
  }) => Tappable.scaled(
    onTap: _busy ? null : onTap,
    child: Container(
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _busy ? AppColors.inputSpace : AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _busy
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              label,
              style: context.labelLarge?.copyWith(
                color: AppColors.black,
                fontWeight: AppFontWeight.semiBold,
              ),
            ),
    ),
  );
}
