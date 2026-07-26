import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Tracks whether the user has seen the first-launch landing page. Backed by
/// the durable Hive prefs box, so it persists across restarts AND logout — the
/// landing page is shown at most once per install.
class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(this._ref)
      : super(_ref.read(localCacheProvider).hasSeenOnboarding);
  final Ref _ref;

  Future<void> markSeen() async {
    await _ref.read(localCacheProvider).setOnboardingSeen();
    state = true;
  }
}

/// `true` once the landing page has been dismissed via "Get Started".
final onboardingSeenProvider = StateNotifierProvider<OnboardingNotifier, bool>(
    (ref) => OnboardingNotifier(ref));
