import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_app/core/data/mock_data_store.dart';
import 'package:healthcare_app/features/appointment/data/repositories/mock_appointment_repository.dart';
import 'package:healthcare_app/features/consultation/domain/entities/prescription_model.dart';

void main() {
  group('Online Consultation: Prescriptions & Encrypted Chat', () {
    late MockAppointmentRepository repository;

    setUp(() {
      repository = MockAppointmentRepository(MockDataStore.instance);
    });

    test('Doctor creates and attaches digital prescription to completed appointment', () async {
      const rxId = 'rx_unit_test_01';
      final rx = PrescriptionModel(
        id: rxId,
        appointmentId: 'apt_past_001',
        patientId: 'patient_001',
        patientName: 'Sarah Jenkins',
        doctorId: 'doc_001',
        doctorName: 'Dr. Emily Stone',
        doctorSpecialty: 'Cardiology',
        diagnosis: 'Mild hypertension',
        medications: const [
          MedicationItem(
            name: 'Amlodipine',
            dosage: '5mg',
            frequency: 'Once daily in morning',
            duration: '30 days',
            instructions: 'Monitor BP weekly',
          ),
        ],
        notes: 'Low sodium diet advised',
        issuedAtUtc: DateTime.now().toUtc().toIso8601String(),
      );

      final created = await repository.createPrescription(rx);
      expect(created.id, equals(rxId));

      final retrieved = await repository.getPrescriptionById(rxId);
      expect(retrieved, isNotNull);
      expect(retrieved?.medications.first.name, equals('Amlodipine'));
      expect(retrieved?.patientId, equals('patient_001'));
    });

    test('Scoped appointment chat sends and retrieves chronological messages', () async {
      const aptId = 'apt_chat_test_01';

      await repository.sendMessage(
        appointmentId: aptId,
        senderId: 'patient_001',
        senderName: 'Sarah',
        senderRole: 'patient',
        content: 'Hi Doctor, I am ready for the call.',
      );

      await repository.sendMessage(
        appointmentId: aptId,
        senderId: 'doc_001',
        senderName: 'Dr. Stone',
        senderRole: 'doctor',
        content: 'Starting the video session now.',
      );

      final messages = await repository.getMessages(aptId);
      expect(messages.length, equals(2));
      expect(messages[0].content, equals('Hi Doctor, I am ready for the call.'));
      expect(messages[1].content, equals('Starting the video session now.'));
    });

    test('Messaging updates unread count and markAppointmentMessagesAsRead clears it', () async {
      const aptId = 'apt_001';

      // Doctor sends 2 messages to patient
      await repository.sendMessage(
        appointmentId: aptId,
        senderId: 'doc_001',
        senderName: 'Dr. Emily Stone',
        senderRole: 'doctor',
        content: 'Hello, please review your test results.',
      );

      await repository.sendMessage(
        appointmentId: aptId,
        senderId: 'doc_001',
        senderName: 'Dr. Emily Stone',
        senderRole: 'doctor',
        content: 'Are you available to discuss?',
      );

      var apt = await repository.getAppointmentById(aptId);
      expect(apt, isNotNull);
      expect(apt!.lastMessageContent, equals('Are you available to discuss?'));
      expect(apt.unreadCountForPatient, equals(2));

      // Patient marks messages as read
      await repository.markAppointmentMessagesAsRead(
        appointmentId: aptId,
        readerRole: 'patient',
      );

      apt = await repository.getAppointmentById(aptId);
      expect(apt!.unreadCountForPatient, equals(0));

      final messages = await repository.getMessages(aptId);
      final doctorMessages = messages.where((m) => m.senderRole == 'doctor');
      expect(doctorMessages.every((m) => m.isRead), isTrue);
    });
  });
}
