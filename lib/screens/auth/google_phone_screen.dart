import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/common/vibe_button.dart';
import '../../widgets/common/vibe_text_field.dart';

/// Completes Google sign-up for a NEW user: collect a phone, OTP-verify it, then
/// the account is created (Firebase email is already verified). On success the
/// router redirects to profile setup (needsProfile).
class GooglePhoneScreen extends ConsumerStatefulWidget {
  const GooglePhoneScreen({super.key});

  @override
  ConsumerState<GooglePhoneScreen> createState() => _GooglePhoneScreenState();
}

enum _Step { phone, otp }

class _GooglePhoneScreenState extends ConsumerState<GooglePhoneScreen> {
  final _phoneKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  static const _countryCode = '+91';

  _Step _step = _Step.phone;
  int _secondsLeft = 0;
  Timer? _timer;

  String get _fullPhone => '$_countryCode${_phone.text.replaceAll(RegExp(r'\s+'), '')}';

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = AppConstants.otpResendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _sendCode() async {
    if (!_phoneKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).googleSendOtp(_fullPhone);
    if (!mounted) return;
    if (ok) {
      setState(() => _step = _Step.otp);
      _startTimer();
      _snack('Code sent to $_fullPhone');
    } else {
      _snack(ref.read(authProvider).error ?? 'Could not send code');
    }
  }

  Future<void> _verify() async {
    if (_otp.text.trim().length != AppConstants.otpLength) return;
    final ok = await ref.read(authProvider.notifier).googleVerify(_fullPhone, _otp.text.trim());
    if (!mounted) return;
    if (!ok) _snack(ref.read(authProvider).error ?? 'Verification failed');
    // On success the router redirects to profile setup automatically.
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider.select((s) => s.isLoading));
    final email = ref.watch(authProvider.notifier).pendingGoogleEmail;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.login),
        ),
        title: const Text('Complete sign-up'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _step == _Step.phone ? _phoneStep(context, email, isLoading) : _otpStep(context, isLoading),
        ),
      ),
    );
  }

  Widget _phoneStep(BuildContext context, String? email, bool isLoading) {
    return Form(
      key: _phoneKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Add your phone', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            email != null
                ? 'Signed in with $email. Verify a phone number to finish creating your account.'
                : 'Verify a phone number to finish creating your account.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          VibeTextField(
            label: 'Phone Number',
            hint: '98XXX XXXXX',
            controller: _phone,
            keyboardType: TextInputType.phone,
            validator: Validators.phone,
            inputPrefixText: _countryCode,
          ),
          const SizedBox(height: 24),
          VibeButton(
            label: 'Send Code',
            trailingIcon: Icons.arrow_forward,
            isLoading: isLoading,
            onPressed: _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _otpStep(BuildContext context, bool isLoading) {
    final pin = PinTheme(
      width: 48,
      height: 56,
      textStyle: Theme.of(context).textTheme.titleLarge,
      decoration: BoxDecoration(
        color: const Color(0xFFEFE9F8),
        borderRadius: BorderRadius.circular(14),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Verify your phone', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text('Enter the 6-digit code sent to $_fullPhone',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
        Pinput(
          length: AppConstants.otpLength,
          controller: _otp,
          defaultPinTheme: pin,
          focusedPinTheme: pin.copyWith(
            decoration: pin.decoration!.copyWith(
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
          ),
          onCompleted: (_) => _verify(),
        ),
        const SizedBox(height: 24),
        VibeButton(label: 'Verify & Continue', isLoading: isLoading, onPressed: _verify),
        const SizedBox(height: 12),
        Center(
          child: _secondsLeft > 0
              ? Text('Resend code in ${_secondsLeft}s',
                  style: Theme.of(context).textTheme.bodySmall)
              : TextButton(onPressed: _sendCode, child: const Text('Resend code')),
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _step = _Step.phone),
            child: const Text('Use a different number'),
          ),
        ),
      ],
    );
  }
}
