import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/local_preferences_store.dart';
import 'app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await AppBootstrap.initialize();
  final sharedPreferences = await SharedPreferences.getInstance();
  final localPreferencesStore = LocalPreferencesStore(sharedPreferences);

  runApp(
    ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(bootstrap),
        localPreferencesStoreProvider.overrideWithValue(localPreferencesStore),
      ],
      child: const ShardPayApp(),
    ),
  );
}
