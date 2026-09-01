import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/local_preferences_store.dart';
import 'app/providers.dart';
import 'core/app_config.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!AppConfig.hasFirebaseConfiguration) {
    return;
  }
  await Firebase.initializeApp(options: AppConfig.currentFirebaseOptions);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.hasFirebaseConfiguration) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  final bootstrap = await AppBootstrap.initialize();
  final sharedPreferences = await SharedPreferences.getInstance();
  final localPreferencesStore = LocalPreferencesStore(sharedPreferences);

  runApp(
    ProviderScope(
      overrides: [bootstrapProvider.overrideWithValue(bootstrap), localPreferencesStoreProvider.overrideWithValue(localPreferencesStore)],
      child: const ShardPayApp(),
    ),
  );
}
