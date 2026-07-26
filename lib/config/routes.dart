import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/splash_screen.dart';

/// Route path constants — referenced everywhere instead of string literals.
class Routes {
  const Routes._();
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const signup = '/signup';
  static const login = '/login';
  static const otp = '/otp';
  static const profileSetup = '/profile-setup';
  static const home = '/home';
}

/// Builds the app router. Redirects are driven by [AuthStatus] plus the
/// first-launch onboarding flag, so navigation has a single source of truth.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);
  // Re-evaluate redirects whenever auth status or onboarding-seen changes.
  ref.listen(authProvider.select((s) => s.status), (_, __) => refresh.bump(),
      fireImmediately: true);
  ref.listen(onboardingSeenProvider, (_, __) => refresh.bump(),
      fireImmediately: true);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: Routes.onboarding,
          builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: Routes.signup, builder: (_, __) => const SignupScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: Routes.otp,
        builder: (_, state) =>
            OtpVerificationScreen(args: state.extra as OtpArgs),
      ),
      GoRoute(
          path: Routes.profileSetup,
          builder: (_, __) => const ProfileSetupScreen()),
      GoRoute(path: Routes.home, builder: (_, __) => const HomeShell()),
    ],
    redirect: (context, state) {
      final status = ref.read(authProvider).status;
      final seenOnboarding = ref.read(onboardingSeenProvider);
      final loc = state.matchedLocation;

      // Still resolving the persisted session → hold on the splash.
      if (status == AuthStatus.unknown) {
        return loc == Routes.splash ? null : Routes.splash;
      }

      switch (status) {
        case AuthStatus.unauthenticated:
          // First launch → landing page (once). Afterwards → Sign In, but let
          // the user move freely between login/signup/otp.
          if (!seenOnboarding) {
            return loc == Routes.onboarding ? null : Routes.onboarding;
          }
          final onAuthScreens =
              {Routes.login, Routes.signup, Routes.otp}.contains(loc);
          return onAuthScreens ? null : Routes.login;

        case AuthStatus.needsProfile:
          return loc == Routes.profileSetup ? null : Routes.profileSetup;

        case AuthStatus.authenticated:
          // Logged-in users never see onboarding or auth screens.
          const transient = {
            Routes.splash,
            Routes.onboarding,
            Routes.login,
            Routes.signup,
            Routes.otp,
            Routes.profileSetup,
          };
          return transient.contains(loc) ? Routes.home : null;

        case AuthStatus.unknown:
          return Routes.splash;
      }
    },
  );
});

/// Tiny [Listenable] that GoRouter listens to; bumped on auth/onboarding change.
class _RouterRefresh extends ChangeNotifier {
  void bump() => notifyListeners();
}
