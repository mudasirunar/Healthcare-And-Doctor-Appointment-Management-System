import 'package:healthcare_app/core/data/mock_data_store.dart';
import 'package:healthcare_app/features/appointment/domain/entities/appointment_model.dart';
import 'package:healthcare_app/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:healthcare_app/features/consultation/domain/entities/chat_message_model.dart';
import 'package:healthcare_app/features/consultation/domain/entities/prescription_model.dart';

class MockAppointmentRepository implements AppointmentRepository {
  final MockDataStore _dataStore;

  MockAppointmentRepository([MockDataStore? dataStore])
      : _dataStore = dataStore ?? MockDataStore.instance;

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
    await Future.delayed(const Duration(milliseconds: 300));
    return _dataStore.bookAppointmentTransaction(
      patientId: patientId,
      patientName: patientName,
      patientEmail: patientEmail,
      doctorId: doctorId,
      doctorName: doctorName,
      doctorSpecialty: doctorSpecialty,
      scheduledTimeUtc: scheduledTimeUtc,
      reasonForVisit: reasonForVisit,
      durationMinutes: durationMinutes,
    );
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
    await Future.delayed(const Duration(milliseconds: 200));
    return _dataStore.updateAppointmentStatus(
      appointmentId: appointmentId,
      targetStatus: targetStatus,
      actorUserId: actorUserId,
      isPatientActor: isPatientActor,
      note: note,
      cancellationReason: cancellationReason,
    );
  }

  @override
  Future<AppointmentModel> rescheduleAppointment({
    required String appointmentId,
    required DateTime newScheduledTimeUtc,
    required String actorUserId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _dataStore.rescheduleAppointment(
      appointmentId: appointmentId,
      newScheduledTimeUtc: newScheduledTimeUtc,
      actorUserId: actorUserId,
    );
  }

  @override
  Future<List<AppointmentModel>> getAppointmentsForPatient(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _dataStore.getAppointmentsForPatient(patientId);
  }

  @override
  Future<List<AppointmentModel>> getAppointmentsForDoctor(String doctorId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _dataStore.getAppointmentsForDoctor(doctorId);
  }

  @override
  Future<List<AppointmentModel>> getAllAppointments() async {
    return _dataStore.getAllAppointments();
  }

  @override
  Future<AppointmentModel?> getAppointmentById(String id) async {
    return _dataStore.getAppointmentById(id);
  }

  @override
  Stream<List<AppointmentModel>> watchAppointments() {
    return _dataStore.appointmentsStream;
  }

  @override
  bool isSlotBooked(String doctorId, DateTime slotUtc) {
    return _dataStore.isSlotBooked(doctorId, slotUtc);
  }

  @override
  Future<PrescriptionModel> createPrescription(PrescriptionModel prescription) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _dataStore.createPrescription(prescription);
  }

  @override
  Future<PrescriptionModel?> getPrescriptionById(String id) async {
    return _dataStore.getPrescriptionById(id);
  }

  @override
  Future<PrescriptionModel?> getPrescriptionForAppointment(String appointmentId) async {
    return _dataStore.getPrescriptionForAppointment(appointmentId);
  }

  @override
  Future<List<PrescriptionModel>> getPrescriptionsForPatient(String patientId) async {
    return _dataStore.getPrescriptionsForPatient(patientId);
  }

  @override
  Future<List<ChatMessageModel>> getMessages(String appointmentId) async {
    return _dataStore.getMessagesForAppointment(appointmentId);
  }

  @override
  Future<ChatMessageModel> sendMessage({
    required String appointmentId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String content,
  }) async {
    return _dataStore.sendMessage(
      appointmentId: appointmentId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      content: content,
    );
  }
}
