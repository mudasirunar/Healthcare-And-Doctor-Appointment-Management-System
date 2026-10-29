import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_app/core/errors/app_exceptions.dart';
import 'package:healthcare_app/features/appointment/domain/entities/appointment_model.dart';
import 'package:healthcare_app/features/appointment/domain/entities/appointment_state_machine.dart';

void main() {
  group('Challenge #3: Appointment State Machine & Transition Rules', () {
    late AppointmentModel baseAppointment;

    setUp(() {
      final futureTimeUtc = DateTime.now().toUtc().add(const Duration(days: 3)).toIso8601String();
      baseAppointment = AppointmentModel(
        id: 'apt_test_001',
        patientId: 'patient_001',
        patientName: 'Sarah Jenkins',
        patientEmail: 'patient@healthcare.com',
        doctorId: 'doc_001',
        doctorName: 'Dr. Emily Stone',
        doctorSpecialty: 'Cardiology',
        scheduledTimeUtc: futureTimeUtc,
        durationMinutes: 30,
        status: AppointmentStatus.requested,
        reasonForVisit: 'Heart palpitations',
        videoRoomId: 'room_apt_test_001',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
    });

    test('Valid lifecycle forward progression: Requested -> Confirmed -> InProgress -> Completed', () {
      // 1. Requested -> Confirmed
      final confirmed = AppointmentStateMachine.transition(
        appointment: baseAppointment,
        targetStatus: AppointmentStatus.confirmed,
        actorUserId: 'doc_001',
        note: 'Doctor approved',
      );
      expect(confirmed.status, equals(AppointmentStatus.confirmed));
      expect(confirmed.statusHistory.length, equals(1));
      expect(confirmed.statusHistory.first.status, equals(AppointmentStatus.confirmed));

      // 2. Confirmed -> InProgress
      final inProgress = AppointmentStateMachine.transition(
        appointment: confirmed,
        targetStatus: AppointmentStatus.inProgress,
        actorUserId: 'doc_001',
        note: 'Call initiated',
      );
      expect(inProgress.status, equals(AppointmentStatus.inProgress));
      expect(inProgress.statusHistory.length, equals(2));

      // 3. InProgress -> Completed
      final completed = AppointmentStateMachine.transition(
        appointment: inProgress,
        targetStatus: AppointmentStatus.completed,
        actorUserId: 'doc_001',
        note: 'Rx issued',
      );
      expect(completed.status, equals(AppointmentStatus.completed));
      expect(completed.status.isTerminal, isTrue);
      expect(completed.statusHistory.length, equals(3));
    });

    test('Doctor decline: Requested -> Rejected', () {
      final rejected = AppointmentStateMachine.transition(
        appointment: baseAppointment,
        targetStatus: AppointmentStatus.rejected,
        actorUserId: 'doc_001',
        note: 'Out of office',
      );
      expect(rejected.status, equals(AppointmentStatus.rejected));
      expect(rejected.status.isTerminal, isTrue);
    });

    test('Invalid jump: Requested -> Completed throws InvalidStateTransitionException', () {
      expect(
        () => AppointmentStateMachine.transition(
          appointment: baseAppointment,
          targetStatus: AppointmentStatus.completed,
          actorUserId: 'doc_001',
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('Terminal state cannot be modified: Completed -> InProgress throws InvalidStateTransitionException', () {
      final completedApt = baseAppointment.copyWith(status: AppointmentStatus.completed);
      expect(
        () => AppointmentStateMachine.transition(
          appointment: completedApt,
          targetStatus: AppointmentStatus.inProgress,
          actorUserId: 'doc_001',
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('Terminal state cannot be modified: Cancelled -> Confirmed throws InvalidStateTransitionException', () {
      final cancelledApt = baseAppointment.copyWith(status: AppointmentStatus.cancelled);
      expect(
        () => AppointmentStateMachine.transition(
          appointment: cancelledApt,
          targetStatus: AppointmentStatus.confirmed,
          actorUserId: 'doc_001',
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });
  });
}
