import 'package:healthcare_app/features/appointment/domain/entities/appointment_model.dart';
import 'package:healthcare_app/features/consultation/domain/entities/prescription_model.dart';
import 'package:healthcare_app/features/consultation/domain/entities/chat_message_model.dart';

abstract class AppointmentRepository {
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
  });

  Future<AppointmentModel> updateStatus({
    required String appointmentId,
    required AppointmentStatus targetStatus,
    required String actorUserId,
    bool isPatientActor = false,
    String? note,
    String? cancellationReason,
  });

  Future<AppointmentModel> rescheduleAppointment({
    required String appointmentId,
    required DateTime newScheduledTimeUtc,
    required String actorUserId,
  });

  Future<List<AppointmentModel>> getAppointmentsForPatient(String patientId);
  Future<List<AppointmentModel>> getAppointmentsForDoctor(String doctorId);
  Future<List<AppointmentModel>> getAllAppointments();
  Future<AppointmentModel?> getAppointmentById(String id);
  Stream<AppointmentModel?> watchAppointment(String id);
  Stream<List<AppointmentModel>> watchAppointments();
  Stream<List<AppointmentModel>> watchAppointmentsForPatient(String patientId);
  Stream<List<AppointmentModel>> watchAppointmentsForDoctor(String doctorId);

  bool isSlotBooked(String doctorId, DateTime slotUtc);

  // Prescriptions
  Future<PrescriptionModel> createPrescription(PrescriptionModel prescription);
  Future<PrescriptionModel?> getPrescriptionById(String id);
  Future<PrescriptionModel?> getPrescriptionForAppointment(String appointmentId);
  Future<List<PrescriptionModel>> getPrescriptionsForPatient(String patientId);

  // Chat
  Future<List<ChatMessageModel>> getMessages(String appointmentId);
  Future<ChatMessageModel> sendMessage({
    required String appointmentId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String content,
  });
}
