import 'dart:async';
import 'package:uuid/uuid.dart';
import '../errors/app_exceptions.dart';
import '../utils/date_time_utils.dart';
import '../../features/auth/domain/entities/user_model.dart';
import '../../features/doctor/domain/entities/doctor_model.dart';
import '../../features/doctor/domain/entities/specialty_model.dart';
import '../../features/appointment/domain/entities/appointment_model.dart';
import '../../features/appointment/domain/entities/appointment_state_machine.dart';
import '../../features/consultation/domain/entities/prescription_model.dart';
import '../../features/consultation/domain/entities/chat_message_model.dart';

/// Central reactive data store implementing offline-resilient operations,
/// seed dataset, and atomic slot-booking locks (Challenge #1 & #6).
class MockDataStore {
  static final MockDataStore instance = MockDataStore._internal();

  MockDataStore._internal() {
    _seedInitialData();
  }

  final _uuid = const Uuid();

  // State maps
  final Map<String, UserModel> _users = {};
  final Map<String, DoctorModel> _doctors = {};
  final Map<String, SpecialtyModel> _specialties = {};
  final Map<String, AppointmentModel> _appointments = {};
  final Map<String, String> _bookedSlots = {}; // slotKey -> appointmentId
  final Map<String, PrescriptionModel> _prescriptions = {};
  final Map<String, List<ChatMessageModel>> _appointmentChats = {};

  // Stream controllers for real-time reactive updates
  final _appointmentsStreamController = StreamController<List<AppointmentModel>>.broadcast();
  final _doctorsStreamController = StreamController<List<DoctorModel>>.broadcast();
  final _specialtiesStreamController = StreamController<List<SpecialtyModel>>.broadcast();

  Stream<List<AppointmentModel>> get appointmentsStream => _appointmentsStreamController.stream;
  Stream<List<DoctorModel>> get doctorsStream => _doctorsStreamController.stream;
  Stream<List<SpecialtyModel>> get specialtiesStream => _specialtiesStreamController.stream;

  void _notifyAppointments() {
    _appointmentsStreamController.add(_appointments.values.toList());
  }

  void _notifyDoctors() {
    _doctorsStreamController.add(_doctors.values.toList());
  }

  void _notifySpecialties() {
    _specialtiesStreamController.add(_specialties.values.toList());
  }

