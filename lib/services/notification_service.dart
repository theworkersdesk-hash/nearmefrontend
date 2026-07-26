import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// FCM push handling (Phase 6). Requests permission, registers the device
/// token with the backend, and routes taps to the relevant screen.
///
/// Call [init] after `Firebase.initializeApp()` (once firebase_options.dart is
/// generated via `flutterfire configure`).
class NotificationService {
  NotificationService(this._api);
  final ApiService _api;

  final _messaging = FirebaseMessaging.instance;

  /// Emits the notification `data` payload when a push is tapped so the app
  /// can navigate (connection_request, connection_accepted, chat_message,
  /// event_reminder).
  final ValueNotifier<Map<String, dynamic>?> onTapPayload = ValueNotifier(null);

  Future<void> init() async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    if (token != null) await _registerToken(token);
    _messaging.onTokenRefresh.listen(_registerToken);

    // Foreground messages surface as in-app banners (handled by the UI layer).
    FirebaseMessaging.onMessage.listen((msg) => onTapPayload.value = null);

    // Background tap → deliver payload for navigation.
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      onTapPayload.value = msg.data;
    });

    // Cold start from a notification tap.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) onTapPayload.value = initial.data;
  }

  Future<void> _registerToken(String token) async {
    try {
      await _api.put('/users/me/fcm-token', data: {'fcmToken': token});
    } catch (_) {
      // Non-fatal: retried on next token refresh / app launch.
    }
  }
}
