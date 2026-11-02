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
    String? targetId,
    String? appointmentId,
    String? doctorId,
  }) async {
    if (doctorUserId.isEmpty) return;

    String resolvedUserId = doctorUserId;
    String resolvedDoctorId = doctorId ?? '';

    // If doctorUserId is a doctor doc ID, look up the doctor's Auth userId
    if (doctorUserId.startsWith('doc_') || (doctorId == null && doctorUserId.isNotEmpty)) {
      try {
        final docSnap =
            await _firestore.collection('doctors').doc(doctorUserId).get();
        if (docSnap.exists && docSnap.data() != null) {
          final data = docSnap.data()!;
          final uid = data['userId'] as String?;
          if (uid != null && uid.isNotEmpty) {
            resolvedUserId = uid;
            resolvedDoctorId = doctorUserId;
          }
        }
      } catch (_) {}
    }

    final effectiveTargetId = targetId ?? appointmentId;
    final payload = <String, dynamic>{
      'userId': resolvedUserId,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'isRead': false,
    };
    if (effectiveTargetId != null) {
      payload['targetId'] = effectiveTargetId;
      payload['appointmentId'] = effectiveTargetId;
    }
    if (resolvedDoctorId.isNotEmpty) {
      payload['doctorId'] = resolvedDoctorId;
    }

    try {
      await _firestore.collection('notifications').add(payload);
    } catch (e) {
      debugPrint('Firestore save doctor notification notice: $e');
    }

    // Always trigger a local push notification banner on the device
    await NotificationService.instance.showLocalNotification(
      title: title,
      body: body,
      payload: 'doctor_update:$resolvedUserId:${effectiveTargetId ?? ''}',
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

  /// Marks multiple notifications as read in a single batch, with resilient individual fallback.
  Future<void> markMultipleAsRead(Iterable<String> notificationIds) async {
    final validIds = notificationIds.where((id) => id.isNotEmpty).toList();
    if (validIds.isEmpty) return;

    try {
      final batch = _firestore.batch();
      for (final id in validIds) {
        batch.update(
          _firestore.collection('notifications').doc(id),
          {'isRead': true},
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Firestore markMultipleAsRead batch failed: $e. Retrying individually...');
      for (final id in validIds) {
        try {
          await _firestore.collection('notifications').doc(id).update({'isRead': true});
        } catch (_) {}
      }
    }
  }

  /// Marks a specific user notification as read in Firestore.
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    try {
      await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
    } catch (_) {}
  }

  /// Marks all notifications for a given user as read in Firestore without requiring composite indexes.
  Future<void> markAllAsReadForUser(String userId, [List<String>? additionalUserIds]) async {
    if (userId.isEmpty) return;
    final allIds = <String>{userId};
    if (additionalUserIds != null) {
      allIds.addAll(additionalUserIds.where((id) => id.isNotEmpty));
    }

    try {
      for (final id in allIds) {
        final query = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: id)
            .get();
        if (query.docs.isNotEmpty) {
          final batch = _firestore.batch();
          bool hasUpdates = false;
          for (final doc in query.docs) {
            if (doc.data()['isRead'] != true) {
              batch.update(doc.reference, {'isRead': true});
              hasUpdates = true;
            }
          }
          if (hasUpdates) {
            await batch.commit();
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore markAllAsReadForUser error: $e');
    }
  }
}

