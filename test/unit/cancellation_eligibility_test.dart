import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_app/core/errors/app_exceptions.dart';
import 'package:healthcare_app/core/utils/date_time_utils.dart';
import 'package:healthcare_app/features/appointment/domain/entities/appointment_model.dart';
import 'package:healthcare_app/features/appointment/domain/entities/appointment_state_machine.dart';

void main() {
  group('Cancellation Eligibility & 2-Hour Window Rules', () {
    test('Appointment > 2 hours in future is eligible for cancellation', () {
      final scheduledUtc = DateTime.now().toUtc().add(const Duration(hours: 4)).toIso8601String();
      expect(DateTimeUtils.isEligibleForCancellation(scheduledUtc), isTrue);
    });

    test('Appointment < 2 hours in future is NOT eligible for patient cancellation', () {
      final scheduledUtc = DateTime.now().toUtc().add(const Duration(minutes: 75)).toIso8601String();
      expect(DateTimeUtils.isEligibleForCancellation(scheduledUtc), isFalse);
    });

    test('Appointment in past is NOT eligible for cancellation', () {
      final pastUtc = DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String();
      expect(DateTimeUtils.isEligibleForCancellation(pastUtc), isFalse);
    });

    test('State machine throws CancellationNotAllowedException if patient cancels < 2 hours prior', () {
      final imminentTimeUtc = DateTime.now().toUtc().add(const Duration(minutes: 45)).toIso8601String();
      final apt = AppointmentModel(
        id: 'apt_imminent_001',
        patientId: 'patient_001',
        patientName: 'Sarah',
        patientEmail: 'sarah@test.com',
        doctorId: 'doc_001',
        doctorName: 'Dr. Stone',
        doctorSpecialty: 'Cardiology',
        scheduledTimeUtc: imminentTimeUtc,
        status: AppointmentStatus.confirmed,
        reasonForVisit: 'Checkup',
        videoRoomId: 'room_1',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );

      expect(
        () => AppointmentStateMachine.transition(
          appointment: apt,
          targetStatus: AppointmentStatus.cancelled,
          actorUserId: 'patient_001',
          isPatientActor: true,
          cancellationReason: 'Need to postpone',
        ),
        throwsA(isA<CancellationNotAllowedException>()),
      );
    });

    test('Doctor cancellation is permitted even within 2 hours for clinical emergencies', () {
      final imminentTimeUtc = DateTime.now().toUtc().add(const Duration(minutes: 30)).toIso8601String();
      final apt = AppointmentModel(
        id: 'apt_imminent_002',
        patientId: 'patient_001',
        patientName: 'Sarah',
        patientEmail: 'sarah@test.com',
        doctorId: 'doc_001',
        doctorName: 'Dr. Stone',
        doctorSpecialty: 'Cardiology',
        scheduledTimeUtc: imminentTimeUtc,
        status: AppointmentStatus.confirmed,
        reasonForVisit: 'Checkup',
        videoRoomId: 'room_1',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );

      final cancelled = AppointmentStateMachine.transition(
        appointment: apt,
        targetStatus: AppointmentStatus.cancelled,
        actorUserId: 'doc_001',
        isPatientActor: false, // Doctor actor
        cancellationReason: 'Emergency surgery scheduled',
      );

      expect(cancelled.status, equals(AppointmentStatus.cancelled));
      expect(cancelled.cancellationReason, equals('Emergency surgery scheduled'));
    });
  });
}
