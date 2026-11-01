import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:healthcare_app/core/errors/app_exceptions.dart';
import 'package:healthcare_app/core/utils/date_time_utils.dart';
import 'package:healthcare_app/features/appointment/domain/entities/appointment_model.dart';
import 'package:healthcare_app/features/appointment/domain/entities/appointment_state_machine.dart';
import 'package:healthcare_app/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:healthcare_app/features/consultation/domain/entities/chat_message_model.dart';
import 'package:healthcare_app/features/consultation/domain/entities/prescription_model.dart';

/// Cloud Firestore implementation of AppointmentRepository featuring:
/// 1. Atomic Firestore Transactions for slot locking (Challenge #1: Concurrency Protection)
/// 2. Real-time appointment synchronization
/// 3. Scoped appointment chat and digital prescriptions
class FirebaseAppointmentRepository implements AppointmentRepository {
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  FirebaseAppointmentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  bool isSlotBooked(String doctorId, DateTime slotUtc) {
    // Note: In synchronous UI contexts, the deterministic slot key can be verified against
    // the local snapshot or server transaction.
    return false;
  }

  /// Atomic Concurrency-Controlled Slot Booking (Challenge #1)
  /// Enforced directly at the Cloud Firestore database level via runTransaction.
  @override
  Future<AppointmentModel> bookAppointment({
    required String patientId,
    required String patientName,
    required String patientEmail,
    required String doctorId,
    required String doctorName,
    required String doctorSpecialty,
    required DateTime scheduledTimeUtc,
    required String reasonForVisit,
    int durationMinutes = 30,
  }) async {
    final slotKey = DateTimeUtils.generateSlotKey(doctorId, scheduledTimeUtc);
    final slotDocRef = _firestore.collection('slots').doc(slotKey);
    final appointmentDocRef = _firestore.collection('appointments').doc();

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final scheduledUtcStr = scheduledTimeUtc.toUtc().toIso8601String();

    return await _firestore.runTransaction<AppointmentModel>((transaction) async {
      // 1. Read slot document exclusivity
      final slotSnapshot = await transaction.get(slotDocRef);

      if (slotSnapshot.exists && slotSnapshot.data()?['status'] == 'booked') {
        throw const SlotAlreadyBookedException(
          'The selected appointment slot has already been reserved by another patient. Please pick another slot.',
        );
      }

      final appointment = AppointmentModel(
        id: appointmentDocRef.id,
        patientId: patientId,
        patientName: patientName,
        patientEmail: patientEmail,
        doctorId: doctorId,
        doctorName: doctorName,
        doctorSpecialty: doctorSpecialty,
        scheduledTimeUtc: scheduledUtcStr,
        durationMinutes: durationMinutes,
        status: AppointmentStatus.requested,
        statusHistory: [
          StatusHistoryEntry(
            status: AppointmentStatus.requested,
            timestampUtc: nowIso,
            byUserId: patientId,
            note: 'Initial booking request',
          ),
        ],
        reasonForVisit: reasonForVisit,
        videoRoomId: AppointmentModel.generateHospitalRoomName(appointmentDocRef.id),
        createdAt: nowIso,
        updatedAt: nowIso,
      );

      // 2. Atomically lock the slot
      transaction.set(slotDocRef, {
        'doctorId': doctorId,
        'slotUtc': scheduledUtcStr,
        'appointmentId': appointmentDocRef.id,
        'status': 'booked',
        'lockedAt': FieldValue.serverTimestamp(),
      });

      // 3. Atomically write the appointment document
      transaction.set(appointmentDocRef, appointment.toMap());

      return appointment;
    });
  }

  @override
  Future<AppointmentModel> updateStatus({
    required String appointmentId,
    required AppointmentStatus targetStatus,
    required String actorUserId,
    bool isPatientActor = false,
    String? note,
    String? cancellationReason,
  }) async {
    final appointmentDocRef = _firestore.collection('appointments').doc(appointmentId);
    final snapshot = await appointmentDocRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw const NotFoundException('Appointment not found.');
    }

    final current = AppointmentModel.fromMap(snapshot.data()!, id: snapshot.id);

    // Apply strict state machine validation
    final updated = AppointmentStateMachine.transition(
      appointment: current,
      targetStatus: targetStatus,
      actorUserId: actorUserId,
      isPatientActor: isPatientActor,
      note: note,
      cancellationReason: cancellationReason,
    );

