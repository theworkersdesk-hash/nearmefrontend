import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed local cache — the frontend's on-device DB. Used as a fast first
/// layer for read models (discover feed, events, conversations, current user)
/// so the app renders instantly on launch and degrades gracefully offline.
///
/// Pattern mirrors the backend's Redis cache-aside: read local first (if
/// fresh), fetch from the API, then write back with a timestamp/TTL.
class LocalCacheService {
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();

  static const _boxName = 'vibe_cache';
  static const _prefsBoxName = 'vibe_prefs';
  static const _kOnboardingSeen = 'onboarding_seen';

  Box<String>? _box;
  Box<String>? _prefs;

  /// Call once at startup (see main.dart) before any read/write.
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_boxName);
    await Hive.openBox<String>(_prefsBoxName);
  }

  Box<String> get _b => _box ??= Hive.box<String>(_boxName);

  /// Durable prefs box — NOT wiped by [clear] (survives logout).
  Box<String> get _p => _prefs ??= Hive.box<String>(_prefsBoxName);

  // ── Onboarding (first-launch) flag ──────────────────────────
  bool get hasSeenOnboarding => _p.get(_kOnboardingSeen) == 'true';
  Future<void> setOnboardingSeen() => _p.put(_kOnboardingSeen, 'true');

  /// Store a JSON-encodable value with an optional TTL.
  Future<void> put(String key, Object value, {Duration? ttl}) async {
    final envelope = {
      'ts': DateTime.now().millisecondsSinceEpoch,
      'ttl': ttl?.inMilliseconds,
      'data': value,
    };
    await _b.put(key, jsonEncode(envelope));
  }

  /// Returns the cached value if present and not expired, else null.
  T? get<T>(String key) {
    final raw = _b.get(key);
    if (raw == null) return null;
    final env = jsonDecode(raw) as Map<String, dynamic>;
    final ttl = env['ttl'] as int?;
    if (ttl != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (env['ts'] as int);
      if (age > ttl) {
        _b.delete(key);
        return null;
      }
    }
    return env['data'] as T;
  }

  /// Cache-aside helper: return fresh local value, else run [loader], cache it.
  Future<T> readThrough<T>(
    String key,
    Duration ttl,
    Future<T> Function() loader, {
    required T Function(Object cached) decode,
    required Object Function(T value) encode,
  }) async {
    final cached = get<Object>(key);
    if (cached != null) return decode(cached);
    final fresh = await loader();
    await put(key, encode(fresh), ttl: ttl);
    return fresh;
  }

  Future<void> delete(String key) => _b.delete(key);
  Future<void> clear() => _b.clear();
}
