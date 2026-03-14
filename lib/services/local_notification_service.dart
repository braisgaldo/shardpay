import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_models.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'shardpay_messages',
    'ShardPay messages',
    description: 'Avisos de actividad y pagos de ShardPay',
    importance: Importance.max,
  );

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(initializationSettings);
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> showAppNotification(AppNotification notification) async {
    await ensureInitialized();
    await _plugin.show(
      notification.id.hashCode,
      notification.title,
      notification.message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'shardpay_messages',
          'ShardPay messages',
          channelDescription: 'Avisos de actividad y pagos de ShardPay',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
    );
  }
}