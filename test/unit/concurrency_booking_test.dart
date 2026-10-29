import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_app/core/data/mock_data_store.dart';
import 'package:healthcare_app/core/errors/app_exceptions.dart';
import 'package:healthcare_app/features/appointment/data/repositories/mock_appointment_repository.dart';

void main() {
  group('Challenge #1: Concurrency Control & Double-Booking Prevention', () {
    late MockAppointmentRepository repository;

    setUp(() {
      repository = MockAppointmentRepository(MockDataStore.instance);
    });

    test('Single booking succeeds and locks deterministic slot key', () async {
      final slotTimeUtc = DateTime.utc(2026, 12, 1, 10, 0);
      const doctorId = 'doc_test_101';

      expect(repository.isSlotBooked(doctorId, slotTimeUtc), isFalse);

      final appointment = await repository.bookAppointment(
        patientId: 'patient_001',
        patientName: 'Test Patient',
        patientEmail: 'patient@test.com',
        doctorId: doctorId,
        doctorName: 'Dr. Test',
        doctorSpecialty: 'Cardiology',
        scheduledTimeUtc: slotTimeUtc,
        reasonForVisit: 'Annual cardiovascular checkup',
      );

      expect(appointment.id, startsWith('apt_'));
      expect(repository.isSlotBooked(doctorId, slotTimeUtc), isTrue);
    });

    test('Second booking attempt on same doctor and slot throws SlotAlreadyBookedException', () async {
      final slotTimeUtc = DateTime.utc(2026, 12, 2, 14, 0);
      const doctorId = 'doc_test_102';

      // First booking succeeds
      await repository.bookAppointment(
        patientId: 'patient_001',
        patientName: 'Patient One',
        patientEmail: 'patient1@test.com',
        doctorId: doctorId,
        doctorName: 'Dr. Test',
        doctorSpecialty: 'Dermatology',
        scheduledTimeUtc: slotTimeUtc,
        reasonForVisit: 'First visit',
      );

      // Colliding second attempt MUST fail at database/transaction level
      expect(
        () => repository.bookAppointment(
          patientId: 'patient_002',
          patientName: 'Patient Two',
          patientEmail: 'patient2@test.com',
          doctorId: doctorId,
          doctorName: 'Dr. Test',
          doctorSpecialty: 'Dermatology',
          scheduledTimeUtc: slotTimeUtc,
          reasonForVisit: 'Second visit colliding',
        ),
        throwsA(isA<SlotAlreadyBookedException>()),
      );
    });

    test('Simultaneous race condition guarantees single winner', () async {
      final slotTimeUtc = DateTime.utc(2026, 12, 3, 11, 30);
      const doctorId = 'doc_test_103';

      int successCount = 0;
      int conflictCount = 0;

      Future<void> attemptBooking(String patientId, String name, String email) async {
        try {
          await repository.bookAppointment(
            patientId: patientId,
            patientName: name,
            patientEmail: email,
            doctorId: doctorId,
            doctorName: 'Dr. Race',
            doctorSpecialty: 'Neurology',
            scheduledTimeUtc: slotTimeUtc,
            reasonForVisit: 'Race consult',
          );
          successCount++;
        } on SlotAlreadyBookedException {
          conflictCount++;
        }
      }

      await Future.wait([
        attemptBooking('patient_alpha', 'Patient Alpha', 'alpha@test.com'),
        attemptBooking('patient_beta', 'Patient Beta', 'beta@test.com'),
      ]);

      expect(successCount, equals(1), reason: 'Exactly one concurrent booking must succeed');
      expect(conflictCount, equals(1), reason: 'The second concurrent booking must be rejected with conflict');
    });

    test('Rescheduling releases original slot and locks target slot', () async {
      final initialSlotUtc = DateTime.utc(2026, 12, 4, 9, 0);
      final newSlotUtc = DateTime.utc(2026, 12, 4, 15, 0);
      const doctorId = 'doc_test_104';

      final apt = await repository.bookAppointment(
        patientId: 'patient_001',
        patientName: 'Patient',
        patientEmail: 'patient@test.com',
        doctorId: doctorId,
        doctorName: 'Dr. Test',
        doctorSpecialty: 'Cardiology',
        scheduledTimeUtc: initialSlotUtc,
        reasonForVisit: 'Routine',
      );

      expect(repository.isSlotBooked(doctorId, initialSlotUtc), isTrue);
      expect(repository.isSlotBooked(doctorId, newSlotUtc), isFalse);

      await repository.rescheduleAppointment(
        appointmentId: apt.id,
        newScheduledTimeUtc: newSlotUtc,
        actorUserId: 'patient_001',
      );

      // Old slot is freed
      expect(repository.isSlotBooked(doctorId, initialSlotUtc), isFalse);
      // New slot is claimed
      expect(repository.isSlotBooked(doctorId, newSlotUtc), isTrue);
    });
  });
}
