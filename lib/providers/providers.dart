import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/connection_service.dart';
import '../services/discover_service.dart';
import '../services/event_service.dart';
import '../services/google_auth_service.dart';
import '../services/image_service.dart';
import '../services/local_cache_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';
import '../services/support_service.dart';

/// Dependency-injection providers. Wiring lives here so services stay testable
/// (override these in tests with fakes).
final storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(storageServiceProvider));
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
      ref.watch(apiServiceProvider), ref.watch(storageServiceProvider));
});

final localCacheProvider =
    Provider<LocalCacheService>((ref) => LocalCacheService.instance);

final discoverServiceProvider = Provider<DiscoverService>(
    (ref) => DiscoverService(ref.watch(apiServiceProvider)));

final connectionServiceProvider = Provider<ConnectionService>(
    (ref) => ConnectionService(ref.watch(apiServiceProvider)));

final chatServiceProvider =
    Provider<ChatService>((ref) => ChatService(ref.watch(apiServiceProvider)));

final eventServiceProvider = Provider<EventService>(
    (ref) => EventService(ref.watch(apiServiceProvider)));

final locationServiceProvider = Provider<LocationService>(
    (ref) => LocationService(ref.watch(apiServiceProvider)));

final imageServiceProvider = Provider<ImageService>(
    (ref) => ImageService(ref.watch(apiServiceProvider)));

final googleAuthServiceProvider =
    Provider<GoogleAuthService>((ref) => GoogleAuthService());

final notificationServiceProvider = Provider<NotificationService>(
    (ref) => NotificationService(ref.watch(apiServiceProvider)));

final supportServiceProvider = Provider<SupportService>(
    (ref) => SupportService(ref.watch(apiServiceProvider)));

final socketServiceProvider = Provider<SocketService>((ref) {
  final socket = SocketService(ref.watch(storageServiceProvider));
  ref.onDispose(socket.dispose);
  return socket;
});
