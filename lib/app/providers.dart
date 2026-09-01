import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import '../repositories/app_repository.dart';
import '../services/backup_service.dart';
import '../services/fcm_service.dart';
import '../services/local_notification_service.dart';
import '../services/receipt_storage_service.dart';
import '../services/ticket_ocr_service.dart';
import 'bootstrap.dart';
import 'local_preferences_store.dart';
import 'preferences.dart';

final bootstrapProvider = Provider<AppBootstrap>((ref) {
  throw UnimplementedError('bootstrapProvider must be overridden in main.dart');
});

final repositoryProvider = Provider<AppRepository>((ref) {
  return ref.watch(bootstrapProvider).repository;
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(repositoryProvider).authStateChanges();
});

final groupsProvider = StreamProvider.autoDispose.family<List<ExpenseGroup>, String>((ref, userId) {
  return ref.watch(repositoryProvider).watchGroups(userId);
});

final groupProvider = StreamProvider.autoDispose.family<ExpenseGroup?, String>((ref, groupId) {
  return ref.watch(repositoryProvider).watchGroup(groupId);
});

final notificationsProvider = StreamProvider.autoDispose.family<List<AppNotification>, String>((ref, userId) {
  return ref.watch(repositoryProvider).watchNotifications(userId);
});

final localNotificationServiceProvider = Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});

final fcmServiceProvider = Provider<FcmService?>((ref) {
  final bootstrap = ref.watch(bootstrapProvider);
  if (!bootstrap.firebaseReady) {
    return null;
  }

  return FcmService(
    firestore: FirebaseFirestore.instance,
    messaging: FirebaseMessaging.instance,
    localNotifications: ref.watch(localNotificationServiceProvider),
  );
});

final ticketOcrServiceProvider = Provider<TicketOcrService>((ref) {
  final service = TicketOcrService();
  ref.onDispose(service.dispose);
  return service;
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(repository: ref.watch(repositoryProvider));
});

final receiptStorageServiceProvider = Provider<ReceiptStorageService>((ref) {
  return ReceiptStorageService(enabled: ref.watch(bootstrapProvider).firebaseReady);
});

final localPreferencesStoreProvider = Provider<LocalPreferencesStore>((ref) {
  throw UnimplementedError('localPreferencesStoreProvider must be overridden in main.dart');
});

final appPreferencesProvider = StateNotifierProvider<AppPreferencesNotifier, AppPreferences>((ref) {
  return AppPreferencesNotifier(ref.watch(localPreferencesStoreProvider));
});
