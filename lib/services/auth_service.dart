import '../models/user_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Auth-specific API calls layered on [ApiService]. Persists tokens on the
/// flows that return them (verify-otp when both channels verified, login,
/// google-signin).
class AuthService {
  AuthService(this._api, this._storage);

  final ApiService _api;
  final StorageService _storage;

  /// Returns the temp user id; OTPs are dispatched to email + phone.
  Future<String> signup({
    required String email,
    required String phone,
    required String password,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/signup',
      skipAuth: true,
      data: {'email': email, 'phone': phone, 'password': password},
    );
    return data['tempUserId'] as String;
  }

  Future<void> sendOtp(
      {required String identifier, required String type}) async {
    await _api.post<Map<String, dynamic>>(
      '/auth/send-otp',
      skipAuth: true,
      data: {'identifier': identifier, 'type': type},
    );
  }

  /// Verifies one OTP channel. When [bothVerified] is true, tokens are stored
  /// and the [UserModel] is returned.
  Future<VerifyOtpResult> verifyOtp({
    required String identifier,
    required String otp,
    required String type,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/verify-otp',
      skipAuth: true,
      data: {'identifier': identifier, 'otp': otp, 'type': type},
    );
    final bothVerified = data['bothVerified'] as bool? ?? false;
    if (bothVerified && data['tokens'] != null) {
      await _persist(data['tokens'] as Map<String, dynamic>);
    }
    return VerifyOtpResult(
      bothVerified: bothVerified,
      user: data['user'] != null
          ? UserModel.fromJson(data['user'] as Map<String, dynamic>)
          : null,
    );
  }

  Future<void> forgotPassword(
      {required String identifier, required String type}) async {
    await _api.post<Map<String, dynamic>>(
      '/auth/forgot-password',
      skipAuth: true,
      data: {'identifier': identifier, 'type': type},
    );
  }

  Future<void> resetPassword({
    required String identifier,
    required String type,
    required String otp,
    required String newPassword,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/auth/reset-password',
      skipAuth: true,
      data: {
        'identifier': identifier,
        'type': type,
        'otp': otp,
        'newPassword': newPassword
      },
    );
  }

  Future<UserModel> login(
      {required String identifier, required String password}) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      skipAuth: true,
      data: {'identifier': identifier, 'password': password},
    );
    await _persist(data['tokens'] as Map<String, dynamic>);
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<UserModel> googleSignIn(
      {required String idToken, String? phone}) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/google-signin',
      skipAuth: true,
      data: {'idToken': idToken, if (phone != null) 'phone': phone},
    );
    await _persist(data['tokens'] as Map<String, dynamic>);
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _api.post<Map<String, dynamic>>('/auth/logout');
    } finally {
      await _storage.clear();
    }
  }

  Future<UserModel> fetchMe() async {
    final data = await _api.get<Map<String, dynamic>>('/users/me');
    return UserModel.fromJson(data);
  }

  /// Profile setup / edit. Only non-null fields are sent.
  Future<UserModel> updateProfile({
    String? fullName,
    int? age,
    String? gender,
    String? bio,
    List<String>? interests,
    String? profilePhotoUrl,
  }) async {
    final data = await _api.put<Map<String, dynamic>>('/users/me', data: {
      if (fullName != null) 'fullName': fullName,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (bio != null) 'bio': bio,
      if (interests != null) 'interests': interests,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
    });
    return UserModel.fromJson(data);
  }

  Future<bool> hasSession() async => (await _storage.accessToken) != null;

  Future<void> _persist(Map<String, dynamic> tokens) async {
    await _storage.saveTokens(
      access: tokens['accessToken'] as String,
      refresh: tokens['refreshToken'] as String,
    );
  }
}

class VerifyOtpResult {
  const VerifyOtpResult({required this.bothVerified, this.user});
  final bool bothVerified;
  final UserModel? user;
}
