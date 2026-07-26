import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/api_exception.dart';
import 'providers.dart';

/// High-level authentication status used by the router to gate screens.
enum AuthStatus {
  unknown, // still resolving persisted session at startup
  unauthenticated,
  needsProfile, // authenticated but profile-setup incomplete
  authenticated,
}

@immutable
class AuthState {
  const AuthState(
      {this.status = AuthStatus.unknown,
      this.user,
      this.isLoading = false,
      this.error});

  final AuthStatus status;
  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns the authentication state machine and exposes the Phase-1 flows.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    _bootstrap();
  }

  final Ref _ref;

  Future<void> _bootstrap() async {
    final auth = _ref.read(authServiceProvider);
    // Route back to login if a refresh ultimately fails mid-session.
    _ref.read(apiServiceProvider).onSessionExpired = () {
      state = const AuthState(status: AuthStatus.unauthenticated);
    };

    if (!await auth.hasSession()) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await auth.fetchMe();
      state = state.copyWith(status: _statusForUser(user), user: user);
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  AuthStatus _statusForUser(UserModel user) => user.hasCompletedProfile
      ? AuthStatus.authenticated
      : AuthStatus.needsProfile;

  Future<T?> _guard<T>(Future<T> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await action();
      state = state.copyWith(isLoading: false);
      return result;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return null;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Something went wrong');
      return null;
    }
  }

  /// Returns the temp user id on success, or null on failure (see state.error).
  Future<String?> signup({
    required String email,
    required String phone,
    required String password,
  }) {
    return _guard(() => _ref.read(authServiceProvider).signup(
          email: email,
          phone: phone,
          password: password,
        ));
  }

  Future<bool> sendOtp(
      {required String identifier, required String type}) async {
    await _guard(
      () => _ref
          .read(authServiceProvider)
          .sendOtp(identifier: identifier, type: type),
    );
    return state.error == null;
  }

  /// Returns true when both channels are now verified (session established).
  Future<bool> verifyOtp({
    required String identifier,
    required String otp,
    required String type,
  }) async {
    final result = await _guard(
      () => _ref
          .read(authServiceProvider)
          .verifyOtp(identifier: identifier, otp: otp, type: type),
    );
    if (result == null) return false;
    if (result.bothVerified && result.user != null) {
      state = state.copyWith(
          status: _statusForUser(result.user!), user: result.user);
    }
    return result.bothVerified;
  }

  /// Request a password-reset code. Returns true on success (see state.error).
  Future<bool> forgotPassword(
      {required String identifier, required String type}) async {
    await _guard(
      () => _ref
          .read(authServiceProvider)
          .forgotPassword(identifier: identifier, type: type),
    );
    return state.error == null;
  }

  /// Reset the password with the code. Returns true on success.
  Future<bool> resetPassword({
    required String identifier,
    required String type,
    required String otp,
    required String newPassword,
  }) async {
    await _guard(
      () => _ref.read(authServiceProvider).resetPassword(
            identifier: identifier,
            type: type,
            otp: otp,
            newPassword: newPassword,
          ),
    );
    return state.error == null;
  }

  Future<bool> login(
      {required String identifier, required String password}) async {
    final user = await _guard(
      () => _ref
          .read(authServiceProvider)
          .login(identifier: identifier, password: password),
    );
    if (user == null) return false;
    state = state.copyWith(status: _statusForUser(user), user: user);
    return true;
  }

  /// Google Sign-In: runs the native flow → Firebase ID token → backend.
  /// Returns false on cancel/error (see state.error).
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final idToken = await _ref.read(googleAuthServiceProvider).signIn();
      if (idToken == null) {
        state = state.copyWith(isLoading: false); // user cancelled
        return false;
      }
      final user =
          await _ref.read(authServiceProvider).googleSignIn(idToken: idToken);
      state = state.copyWith(
          isLoading: false, status: _statusForUser(user), user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Google sign-in unavailable. Configure Firebase to enable it.',
      );
      return false;
    }
  }

  /// Submit profile-setup details. On success flips status to authenticated.
  Future<bool> completeProfile({
    required String fullName,
    required int age,
    required String gender,
    required List<String> interests,
    String? bio,
  }) async {
    final user = await _guard(
      () => _ref.read(authServiceProvider).updateProfile(
            fullName: fullName,
            age: age,
            gender: gender,
            interests: interests,
            bio: bio,
          ),
    );
    if (user == null) return false;
    state = state.copyWith(status: AuthStatus.authenticated, user: user);
    return true;
  }

  /// Upload a cropped avatar file; refreshes the cached user on success.
  Future<bool> uploadAvatar(String filePath) async {
    final url = await _guard(
      () => _ref.read(imageServiceProvider).uploadAvatar(filePath),
    );
    if (url == null) return false;
    final user = await _ref.read(authServiceProvider).fetchMe();
    state = state.copyWith(user: user);
    return true;
  }

  /// Edit an existing profile (keeps status authenticated).
  Future<bool> updateProfile({
    String? fullName,
    int? age,
    String? gender,
    List<String>? interests,
    String? bio,
  }) async {
    final user = await _guard(
      () => _ref.read(authServiceProvider).updateProfile(
            fullName: fullName,
            age: age,
            gender: gender,
            interests: interests,
            bio: bio,
          ),
    );
    if (user == null) return false;
    state = state.copyWith(user: user);
    return true;
  }

  Future<void> logout() async {
    await _ref
        .read(authServiceProvider)
        .logout(); // clears FCM token server-side
    _ref.read(socketServiceProvider).dispose(); // tear down the authed socket
    await _ref.read(localCacheProvider).clear(); // drop cached read models
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
