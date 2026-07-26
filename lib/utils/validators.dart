/// Client-side form validators mirroring backend Zod rules so users get fast
/// feedback before hitting the API.
class Validators {
  const Validators._();

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _passwordRe =
      RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailRe.hasMatch(v)) return 'Enter a valid email';
    return null;
  }

  /// Expects the national number; combined with country code before submit.
  static String? phone(String? value) {
    final v = value?.replaceAll(RegExp(r'\s+'), '') ?? '';
    if (v.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^\d{6,14}$').hasMatch(v)) return 'Enter a valid phone number';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (!_passwordRe.hasMatch(v)) {
      return 'Min 8 chars with an uppercase, number & special character';
    }
    return null;
  }

  static String? required(String? value, [String field = 'This field']) {
    if ((value?.trim() ?? '').isEmpty) return '$field is required';
    return null;
  }

  static String? age(String? value) {
    final n = int.tryParse(value?.trim() ?? '');
    if (n == null) return 'Enter your age';
    if (n < 18) return 'You must be 18 or older';
    if (n > 120) return 'Enter a valid age';
    return null;
  }

  static String? loginIdentifier(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email or phone';
    return null;
  }

  static String? latitude(String? value) {
    final n = double.tryParse(value?.trim() ?? '');
    if (n == null) return 'Enter a latitude';
    if (n < -90 || n > 90) return 'Latitude must be between -90 and 90';
    return null;
  }

  static String? longitude(String? value) {
    final n = double.tryParse(value?.trim() ?? '');
    if (n == null) return 'Enter a longitude';
    if (n < -180 || n > 180) return 'Longitude must be between -180 and 180';
    return null;
  }

  static String? url(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'This field is required';
    final uri = Uri.tryParse(v);
    if (uri == null ||
        !uri.isAbsolute ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return 'Enter a valid URL (https://…)';
    }
    return null;
  }

  static String? minLength(String? value, int min,
      [String field = 'This field']) {
    if ((value?.trim().length ?? 0) < min) {
      return '$field must be at least $min characters';
    }
    return null;
  }
}
