import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background message handler for Firebase Cloud Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handles notifications received while app is terminated/in background
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  void Function(String payload)? onNotificationTap;

  Future<void> initialize() async {
    // 1. Request User Permissions
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 2. Set Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Initialize Local Notifications for Foreground delivery & click payloads
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap?.call(payload);
        }
      },
    );

    // 4. Listen to foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        final routePayload = message.data['payload'] as String? ?? '';
        showLocalNotification(
          title: notification.title ?? 'MediCare Update',
          body: notification.body ?? '',
          payload: routePayload,
        );
      }
    });

    // 5. Handle background FCM notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final routePayload = message.data['payload'] as String? ?? '';
      if (routePayload.isNotEmpty) {
        onNotificationTap?.call(routePayload);
      }
    });
  }

  Future<String?> getFcmToken() async {
    try {
      if (Platform.isIOS) {
        final apns = await _messaging.getAPNSToken();
        if (apns == null) return null;
      }
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'healthcare_appointment_channel',
      'Healthcare Updates & Verifications',
      channelDescription:
          'Notifications for doctor verification requests, appointment updates, and prescriptions.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}