    // If terminal cancellation or rejection, release the slot lock
    if (targetStatus == AppointmentStatus.cancelled || targetStatus == AppointmentStatus.rejected) {
      final slotKey = DateTimeUtils.generateSlotKey(
        current.doctorId,
        DateTime.parse(current.scheduledTimeUtc),
      );
      await _firestore.collection('slots').doc(slotKey).delete();
    }

    await appointmentDocRef.update(updated.toMap());
    return updated;
  }

  @override
  Future<AppointmentModel> rescheduleAppointment({
    required String appointmentId,
    required DateTime newScheduledTimeUtc,
    required String actorUserId,
  }) async {
    final appointmentDocRef = _firestore.collection('appointments').doc(appointmentId);
    final snapshot = await appointmentDocRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw const NotFoundException('Appointment not found.');
    }

    final current = AppointmentModel.fromMap(snapshot.data()!, id: snapshot.id);

    if (current.status.isTerminal) {
      throw InvalidStateTransitionException(
        current.status.name,
        'rescheduled',
        'Cannot reschedule an appointment in status ${current.status.displayName}.',
      );
    }

    final oldSlotKey = DateTimeUtils.generateSlotKey(
      current.doctorId,
      DateTime.parse(current.scheduledTimeUtc),
    );
    final newSlotKey = DateTimeUtils.generateSlotKey(
      current.doctorId,
      newScheduledTimeUtc,
    );

    final oldSlotDocRef = _firestore.collection('slots').doc(oldSlotKey);
    final newSlotDocRef = _firestore.collection('slots').doc(newSlotKey);

    return await _firestore.runTransaction<AppointmentModel>((transaction) async {
      final newSlotSnapshot = await transaction.get(newSlotDocRef);
      if (newSlotSnapshot.exists &&
          newSlotSnapshot.data()?['status'] == 'booked' &&
          newSlotSnapshot.data()?['appointmentId'] != appointmentId) {
        throw const SlotAlreadyBookedException('The newly selected slot is unavailable.');
      }

      // Release old slot
      transaction.delete(oldSlotDocRef);

      // Lock new slot
      transaction.set(newSlotDocRef, {
        'doctorId': current.doctorId,
        'slotUtc': newScheduledTimeUtc.toUtc().toIso8601String(),
        'appointmentId': appointmentId,
        'status': 'booked',
        'lockedAt': FieldValue.serverTimestamp(),
      });

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final updated = current.copyWith(
        scheduledTimeUtc: newScheduledTimeUtc.toUtc().toIso8601String(),
        status: AppointmentStatus.requested,
        statusHistory: [
          ...current.statusHistory,
          StatusHistoryEntry(
            status: AppointmentStatus.requested,
            timestampUtc: nowIso,
            byUserId: actorUserId,
            note: 'Rescheduled appointment to ${DateTimeUtils.formatFullWithTimeZone(newScheduledTimeUtc.toUtc().toIso8601String())}',
          ),
        ],
        updatedAt: nowIso,
      );

      transaction.update(appointmentDocRef, updated.toMap());
      return updated;
    });
  }

  @override
  Future<List<AppointmentModel>> getAppointmentsForPatient(String patientId) async {
    final querySnapshot = await _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .get();

    final list = querySnapshot.docs.map((d) => AppointmentModel.fromMap(d.data(), id: d.id)).toList();
    list.sort((a, b) => b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc));
    return list;
  }

  @override
  Future<List<AppointmentModel>> getAppointmentsForDoctor(String doctorId) async {
    final querySnapshot = await _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .get();

    final list = querySnapshot.docs.map((d) => AppointmentModel.fromMap(d.data(), id: d.id)).toList();
    list.sort((a, b) => b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc));
    return list;
  }

  @override
  Future<List<AppointmentModel>> getAllAppointments() async {
    final querySnapshot = await _firestore.collection('appointments').get();
    final list = querySnapshot.docs.map((d) => AppointmentModel.fromMap(d.data(), id: d.id)).toList();
    list.sort((a, b) => b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc));
    return list;
  }

  @override
  Future<AppointmentModel?> getAppointmentById(String id) async {
    final docSnapshot = await _firestore.collection('appointments').doc(id).get();
    if (!docSnapshot.exists || docSnapshot.data() == null) return null;
    return AppointmentModel.fromMap(docSnapshot.data()!, id: docSnapshot.id);
  }

  @override
  Stream<AppointmentModel?> watchAppointment(String id) {
    return _firestore.collection('appointments').doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppointmentModel.fromMap(doc.data()!, id: doc.id);
    });
  }

  @override
  Stream<List<AppointmentModel>> watchAppointments() {
    return _firestore.collection('appointments').snapshots().map((s) =>
        s.docs.map((d) => AppointmentModel.fromMap(d.data(), id: d.id)).toList()
          ..sort((a, b) => b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc)));
  }

  @override
  Stream<List<AppointmentModel>> watchAppointmentsForPatient(String patientId) {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => AppointmentModel.fromMap(d.data(), id: d.id))
            .toList()
          ..sort((a, b) => b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc)));
  }

  @override
  Stream<List<AppointmentModel>> watchAppointmentsForDoctor(String doctorId) {
    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => AppointmentModel.fromMap(d.data(), id: d.id))
            .toList()
          ..sort((a, b) => b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc)));
  }

  // --- PRESCRIPTIONS ---
  @override
  Future<PrescriptionModel> createPrescription(PrescriptionModel prescription) async {
    await _firestore.collection('prescriptions').doc(prescription.id).set(prescription.toMap());
    await _firestore.collection('appointments').doc(prescription.appointmentId).update({
      'prescriptionId': prescription.id,
      'status': AppointmentStatus.completed.name,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    return prescription;
  }

  @override
  Future<PrescriptionModel?> getPrescriptionById(String id) async {
    final doc = await _firestore.collection('prescriptions').doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return PrescriptionModel.fromMap(doc.data()!, id: doc.id);
  }

  @override
  Future<PrescriptionModel?> getPrescriptionForAppointment(String appointmentId) async {
    final query = await _firestore
        .collection('prescriptions')
        .where('appointmentId', isEqualTo: appointmentId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return PrescriptionModel.fromMap(query.docs.first.data(), id: query.docs.first.id);
  }

  @override
  Future<List<PrescriptionModel>> getPrescriptionsForPatient(String patientId) async {
    final query = await _firestore
        .collection('prescriptions')
        .where('patientId', isEqualTo: patientId)
        .get();
    return query.docs.map((d) => PrescriptionModel.fromMap(d.data(), id: d.id)).toList();
  }

  // --- APPOINTMENT CHAT ---
  @override
  Future<List<ChatMessageModel>> getMessages(String appointmentId) async {
    final query = await _firestore
        .collection('appointments')
        .doc(appointmentId)
        .collection('messages')
        .orderBy('sentAtUtc', descending: false)
        .get();
    return query.docs.map((d) => ChatMessageModel.fromMap(d.data(), id: d.id)).toList();
  }

  @override
  Future<ChatMessageModel> sendMessage({
    required String appointmentId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String content,
    String? messageId,
  }) async {
    final effectiveMessageId =
        messageId ?? 'msg_${_uuid.v4().substring(0, 8)}';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final message = ChatMessageModel(
      id: effectiveMessageId,
      appointmentId: appointmentId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      content: content,
      sentAtUtc: nowIso,
    );

    await _firestore
        .collection('appointments')
        .doc(appointmentId)
        .collection('messages')
        .doc(effectiveMessageId)
        .set(message.toMap());

    // Update appointment document preview & increment recipient unread count remotely in Firestore
    final isSenderDoctor = senderRole.toLowerCase() == 'doctor';
    await _firestore.collection('appointments').doc(appointmentId).set({
      'lastMessageContent': content,
      'lastMessageSentAtUtc': nowIso,
      'lastMessageSenderId': senderId,
      if (isSenderDoctor)
        'unreadCountForPatient': FieldValue.increment(1)
      else
        'unreadCountForDoctor': FieldValue.increment(1),
    }, SetOptions(merge: true));

    return message;
  }

  @override
  Future<void> markAppointmentMessagesAsRead({
    required String appointmentId,
    required String readerRole,
  }) async {
    try {
      final isDoctor = readerRole.toLowerCase() == 'doctor';
      // Reset unread count remotely in Firestore on appointment doc
      await _firestore.collection('appointments').doc(appointmentId).set({
        if (isDoctor)
          'unreadCountForDoctor': 0
        else
          'unreadCountForPatient': 0,
      }, SetOptions(merge: true));

      // Mark unread messages in Firestore subcollection as read
      final unreadSnap = await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in unreadSnap.docs) {
          final data = doc.data();
          final senderRole = data['senderRole'] as String? ?? '';
          if (senderRole.toLowerCase() != readerRole.toLowerCase()) {
            batch.update(doc.reference, {
              'isRead': true,
              'isDelivered': true,
            });
          }
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Notice: markAppointmentMessagesAsRead: $e');
    }
  }
}
