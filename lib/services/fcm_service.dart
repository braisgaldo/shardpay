import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/app_models.dart';
import 'local_notification_service.dart';

class FcmService {
  FcmService({
    required FirebaseFirestore firestore,
    required FirebaseMessaging messaging,
    required LocalNotificationService localNotifications,
  }) : _firestore = firestore,
       _messaging = messaging,
       _localNotifications = localNotifications;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final LocalNotificationService _localNotifications;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  String? _activeUserId;

  Future<void> initializeForUser(AppUser user) async {
    if (_activeUserId == user.id) {
      return;
    }

    await dispose();
    _activeUserId = user.id;
    await _localNotifications.ensureInitialized();

    await _messaging.requestPermission(alert: true, badge: true, sound: true, provisional: false);

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _saveToken(user, token);
    }

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      if (token.isNotEmpty) {
        await _saveToken(user, token);
      }
    });

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) async {
      final notification = _notificationFromRemoteMessage(message, user.id);
      if (notification != null) {
        await _localNotifications.showAppNotification(notification);
      }
    });
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundSubscription = null;
    _activeUserId = null;
  }

  Future<void> _saveToken(AppUser user, String token) {
    return _firestore.collection('users').doc(user.id).set({
      'id': user.id,
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoUrl,
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  AppNotification? _notificationFromRemoteMessage(RemoteMessage message, String userId) {
    final title = message.notification?.title ?? message.data['title'] as String?;
    final body = message.notification?.body ?? message.data['message'] as String?;
    if (title == null || body == null) {
      return null;
    }

    final typeName = message.data['type'] as String?;
    final type = AppNotificationType.values.firstWhere((entry) => entry.name == typeName, orElse: () => AppNotificationType.expenseAdded);

    return AppNotification(
      id: message.messageId ?? '${DateTime.now().microsecondsSinceEpoch}',
      userId: userId,
      type: type,
      title: title,
      message: body,
      createdAt: DateTime.now(),
      groupId: message.data['groupId'] as String?,
      expenseId: message.data['expenseId'] as String?,
      fromUserId: message.data['fromUserId'] as String?,
      relatedUserId: message.data['relatedUserId'] as String?,
      amount: double.tryParse('${message.data['amount'] ?? ''}'),
    );
  }
}
