import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/common/hloppl_button.dart';

/// First-launch landing page ("Find your tribe"). Shown once (flag persisted in
/// Hive) and never for a logged-in user. "Let's Get Started" → Sign In.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.surfaceGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Headline: "Find your" + script-style "tribe".
                Text(
                  'Find your',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        height: 1.0,
                      ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _Sparkles(),
                    const SizedBox(width: 8),
                    Text(
                      'tribe',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 52,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(width: 8),
                    const _Sparkles(),
                  ],
                ),
                const SizedBox(height: 20),
                // Tagline.
                Column(
                  children: [
                    Text('Real People.', style: _tagline(context)),
                    const SizedBox(height: 2),
                    Text('Real Connections.', style: _tagline(context)),
                    const SizedBox(height: 2),
                    Text('Real Life.',
                        style: _tagline(context)
                            ?.copyWith(color: AppColors.primary)),
                  ],
                ),
                const Spacer(),
                // Hero illustration.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: Image.asset('assets/images/onboarding_hero.png',
                      fit: BoxFit.contain),
                ),
                const Spacer(),
                HlopplButton(
                  label: "Let's Get Started",
                  trailingIcon: Icons.arrow_forward,
                  onPressed: () async {
                    await ref.read(onboardingSeenProvider.notifier).markSeen();
                    if (context.mounted) context.go(Routes.login);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle? _tagline(BuildContext context) => Theme.of(context)
      .textTheme
      .titleLarge
      ?.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface);
}

/// The small decorative logo-mark sparkles beside the "tribe" wordmark.
class _Sparkles extends StatelessWidget {
  const _Sparkles();
  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/images/logo_mark.svg', height: 22);
}
