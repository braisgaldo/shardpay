import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AppConfig {
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const firebaseAndroidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const firebaseIosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: 'com.ghatostudio.shardpay');
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool get hasFirebaseConfiguration {
    if (firebaseApiKey.isEmpty || firebaseProjectId.isEmpty || firebaseMessagingSenderId.isEmpty) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return firebaseAndroidAppId.isNotEmpty;
      case TargetPlatform.iOS:
        return firebaseIosAppId.isNotEmpty;
      default:
        return false;
    }
  }

  static FirebaseOptions get currentFirebaseOptions {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return FirebaseOptions(
          apiKey: firebaseApiKey,
          appId: firebaseAndroidAppId,
          messagingSenderId: firebaseMessagingSenderId,
          projectId: firebaseProjectId,
          storageBucket: firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
        );
      case TargetPlatform.iOS:
        return FirebaseOptions(
          apiKey: firebaseApiKey,
          appId: firebaseIosAppId,
          messagingSenderId: firebaseMessagingSenderId,
          projectId: firebaseProjectId,
          storageBucket: firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
          iosBundleId: firebaseIosBundleId,
        );
      default:
        throw UnsupportedError('ShardPay solo está preparado aquí para Android/iOS.');
    }
  }
}