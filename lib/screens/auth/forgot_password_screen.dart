import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/common/hloppl_button.dart';
import '../../widgets/common/hloppl_text_field.dart';

/// Two-step password reset: (1) request a code by email, (2) enter the code +
/// a new password. Reuses the OTP infrastructure on the backend.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

enum _Step { request, reset }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _requestKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();

  _Step _step = _Step.request;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_requestKey.currentState!.validate()) return;
    final ok = await ref
        .read(authProvider.notifier)
        .forgotPassword(identifier: _email.text.trim(), type: 'email');
    if (!mounted) return;
    if (ok) {
      setState(() => _step = _Step.reset);
      _snack('If an account exists, a reset code has been sent.');
    } else {
      _snack(ref.read(authProvider).error ?? 'Could not send code');
    }
  }

  Future<void> _reset() async {
    if (!_resetKey.currentState!.validate()) return;
    if (_otp.text.trim().length != AppConstants.otpLength) {
      return _snack('Enter the 6-digit code');
    }
    final ok = await ref.read(authProvider.notifier).resetPassword(
          identifier: _email.text.trim(),
          type: 'email',
          otp: _otp.text.trim(),
          newPassword: _newPassword.text,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      _snack('Password reset. Please log in with your new password.');
    } else {
      _snack(ref.read(authProvider).error ?? 'Reset failed');
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider.select((s) => s.isLoading));

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _step == _Step.request
              ? _requestForm(isLoading)
              : _resetForm(isLoading, context),
        ),
      ),
    );
  }

  Widget _requestForm(bool isLoading) {
    return Form(
      key: _requestKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Forgot your password?',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('Enter your email and we\'ll send you a reset code.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 28),
          HlopplTextField(
            label: 'Email Address',
            hint: 'name@example.com',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          const SizedBox(height: 24),
          HlopplButton(
              label: 'Send Reset Code',
              isLoading: isLoading,
              onPressed: _sendCode),
        ],
      ),
    );
  }

  Widget _resetForm(bool isLoading, BuildContext context) {
    final pinTheme = PinTheme(
      width: 48,
      height: 54,
      textStyle: Theme.of(context).textTheme.titleLarge,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
    );

    return Form(
      key: _resetKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Enter code & new password',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('We sent a 6-digit code to ${_email.text.trim()}.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          Pinput(
            length: AppConstants.otpLength,
            controller: _otp,
            defaultPinTheme: pinTheme,
            focusedPinTheme: pinTheme.copyWith(
              decoration: pinTheme.decoration!.copyWith(
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          HlopplTextField(
            label: 'New Password',
            controller: _newPassword,
            obscureText: _obscure,
            validator: Validators.password,
            suffix: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 24),
          HlopplButton(
              label: 'Reset Password', isLoading: isLoading, onPressed: _reset),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _step = _Step.request),
              child: const Text('Use a different email'),
            ),
          ),
        ],
      ),
    );
  }
}
