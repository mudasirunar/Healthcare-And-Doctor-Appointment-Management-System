import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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

  // Active incoming listener subscriptions
  StreamSubscription? _userNotificationsSub;
  StreamSubscription? _adminAppointmentsSub;
  StreamSubscription? _tokenRefreshSub;
  String? _currentListeningUserId;
  bool? _currentListeningIsAdmin;
  final Set<String> _seenNotificationIds = {};
  bool _isInitialSync = true;
  final Map<String, DateTime> _recentlyDispatchedBanners = {};

  Future<void> initialize() async {
    // 1. Request User Permissions for FCM (iOS & Android)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 2. Set foreground presentation options so iOS displays banners while app is open
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Set Background FCM handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Initialize Local Notifications with Darwin (iOS) & Android configurations
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
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

    // 5. Request native OS permissions explicitly for FlutterLocalNotificationsPlugin
    try {
      if (Platform.isIOS) {
        final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else if (Platform.isAndroid) {
        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Notification permission request notice: $e');
    }

    // 6. Listen to foreground FCM messages
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

    // 7. Handle background FCM notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final routePayload = message.data['payload'] as String? ?? '';
      if (routePayload.isNotEmpty) {
        onNotificationTap?.call(routePayload);
      }
    });

    // 8. Handle terminated app launch via FCM notification tap
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final routePayload = initialMessage.data['payload'] as String? ?? '';
      if (routePayload.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          onNotificationTap?.call(routePayload);
        });
      }
    }
  }

  /// Synchronizes device FCM token to Firestore so backend push dispatchers can target this user
  Future<void> _syncFcmToken(String userId, {bool isAdmin = false}) async {
    try {
      final token = await getFcmToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'devicePlatform': Platform.isIOS ? 'ios' : 'android',
        }, SetOptions(merge: true));

        debugPrint('FCM Token successfully synced for user: $userId');
      }

      // Keep token updated if refreshed by Google FCM servers
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'fcmToken': newToken,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      });

      // Subscribe user to personalized topic
      await _messaging.subscribeToTopic('user_$userId');
      if (isAdmin) {
        await _messaging.subscribeToTopic('admin_notifications');
      }
    } catch (e) {
      debugPrint('Notice during FCM token sync: $e');
    }
  }

  /// Starts listening to real-time incoming Firestore notifications on the receiver's device
  /// and automatically displays native iOS / Android heads-up banners with sound & vibration.
  void startListeningForUser(String userId, {bool isAdmin = false}) {
    if (_currentListeningUserId == userId &&
        _currentListeningIsAdmin == isAdmin &&
        _userNotificationsSub != null) {
      // Already actively listening for this user. Avoid resetting seen state!
      return;
    }

    stopListening();
    _currentListeningUserId = userId;
    _currentListeningIsAdmin = isAdmin;
    _isInitialSync = true;
    _seenNotificationIds.clear();

    // Sync FCM Token and subscribe to device topics
    _syncFcmToken(userId, isAdmin: isAdmin);

    // 1. User Personal Notifications Stream (Patient, Doctor, Admin direct alerts)
    _userNotificationsSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(
      (snapshot) {
        if (_isInitialSync) {
          // Record pre-existing historical notifications to avoid spamming on login
          for (final doc in snapshot.docs) {
            _seenNotificationIds.add(doc.id);
          }
          _isInitialSync = false;
          return;
        }

        // Detect newly created incoming notification documents
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final id = change.doc.id;
            if (_seenNotificationIds.contains(id)) continue;
            _seenNotificationIds.add(id);

            final data = change.doc.data();
            if (data != null && data['isRead'] == false) {
              final title = data['title'] as String? ?? 'New Health Update';
              final body = data['body'] as String? ?? '';
              final type = data['type'] as String? ?? 'general';
              final targetId = (data['targetId'] as String?) ??
                  (data['appointmentId'] as String?) ??
                  '';

              showLocalNotification(
                title: title,
                body: body,
                payload: 'user_notification:$type:$targetId',
              );
            }
          }
        }
      },
      onError: (e) {
        debugPrint('UserNotification listener notice: $e');
      },
    );

    // 2. Admin Global Activity Stream (New appointments, booking requests)
    if (isAdmin) {
      bool initialAdminSync = true;
      final seenAdminAptIds = <String>{};

      _adminAppointmentsSub = FirebaseFirestore.instance
          .collection('appointments')
          .snapshots()
          .listen(
        (snapshot) {
          if (initialAdminSync) {
            for (final doc in snapshot.docs) {
              seenAdminAptIds.add(doc.id);
            }
            initialAdminSync = false;
            return;
          }

          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final id = change.doc.id;
              if (seenAdminAptIds.contains(id)) continue;
              seenAdminAptIds.add(id);

              final data = change.doc.data();
              if (data != null) {
                final patientName = data['patientName'] as String? ?? 'A patient';
                final docName = data['doctorName'] as String? ?? 'doctor';

                showLocalNotification(
                  title: 'New Consultation Booking',
                  body: '$patientName scheduled a consultation with $docName.',
                  payload: 'admin_appointment:$id',
                );
              }
            }
          }
        },
        onError: (e) {
          debugPrint('Admin appointments listener notice: $e');
        },
      );
    }
  }

  /// Cancels active real-time listeners on sign-out
  void stopListening() {
    _userNotificationsSub?.cancel();
    _userNotificationsSub = null;
    _adminAppointmentsSub?.cancel();
    _adminAppointmentsSub = null;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _currentListeningUserId = null;
    _currentListeningIsAdmin = null;
    _seenNotificationIds.clear();
    _isInitialSync = true;
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

  /// Displays native system heads-up notification with sound, vibration, and banner
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Deduplicate fast consecutive dispatches (within 3 seconds)
    final dedupeKey = '$title|$body';
    final now = DateTime.now();
    if (_recentlyDispatchedBanners.containsKey(dedupeKey)) {
      final prev = _recentlyDispatchedBanners[dedupeKey]!;
      if (now.difference(prev).inSeconds < 3) {
        return;
      }
    }
    _recentlyDispatchedBanners[dedupeKey] = now;

    const androidDetails = AndroidNotificationDetails(
      'healthcare_appointment_channel',
      'Healthcare Updates & Verifications',
      channelDescription:
          'Notifications for doctor verification requests, appointment updates, and prescriptions.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification banner: $e');
    }
  }
}
