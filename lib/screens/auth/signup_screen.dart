import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/common/hloppl_button.dart';
import '../../widgets/common/hloppl_text_field.dart';
import 'otp_verification_screen.dart';

/// "Join hloppl" — email + phone + T&C, dispatches dual OTP on submit.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  static const _countryCode = '+91';

  bool _isAdult = false;
  bool _agreeTerms = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isAdult || !_agreeTerms) {
      _snack('Please confirm you are 18+ and agree to the Terms');
      return;
    }
    final email = _email.text.trim();
    final phone = '$_countryCode${_phone.text.replaceAll(RegExp(r'\s+'), '')}';

    final tempId = await ref.read(authProvider.notifier).signup(
          email: email,
          phone: phone,
          password: _password.text,
        );

    if (!mounted) return;
    final error = ref.read(authProvider).error;
    if (tempId == null || error != null) {
      _snack(error ?? 'Signup failed');
      return;
    }
    context.push(
      Routes.otp,
      extra: OtpArgs(email: email, phone: phone),
    );
  }

  Future<void> _googleSignIn() async {
    final flow = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    if (flow == GoogleFlow.needsPhone) {
      context.push(Routes.googlePhone); // new user → verify a phone
    } else if (flow == GoogleFlow.failed && ref.read(authProvider).error != null) {
      _snack(ref.read(authProvider).error!);
    }
    // GoogleFlow.done → router redirects based on AuthStatus.
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider.select((s) => s.isLoading));

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('hloppl',
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(color: AppColors.primary)),
                    TextButton(
                      onPressed: () => context.go(Routes.login),
                      child: const Text('Already a member? Log in'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Join hloppl',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text('Start your journey to meaningful connections nearby.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 28),
                HlopplTextField(
                  label: 'Email Address',
                  hint: 'name@example.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 18),
                HlopplTextField(
                  label: 'Phone Number',
                  hint: '98XXX XXXXX',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                  inputPrefixText: _countryCode,
                ),
                const SizedBox(height: 18),
                HlopplTextField(
                  label: 'Password',
                  hint: 'Create a strong password',
                  controller: _password,
                  obscureText: _obscure,
                  validator: Validators.password,
                  suffix: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 12),
                _CheckRow(
                  value: _isAdult,
                  onChanged: (v) => setState(() => _isAdult = v),
                  label: 'I am 18 years or older',
                ),
                _CheckRow(
                  value: _agreeTerms,
                  onChanged: (v) => setState(() => _agreeTerms = v),
                  label: 'I agree to the Terms of Policy',
                ),
                const SizedBox(height: 20),
                HlopplButton(
                  label: 'Get Started',
                  trailingIcon: Icons.arrow_forward,
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 24),
                const _OrDivider(text: 'OR JOIN WITH'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: HlopplButton(
                        label: 'Google',
                        variant: HlopplButtonVariant.outline,
                        onPressed: _googleSignIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: HlopplButton(
                        label: 'Apple',
                        variant: HlopplButtonVariant.outline,
                        onPressed: () =>
                            _snack('Apple sign-in — configure to enable'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'By tapping Get Started you agree to our Terms of Service and Privacy Policy.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(
      {required this.value, required this.onChanged, required this.label});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.primary,
          ),
          Expanded(
              child:
                  Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
