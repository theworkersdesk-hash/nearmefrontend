import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/hloppl_button.dart';

/// Navigation args for the OTP screen: verify email first, then phone.
class OtpArgs {
  const OtpArgs({required this.email, required this.phone});
  final String email;
  final String phone;
}

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, required this.args});
  final OtpArgs args;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

enum _Step { email, phone }

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _pinController = TextEditingController();
  _Step _step = _Step.email;
  int _secondsLeft = AppConstants.otpResendSeconds;
  Timer? _timer;

  String get _identifier =>
      _step == _Step.email ? widget.args.email : widget.args.phone;
  String get _type => _step == _Step.email ? 'email' : 'phone';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
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

  Future<void> _verify() async {
    final code = _pinController.text.trim();
    if (code.length != AppConstants.otpLength) return;

    final bothVerified = await ref.read(authProvider.notifier).verifyOtp(
          identifier: _identifier,
          otp: code,
          type: _type,
        );
    if (!mounted) return;

    final error = ref.read(authProvider).error;
    if (error != null) {
      _snack(error);
      return;
    }

    if (_step == _Step.email && !bothVerified) {
      // Email done → move to phone step. Router handles final redirect when
      // both are verified (session established).
      setState(() {
        _step = _Step.phone;
        _pinController.clear();
      });
      _startTimer();
      _snack('Email verified. Now verify your phone.');
    }
    // When bothVerified becomes true, AuthStatus flips and the router
    // redirects to profile setup automatically.
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    final ok = await ref
        .read(authProvider.notifier)
        .sendOtp(identifier: _identifier, type: _type);
    if (!mounted) return;
    if (ok) {
      _startTimer();
      _snack('A new code has been sent.');
    } else {
      _snack(ref.read(authProvider).error ?? 'Could not resend code');
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Mask the identifier for display, e.g. alex***@example.com / +9198***4321.
  String get _masked {
    final id = _identifier;
    if (id.contains('@')) {
      final parts = id.split('@');
      final name = parts[0];
      final shown = name.length <= 3 ? name : name.substring(0, 3);
      return '$shown***@${parts[1]}';
    }
    if (id.length <= 6) return id;
    return '${id.substring(0, id.length - 4).replaceRange(3, id.length - 4, '***')}${id.substring(id.length - 4)}';
  }

  String get _mmss {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider.select((s) => s.isLoading));

    final defaultPin = PinTheme(
      width: 48,
      height: 56,
      textStyle: Theme.of(context).textTheme.titleLarge,
      decoration: BoxDecoration(
        color: const Color(0xFFEFE9F8),
        borderRadius: BorderRadius.circular(14),
      ),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.surfaceGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Shield badge.
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.verified_user,
                      color: AppColors.primary, size: 30),
                ),
                const SizedBox(height: 20),
                Text('Verify your identity',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: 'We\'ve sent a 6-digit verification code to\n',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.mutedText),
                    children: [
                      TextSpan(
                        text: _masked,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                _StepIndicator(step: _step),
                const SizedBox(height: 24),
                // White card with the pin input + verify button.
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Pinput(
                        length: AppConstants.otpLength,
                        controller: _pinController,
                        defaultPinTheme: defaultPin,
                        focusedPinTheme: defaultPin.copyWith(
                          decoration: defaultPin.decoration!.copyWith(
                            border: Border.all(
                                color: AppColors.primary, width: 1.5),
                          ),
                        ),
                        onCompleted: (_) => _verify(),
                      ),
                      const SizedBox(height: 24),
                      HlopplButton(
                        label: 'Verify Identity',
                        trailingIcon: Icons.arrow_forward,
                        isLoading: isLoading,
                        onPressed: _verify,
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 12),
                      Text("Didn't receive the code?",
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.mutedText)),
                      const SizedBox(height: 6),
                      _secondsLeft > 0
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.access_time,
                                    size: 15, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text('Resend code in $_mmss',
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600)),
                              ],
                            )
                          : TextButton(
                              onPressed: _resend,
                              child: const Text('Resend code')),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to sign up'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(active: true, label: 'Email'),
        Container(width: 24, height: 2, color: AppColors.border),
        _dot(active: step == _Step.phone, label: 'Phone'),
      ],
    );
  }

  Widget _dot({required bool active, required String label}) {
    return Row(
      children: [
        CircleAvatar(
          radius: 5,
          backgroundColor: active ? AppColors.primary : AppColors.disabled,
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
      ],
    );
  }
}
