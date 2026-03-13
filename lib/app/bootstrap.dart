import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/app_config.dart';
import '../repositories/app_repository.dart';
import '../repositories/firebase/firebase_app_repository.dart';
import '../repositories/mock/mock_app_repository.dart';

class AppBootstrap {
  const AppBootstrap({
    required this.repository,
    required this.firebaseReady,
    required this.backendLabel,
  });

  final AppRepository repository;
  final bool firebaseReady;
  final String backendLabel;

  static Future<AppBootstrap> initialize() async {
    if (!AppConfig.hasFirebaseConfiguration) {
      return AppBootstrap(
        repository: MockAppRepository(),
        firebaseReady: false,
        backendLabel: 'demo-local',
      );
    }

    try {
      await Firebase.initializeApp(options: AppConfig.currentFirebaseOptions);

      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      return AppBootstrap(
        repository: FirebaseAppRepository(
          auth: FirebaseAuth.instance,
          firestore: FirebaseFirestore.instance,
          googleSignIn: GoogleSignIn(
            scopes: const ['email'],
            serverClientId: AppConfig.googleServerClientId.isEmpty ? null : AppConfig.googleServerClientId,
            clientId: AppConfig.googleIosClientId.isEmpty ? null : AppConfig.googleIosClientId,
          ),
        ),
        firebaseReady: true,
        backendLabel: 'firebase',
      );
    } catch (_) {
      return AppBootstrap(
        repository: MockAppRepository(),
        firebaseReady: false,
        backendLabel: 'demo-fallback',
      );
    }
  }
}