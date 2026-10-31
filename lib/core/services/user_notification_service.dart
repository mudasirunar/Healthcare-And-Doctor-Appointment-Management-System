import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

/// Clinical user notification dispatcher for doctor & patient account updates.
class UserNotificationService {
  UserNotificationService._();
  static final UserNotificationService instance = UserNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Dispatches an administrative update notification to a doctor's account.
  Future<void> sendDoctorNotification({
    required String doctorUserId,
    required String title,
    required String body,
    String type = 'doctor_profile_updated',
  }) async {
    if (doctorUserId.isEmpty) return;

    try {
      await _firestore.collection('notifications').add({
        'userId': doctorUserId,
        'title': title,
        'body': body,
        'type': type,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'isRead': false,
      });

      // Also trigger a local push notification
      await NotificationService.instance.showLocalNotification(
        title: title,
        body: body,
        payload: 'doctor_update:$doctorUserId',
      );
    } catch (_) {
      // Best-effort delivery; silent fallback if offline
    }
  }

  /// Dispatches an administrative update notification to a patient's account.
  Future<void> sendPatientNotification({
    required String patientUserId,
    required String title,
    required String body,
    String type = 'patient_profile_updated',
  }) async {
    if (patientUserId.isEmpty) return;

    try {
      await _firestore.collection('notifications').add({
        'userId': patientUserId,
        'title': title,
        'body': body,
        'type': type,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'isRead': false,
      });

      // Also trigger a local push notification
      await NotificationService.instance.showLocalNotification(
        title: title,
        body: body,
        payload: 'patient_update:$patientUserId',
      );
    } catch (_) {
      // Best-effort delivery; silent fallback if offline
    }
  }
}

