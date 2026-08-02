import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/local_cache_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the on-device Hive cache (local DB) before the app renders.
  await LocalCacheService.init();

  // Firebase (Google Sign-In, FCM, Storage). firebase_options.dart is generated
  // by `flutterfire configure`. Guarded so a misconfig doesn't block startup.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase init skipped/failed: $e');
  }

  runApp(const ProviderScope(child: VibeApp()));
}