  // --- SEED DATA ---
  void _seedInitialData() {
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();

    // 1. Users
    final patientUser = UserModel(
      id: 'patient_001',
      email: 'patient@healthcare.com',
      displayName: 'Sarah Jenkins',
      role: UserRole.patient,
      phoneNumber: '+1 (555) 234-5678',
      dateOfBirth: '1992-04-15',
      gender: 'Female',
      bloodGroup: 'O+',
      emergencyContact: '+1 (555) 987-6543',
      medicalAllergies: 'Penicillin, Peanuts',
      createdAt: nowIso,
      updatedAt: nowIso,
    );

    final doctorUser1 = UserModel(
      id: 'doctor_user_001',
      email: 'doctor@healthcare.com',
      displayName: 'Dr. Emily Stone',
      role: UserRole.doctor,
      phoneNumber: '+1 (555) 432-1098',
      createdAt: nowIso,
      updatedAt: nowIso,
    );

    final doctorUser2 = UserModel(
      id: 'doctor_user_002',
      email: 'doctor2@healthcare.com',
      displayName: 'Dr. Alex Morgan',
      role: UserRole.doctor,
      phoneNumber: '+1 (555) 876-5432',
      createdAt: nowIso,
      updatedAt: nowIso,
    );

    final doctorUser3 = UserModel(
      id: 'doctor_user_003',
      email: 'doctor3@healthcare.com',
      displayName: 'Dr. Marcus Vance',
      role: UserRole.doctor,
      phoneNumber: '+1 (555) 345-6789',
      createdAt: nowIso,
      updatedAt: nowIso,
    );

    final adminUser = UserModel(
      id: 'admin_001',
      email: 'admin@healthcare.com',
      displayName: 'Admin Mark',
      role: UserRole.admin,
      phoneNumber: '+1 (555) 111-2222',
      createdAt: nowIso,
      updatedAt: nowIso,
    );

    _users[patientUser.id] = patientUser;
    _users[doctorUser1.id] = doctorUser1;
    _users[doctorUser2.id] = doctorUser2;
    _users[doctorUser3.id] = doctorUser3;
    _users[adminUser.id] = adminUser;

    // 2. Specialties
    final specialtiesList = [
      const SpecialtyModel(
        id: 'spec_cardiology',
        name: 'Cardiology',
        description: 'Heart, blood vessels & cardiovascular system',
        iconName: 'favorite_rounded',
        activeDoctorCount: 12,
      ),
      const SpecialtyModel(
        id: 'spec_dermatology',
        name: 'Dermatology',
        description: 'Skin, hair, nails & cosmetic health',
        iconName: 'spa_rounded',
        activeDoctorCount: 8,
      ),
      const SpecialtyModel(
        id: 'spec_pediatrics',
        name: 'Pediatrics',
        description: 'Infant, child & adolescent healthcare',
        iconName: 'child_care_rounded',
        activeDoctorCount: 15,
      ),
      const SpecialtyModel(
        id: 'spec_general',
        name: 'General Medicine',
        description: 'Comprehensive primary health & routine wellness',
        iconName: 'medical_services_rounded',
        activeDoctorCount: 22,
      ),
      const SpecialtyModel(
        id: 'spec_orthopedics',
        name: 'Orthopedics',
        description: 'Bones, joints, ligaments & spine care',
        iconName: 'accessibility_new_rounded',
        activeDoctorCount: 9,
      ),
      const SpecialtyModel(
        id: 'spec_neurology',
        name: 'Neurology',
        description: 'Brain, spinal cord & nervous system',
        iconName: 'psychology_rounded',
        activeDoctorCount: 6,
      ),
    ];
    for (var s in specialtiesList) {
      _specialties[s.id] = s;
    }

    // 3. Doctors
    const standardAvailability = {
      'monday': [TimeWindow(start: '09:00', end: '13:00'), TimeWindow(start: '14:00', end: '17:00')],
      'tuesday': [TimeWindow(start: '09:00', end: '13:00'), TimeWindow(start: '14:00', end: '17:00')],
      'wednesday': [TimeWindow(start: '09:00', end: '13:00'), TimeWindow(start: '14:00', end: '17:00')],
      'thursday': [TimeWindow(start: '09:00', end: '13:00'), TimeWindow(start: '14:00', end: '17:00')],
      'friday': [TimeWindow(start: '09:00', end: '14:00')],
    };

    final doc1 = DoctorModel(
      id: 'doc_001',
      userId: doctorUser1.id,
      doctorName: 'Dr. Emily Stone, MD',
      specialtyId: 'spec_cardiology',
      specialtyName: 'Cardiology',
      licenseNumber: 'MD-84920-CARD',
      experienceYears: 14,
      consultationFee: 75.0,
      currency: 'USD',
      bio: 'Senior Cardiologist specializing in preventative heart care, hypertension management, and echocardiography. Former Chief Resident at Johns Hopkins.',
      rating: 4.9,
      reviewCount: 128,
      verificationStatus: VerificationStatus.approved,
      documentUrls: const ['https://example.com/docs/license_stone.pdf'],
      weeklyAvailability: standardAvailability,
      slotDurationMinutes: 30,
    );

    final doc2 = DoctorModel(
      id: 'doc_002',
      userId: doctorUser2.id,
      doctorName: 'Dr. Alex Morgan, DO',
      specialtyId: 'spec_dermatology',
      specialtyName: 'Dermatology',
      licenseNumber: 'DO-31902-DERM',
      experienceYears: 6,
      consultationFee: 60.0,
      currency: 'USD',
      bio: 'Board-certified Dermatologist focusing on adult acne, eczema, and dermoscopy screening. Committed to compassionate skin health.',
      rating: 4.7,
      reviewCount: 45,
      verificationStatus: VerificationStatus.pending,
      documentUrls: const ['https://example.com/docs/license_morgan.pdf'],
      weeklyAvailability: standardAvailability,
      slotDurationMinutes: 30,
    );

    final doc3 = DoctorModel(
      id: 'doc_003',
      userId: doctorUser3.id,
      doctorName: 'Dr. Marcus Vance, MD',
      specialtyId: 'spec_pediatrics',
      specialtyName: 'Pediatrics',
      licenseNumber: 'MD-90184-PED',
      experienceYears: 18,
      consultationFee: 70.0,
      currency: 'USD',
      bio: 'Pediatric care expert with extensive experience in developmental milestones, childhood immunology, and adolescent medicine.',
      rating: 4.95,
      reviewCount: 210,
      verificationStatus: VerificationStatus.approved,
      documentUrls: const ['https://example.com/docs/license_vance.pdf'],
      weeklyAvailability: standardAvailability,
      slotDurationMinutes: 30,
    );

    _doctors[doc1.id] = doc1;
    _doctors[doc2.id] = doc2;
    _doctors[doc3.id] = doc3;

    // 4. Appointments & Slots
    // Tomorrow at 10:00 AM UTC
    final tomorrow10AmUtc = DateTime.utc(now.year, now.month, now.day + 1, 10, 0);
    final tomorrow10AmUtcStr = tomorrow10AmUtc.toIso8601String();
    final tomorrowSlotKey = DateTimeUtils.generateSlotKey(doc1.id, tomorrow10AmUtc);

    final apt1 = AppointmentModel(
      id: 'apt_001',
      patientId: patientUser.id,
      patientName: patientUser.displayName,
      patientEmail: patientUser.email,
      doctorId: doc1.id,
      doctorName: doc1.doctorName,
      doctorSpecialty: doc1.specialtyName,
      scheduledTimeUtc: tomorrow10AmUtcStr,
      durationMinutes: 30,
      status: AppointmentStatus.confirmed,
      statusHistory: [
        StatusHistoryEntry(
          status: AppointmentStatus.requested,
          timestampUtc: now.subtract(const Duration(hours: 4)).toIso8601String(),
          byUserId: patientUser.id,
          note: 'Initial booking',
        ),
        StatusHistoryEntry(
          status: AppointmentStatus.confirmed,
          timestampUtc: now.subtract(const Duration(hours: 3)).toIso8601String(),
          byUserId: doc1.userId,
          note: 'Doctor approved request',
        ),
      ],
      reasonForVisit: 'Occasional chest tightness and routine blood pressure follow-up.',
      videoRoomId: 'room_apt_001',
      createdAt: now.subtract(const Duration(hours: 4)).toIso8601String(),
      updatedAt: now.subtract(const Duration(hours: 3)).toIso8601String(),
    );

    _appointments[apt1.id] = apt1;
    _bookedSlots[tomorrowSlotKey] = apt1.id;

    // Past completed appointment with prescription
    final pastTimeUtc = now.subtract(const Duration(days: 7, hours: 2));
    final pastTimeUtcStr = pastTimeUtc.toIso8601String();
    final pastSlotKey = DateTimeUtils.generateSlotKey(doc1.id, pastTimeUtc);

    final aptCompleted = AppointmentModel(
      id: 'apt_past_001',
      patientId: patientUser.id,
      patientName: patientUser.displayName,
      patientEmail: patientUser.email,
      doctorId: doc1.id,
      doctorName: doc1.doctorName,
      doctorSpecialty: doc1.specialtyName,
      scheduledTimeUtc: pastTimeUtcStr,
      durationMinutes: 30,
      status: AppointmentStatus.completed,
      statusHistory: [
        StatusHistoryEntry(
          status: AppointmentStatus.completed,
          timestampUtc: pastTimeUtc.add(const Duration(minutes: 35)).toIso8601String(),
          byUserId: doc1.userId,
          note: 'Consultation concluded',
        ),
      ],
      reasonForVisit: 'Severe migraine and light sensitivity.',
      consultationNotes: 'Patient showed symptoms of tension-type migraine exacerbated by screen fatigue. Advised hydration and sleep hygiene.',
      prescriptionId: 'rx_001',
      videoRoomId: 'room_apt_past_001',
      createdAt: pastTimeUtc.subtract(const Duration(days: 1)).toIso8601String(),
      updatedAt: pastTimeUtc.add(const Duration(minutes: 35)).toIso8601String(),
    );

    _appointments[aptCompleted.id] = aptCompleted;
    _bookedSlots[pastSlotKey] = aptCompleted.id;

    // 5. Prescription for completed appointment
    final rx1 = PrescriptionModel(
      id: 'rx_001',
      appointmentId: aptCompleted.id,
      patientId: patientUser.id,
      patientName: patientUser.displayName,
      doctorId: doc1.id,
      doctorName: doc1.doctorName,
      doctorSpecialty: doc1.specialtyName,
      diagnosis: 'Tension-type Cephalea / Migraine with photo-sensitivity',
      medications: const [
        MedicationItem(
          name: 'Sumatriptan',
          dosage: '50mg',
          frequency: 'Single dose at onset of migraine',
          duration: 'As needed (max 2/day)',
          instructions: 'Take with plenty of water. Do not exceed 100mg in 24 hours.',
        ),
        MedicationItem(
          name: 'Magnesium Glycinate',
          dosage: '400mg',
          frequency: 'Once daily before bed',
          duration: '30 days',
          instructions: 'Supports neurological relaxation and preventive care.',
        ),
      ],
      notes: 'Follow up in 3 weeks if symptoms do not alleviate. Avoid bright displays 1 hour before sleep.',
      issuedAtUtc: pastTimeUtc.add(const Duration(minutes: 30)).toIso8601String(),
    );
    _prescriptions[rx1.id] = rx1;

    // 6. Sample Chat for apt1
    _appointmentChats[apt1.id] = [
      ChatMessageModel(
        id: 'msg_001',
        appointmentId: apt1.id,
        senderId: patientUser.id,
        senderName: patientUser.displayName,
        senderRole: 'patient',
        content: 'Hello Dr. Stone, I have uploaded my recent BP log.',
        sentAtUtc: now.subtract(const Duration(hours: 2)).toIso8601String(),
      ),
      ChatMessageModel(
        id: 'msg_002',
        appointmentId: apt1.id,
        senderId: doc1.userId,
        senderName: doc1.doctorName,
        senderRole: 'doctor',
        content: 'Thank you Sarah! I see the numbers. We will discuss them in our call tomorrow.',
        sentAtUtc: now.subtract(const Duration(hours: 1)).toIso8601String(),
      ),
    ];
  }

