import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/local_cache_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the on-device Hive cache (local DB) before the app renders.
  await LocalCacheService.init();

  // Firebase.initializeApp() is intentionally deferred: run `flutterfire
  // configure` to generate firebase_options.dart, then initialize here.
  runApp(const ProviderScope(child: VibeApp()));
}
