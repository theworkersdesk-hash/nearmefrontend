/// App-wide constants. API base URL is injected at build/run time via
/// `--dart-define=API_BASE_URL=...` so URLs are never hardcoded per flavor.
class AppConstants {
  const AppConstants._();

  /// Backend base URL. Defaults to production; override for local dev via
  /// `--dart-define=API_BASE_URL=http://10.0.2.2:3000` (Android emulator),
  /// `http://localhost:3000` (iOS sim / web), or `http://<lan-ip>:3000` (device).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nearme.theworkersdesk.tech',
  );

  static const String apiPrefix = '/api';

  // Discovery defaults.
  static const double defaultRadiusKm = 5;
  static const double minRadiusKm = 1;
  static const double maxRadiusKm = 50;

  // OTP.
  static const int otpLength = 6;
  static const int otpResendSeconds = 60;

  // Profile.
  static const int minInterests = 3;
  static const int maxBioLength = 500;

  /// Predefined interest tags (matches plan.md).
  static const List<String> interestTags = [
    'Music',
    'Sports',
    'Technology',
    'Art',
    'Travel',
    'Food',
    'Gaming',
    'Reading',
    'Fitness',
    'Photography',
    'Movies',
    'Nature',
    'Cooking',
    'Dance',
    'Yoga',
    'Meditation',
    'Volunteering',
    'Fashion',
    'Pets',
    'Writing',
    'Comedy',
    'Podcasts',
    'Gardening',
    'DIY',
    'Cycling',
    'Running',
    'Swimming',
    'Coding',
    'Languages',
    'Board Games',
  ];
}