  // --- USER OPERATIONS ---
  Future<UserModel?> getUserById(String id) async => _users[id];
  Future<UserModel?> getUserByEmail(String email) async {
    final clean = email.toLowerCase().trim();
    for (var u in _users.values) {
      if (u.email.toLowerCase().trim() == clean) return u;
    }
    return null;
  }

  Future<void> saveUser(UserModel user) async {
    _users[user.id] = user;
  }

  List<UserModel> getAllUsers() => _users.values.toList();

  // --- DOCTOR OPERATIONS ---
  List<DoctorModel> getDoctors({
    String? specialtyId,
    String? query,
    double? minRating,
    double? maxFee,
    bool onlyVerified = true,
  }) {
    return _doctors.values.where((doc) {
      if (onlyVerified && !doc.isVerified) return false;
      if (specialtyId != null && specialtyId.isNotEmpty && doc.specialtyId != specialtyId) {
        return false;
      }
      if (minRating != null && doc.rating < minRating) return false;
      if (maxFee != null && doc.consultationFee > maxFee) return false;
      if (query != null && query.trim().isNotEmpty) {
        final q = query.toLowerCase().trim();
        final matchName = doc.doctorName.toLowerCase().contains(q);
        final matchSpec = doc.specialtyName.toLowerCase().contains(q);
        final matchBio = doc.bio.toLowerCase().contains(q);
        if (!matchName && !matchSpec && !matchBio) return false;
      }
      return true;
    }).toList();
  }

