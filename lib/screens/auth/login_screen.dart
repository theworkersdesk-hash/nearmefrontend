import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/common/vibe_button.dart';
import '../../widgets/common/vibe_text_field.dart';
import 'forgot_password_screen.dart';

/// Login by email OR phone + password.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
          identifier: _identifier.text.trim(),
          password: _password.text,
        );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(authProvider).error ?? 'Login failed')),
      );
    }
    // On success the router redirects based on AuthStatus.
  }

  Future<void> _googleSignIn() async {
    final ok = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    if (!ok && ref.read(authProvider).error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(authProvider).error!)),
      );
    }
  }

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
                const SizedBox(height: 24),
                Text('vibe',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(color: AppColors.primary)),
                const SizedBox(height: 24),
                Text('Welcome back',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text('Log in to continue the vibe.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 28),
                VibeTextField(
                  label: 'Email or Phone',
                  hint: 'name@example.com or +9198XXXXXXXX',
                  controller: _identifier,
                  validator: Validators.loginIdentifier,
                ),
                const SizedBox(height: 18),
                VibeTextField(
                  label: 'Password',
                  hint: 'Your password',
                  controller: _password,
                  obscureText: _obscure,
                  validator: (v) => Validators.required(v, 'Password'),
                  suffix: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen()),
                    ),
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 8),
                VibeButton(
                    label: 'Log In', isLoading: isLoading, onPressed: _submit),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR LOG IN WITH',
                          style: TextStyle(
                              color: AppColors.mutedText, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: AppColors.border)),
                  ],
                ),
                const SizedBox(height: 16),
                VibeButton(
                  label: 'Google',
                  variant: VibeButtonVariant.outline,
                  onPressed: _googleSignIn,
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text.rich(
                    TextSpan(
                      text: "Don't have an account? ",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.mutedText),
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => context.go(Routes.signup),
                            child: const Text(
                              'Create one',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
