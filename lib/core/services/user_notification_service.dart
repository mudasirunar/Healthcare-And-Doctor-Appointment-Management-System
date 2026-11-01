import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
    } catch (e) {
      debugPrint('Firestore save doctor notification notice: $e');
    }

    // Always trigger a local push notification banner on the device
    await NotificationService.instance.showLocalNotification(
      title: title,
      body: body,
      payload: 'doctor_update:$doctorUserId',
    );
  }

  /// Dispatches an administrative or clinical update notification to a patient's account.
  Future<void> sendPatientNotification({
    required String patientUserId,
    required String title,
    required String body,
    String type = 'patient_profile_updated',
    String? targetId,
    String? appointmentId,
  }) async {
    if (patientUserId.isEmpty) return;

    final effectiveTargetId = targetId ?? appointmentId;
    final payloadData = <String, dynamic>{
      'userId': patientUserId,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'isRead': false,
    };
    if (effectiveTargetId != null) {
      payloadData['targetId'] = effectiveTargetId;
      payloadData['appointmentId'] = effectiveTargetId;
    }

    try {
      await _firestore.collection('notifications').add(payloadData);
    } catch (e) {
      debugPrint('Firestore save patient notification notice: $e');
    }

    // Always trigger a local push notification banner on the device
    await NotificationService.instance.showLocalNotification(
      title: title,
      body: body,
      payload: 'patient_update:$patientUserId:${effectiveTargetId ?? ''}',
    );
  }

  /// Marks a specific user notification as read in Firestore.
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    try {
      await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
    } catch (_) {}
  }

  /// Marks all notifications for a given user as read in Firestore.
  Future<void> markAllAsReadForUser(String userId) async {
    if (userId.isEmpty) return;
    try {
      final query = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }
}