  DoctorModel? getDoctorById(String id) => _doctors[id];
  DoctorModel? getDoctorByUserId(String userId) {
    for (var d in _doctors.values) {
      if (d.userId == userId) return d;
    }
    return null;
  }

  Future<void> updateDoctor(DoctorModel doctor) async {
    _doctors[doctor.id] = doctor;
    _notifyDoctors();
  }

  List<DoctorModel> getPendingVerificationDoctors() {
    return _doctors.values
        .where((d) => d.verificationStatus == VerificationStatus.pending)
        .toList();
  }

  // --- SPECIALTY OPERATIONS ---
  List<SpecialtyModel> getSpecialties() => _specialties.values.toList();
  Future<void> saveSpecialty(SpecialtyModel specialty) async {
    _specialties[specialty.id] = specialty;
    _notifySpecialties();
  }

  // --- APPOINTMENT & CONCURRENCY TRANSACTION (Challenge #1) ---

  /// Checks if a slot is currently booked
  bool isSlotBooked(String doctorId, DateTime slotUtc) {
    final key = DateTimeUtils.generateSlotKey(doctorId, slotUtc);
    return _bookedSlots.containsKey(key);
  }

  /// Atomic Slot Booking Transaction (Challenge #1: Concurrency Control)
  /// Guaranteed single winner under race conditions.
  Future<AppointmentModel> bookAppointmentTransaction({
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

    // Concurrency Lock Check
    if (_bookedSlots.containsKey(slotKey)) {
      throw const SlotAlreadyBookedException();
    }

    final appointmentId = 'apt_${_uuid.v4().substring(0, 8)}';
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final scheduledUtcStr = scheduledTimeUtc.toUtc().toIso8601String();

    // Lock the slot
    _bookedSlots[slotKey] = appointmentId;

    final appointment = AppointmentModel(
      id: appointmentId,
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
      videoRoomId: 'room_$appointmentId',
      createdAt: nowIso,
      updatedAt: nowIso,
    );

    _appointments[appointmentId] = appointment;
    _notifyAppointments();
    return appointment;
  }

  /// Transitions an appointment according to state machine rules
  Future<AppointmentModel> updateAppointmentStatus({
    required String appointmentId,
    required AppointmentStatus targetStatus,
    required String actorUserId,
    bool isPatientActor = false,
    String? note,
    String? cancellationReason,
  }) async {
    final current = _appointments[appointmentId];
    if (current == null) {
      throw const NotFoundException('Appointment not found.');
    }

    final updated = AppointmentStateMachine.transition(
      appointment: current,
      targetStatus: targetStatus,
      actorUserId: actorUserId,
      isPatientActor: isPatientActor,
      note: note,
      cancellationReason: cancellationReason,
    );

    // If cancelled or rejected, release slot
    if (targetStatus == AppointmentStatus.cancelled || targetStatus == AppointmentStatus.rejected) {
      final slotKey = DateTimeUtils.generateSlotKey(
        current.doctorId,
        DateTime.parse(current.scheduledTimeUtc),
      );
      _bookedSlots.remove(slotKey);
    }

    _appointments[appointmentId] = updated;
    _notifyAppointments();
    return updated;
  }

  /// Reschedules an appointment to a new slot with atomic collision check
  Future<AppointmentModel> rescheduleAppointment({
    required String appointmentId,
    required DateTime newScheduledTimeUtc,
    required String actorUserId,
  }) async {
    final current = _appointments[appointmentId];
    if (current == null) {
      throw const NotFoundException('Appointment not found.');
    }

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

    if (_bookedSlots.containsKey(newSlotKey) && _bookedSlots[newSlotKey] != appointmentId) {
      throw const SlotAlreadyBookedException('The newly selected slot is unavailable.');
    }

    // Release old slot and lock new slot
    _bookedSlots.remove(oldSlotKey);
    _bookedSlots[newSlotKey] = appointmentId;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final updated = current.copyWith(
      scheduledTimeUtc: newScheduledTimeUtc.toUtc().toIso8601String(),
      status: AppointmentStatus.requested, // Needs re-approval upon reschedule
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

    _appointments[appointmentId] = updated;
    _notifyAppointments();
    return updated;
  }

  List<AppointmentModel> getAppointmentsForPatient(String patientId) {
    return _appointments.values
        .where((a) => a.patientId == patientId)
        .toList()
      ..sort((a, b) => b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc));
  }

  List<AppointmentModel> getAppointmentsForDoctor(String doctorId) {
    return _appointments.values
        .where((a) => a.doctorId == doctorId)
        .toList()
      ..sort((a, b) => b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc));
  }

  List<AppointmentModel> getAllAppointments() {
    return _appointments.values.toList()
      ..sort((a, b) => b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc));
  }

  AppointmentModel? getAppointmentById(String id) => _appointments[id];

  // --- PRESCRIPTION OPERATIONS ---
  Future<PrescriptionModel> createPrescription(PrescriptionModel prescription) async {
    _prescriptions[prescription.id] = prescription;
    // Link to appointment
    final apt = _appointments[prescription.appointmentId];
    if (apt != null) {
      _appointments[apt.id] = apt.copyWith(prescriptionId: prescription.id);
      _notifyAppointments();
    }
    return prescription;
  }

  PrescriptionModel? getPrescriptionById(String id) => _prescriptions[id];
  PrescriptionModel? getPrescriptionForAppointment(String appointmentId) {
    for (var p in _prescriptions.values) {
      if (p.appointmentId == appointmentId) return p;
    }
    return null;
  }

  List<PrescriptionModel> getPrescriptionsForPatient(String patientId) {
    return _prescriptions.values.where((p) => p.patientId == patientId).toList();
  }

  // --- CHAT OPERATIONS ---
  List<ChatMessageModel> getMessagesForAppointment(String appointmentId) {
    return _appointmentChats[appointmentId] ?? [];
  }

  Future<ChatMessageModel> sendMessage({
    required String appointmentId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String content,
  }) async {
    final msg = ChatMessageModel(
      id: 'msg_${_uuid.v4().substring(0, 8)}',
      appointmentId: appointmentId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      content: content,
      sentAtUtc: DateTime.now().toUtc().toIso8601String(),
    );

    _appointmentChats.putIfAbsent(appointmentId, () => []).add(msg);
    return msg;
  }
}
