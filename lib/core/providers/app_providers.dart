import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare_app/core/services/notification_service.dart';
import 'package:healthcare_app/core/services/preferences_service.dart';
import 'package:healthcare_app/features/admin/domain/entities/admin_analytics_model.dart';
import 'package:healthcare_app/features/admin/domain/entities/admin_notification_model.dart';
import 'package:healthcare_app/features/auth/domain/entities/user_model.dart';
import 'package:healthcare_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:healthcare_app/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:healthcare_app/features/consultation/domain/entities/chat_message_model.dart';
import 'package:healthcare_app/features/consultation/domain/entities/prescription_model.dart';
import 'package:healthcare_app/features/doctor/domain/entities/doctor_model.dart';
import 'package:healthcare_app/features/doctor/domain/entities/specialty_model.dart';
import 'package:healthcare_app/features/doctor/domain/repositories/doctor_repository.dart';
import 'package:healthcare_app/features/doctor/data/repositories/firebase_doctor_repository.dart';
import 'package:healthcare_app/features/appointment/domain/entities/appointment_model.dart';
import 'package:healthcare_app/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:healthcare_app/features/appointment/data/repositories/firebase_appointment_repository.dart';

// --- PATIENT NOTIFICATIONS & LIVE CONSULTATION STREAMS ---
class PatientNotificationItem {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final String createdAt;
  final bool isRead;

  const PatientNotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  factory PatientNotificationItem.fromMap(Map<String, dynamic> map, {required String id}) {
    return PatientNotificationItem(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? 'Notification',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'general',
      createdAt: map['createdAt'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}

final patientNotificationsStreamProvider = StreamProvider<List<PatientNotificationItem>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();

  try {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.id)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => PatientNotificationItem.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).handleError((_) => <PatientNotificationItem>[]);
  } catch (_) {
    return Stream.value(<PatientNotificationItem>[]);
  }
});

final unreadPatientNotificationsCountProvider = Provider<int>((ref) {
  final asyncVal = ref.watch(patientNotificationsStreamProvider);
  return asyncVal.valueOrNull?.where((n) => !n.isRead).length ?? 0;
});

final appointmentMessagesStreamProvider =
    StreamProvider.family<List<ChatMessageModel>, String>((ref, appointmentId) {
  return FirebaseFirestore.instance
      .collection('appointments')
      .doc(appointmentId)
      .collection('messages')
      .orderBy('sentAtUtc', descending: false)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((d) => ChatMessageModel.fromMap(d.data(), id: d.id)).toList());
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(PreferencesService.instance.getThemeMode());

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await PreferencesService.instance.setThemeMode(mode);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// --- ADMIN NOTIFICATION READ STATE & PREFERENCES ---
class ReadNotificationsNotifier extends StateNotifier<Set<String>> {
  ReadNotificationsNotifier()
      : super(PreferencesService.instance.getReadNotificationIds());

  Future<void> markAsRead(String id) async {
    if (state.contains(id)) return;
    state = {...state, id};
    await PreferencesService.instance.markNotificationRead(id);
  }

  Future<void> markAllAsRead(Iterable<String> ids) async {
    final next = {...state, ...ids};
    if (next.length == state.length) return;
    state = next;
    await PreferencesService.instance.markNotificationsRead(ids);
  }
}

final readNotificationsProvider =
    StateNotifierProvider<ReadNotificationsNotifier, Set<String>>((ref) {
  return ReadNotificationsNotifier();
});

// --- LIVE FIREBASE REPOSITORIES ---
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final doctorRepositoryProvider = Provider<DoctorRepository>((ref) {
  return FirebaseDoctorRepository();
});

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return FirebaseAppointmentRepository();
});

// --- AUTH STATE ---
final currentUserStreamProvider = StreamProvider<UserModel?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges();
});

final currentUserProvider = StateProvider<UserModel?>((ref) {
  final asyncUser = ref.watch(currentUserStreamProvider);
  return asyncUser.value;
});

// --- DOCTORS & SPECIALTIES (REAL-TIME STREAMS) ---
final specialtiesProvider = StreamProvider<List<SpecialtyModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('specialties')
      .snapshots()
      .map((s) => s.docs.map((d) => SpecialtyModel.fromMap(d.data(), id: d.id)).toList());
});

class DoctorFilterState {
  final String? specialtyId;
  final String? query;
  final double? minRating;
  final double? maxFee;

  const DoctorFilterState({
    this.specialtyId,
    this.query,
    this.minRating,
    this.maxFee,
  });

  DoctorFilterState copyWith({
    String? specialtyId,
    String? query,
    double? minRating,
    double? maxFee,
    bool clearSpecialty = false,
  }) {
    return DoctorFilterState(
      specialtyId: clearSpecialty ? null : (specialtyId ?? this.specialtyId),
      query: query ?? this.query,
      minRating: minRating ?? this.minRating,
      maxFee: maxFee ?? this.maxFee,
    );
  }
}

final doctorFilterProvider = StateProvider<DoctorFilterState>((ref) {
  return const DoctorFilterState();
});

final filteredDoctorsProvider = FutureProvider<List<DoctorModel>>((ref) async {
  final repo = ref.watch(doctorRepositoryProvider);
  final filter = ref.watch(doctorFilterProvider);
  return repo.getDoctors(
    specialtyId: filter.specialtyId,
    query: filter.query,
    minRating: filter.minRating,
    maxFee: filter.maxFee,
  );
});

// --- APPOINTMENTS ---
final userAppointmentsProvider = FutureProvider<List<AppointmentModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final repo = ref.watch(appointmentRepositoryProvider);

  if (user.isPatient) {
    return repo.getAppointmentsForPatient(user.id);
  } else if (user.isDoctor) {
    final docRepo = ref.watch(doctorRepositoryProvider);
    final doc = await docRepo.getDoctorByUserId(user.id);
    if (doc == null) return [];
    return repo.getAppointmentsForDoctor(doc.id);
  } else {
    return repo.getAllAppointments();
  }
});

final verifiedDoctorsStreamProvider = StreamProvider<List<DoctorModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('doctors')
      .where('verificationStatus', isEqualTo: 'approved')
      .snapshots()
      .map((s) => s.docs.map((d) => DoctorModel.fromMap(d.data(), id: d.id)).toList());
});

// --- ADMIN LIVE DIRECTORY, APPOINTMENTS, PRESCRIPTIONS & NOTIFICATIONS ---
final allDoctorsAdminProvider = StreamProvider<List<DoctorModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('doctors')
      .snapshots()
      .map((s) => s.docs.map((d) => DoctorModel.fromMap(d.data(), id: d.id)).toList());
});

final allPatientsAdminProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'patient')
      .snapshots()
      .map((s) => s.docs.map((d) => UserModel.fromMap(d.data(), id: d.id)).toList());
});

final allAppointmentsAdminProvider = StreamProvider<List<AppointmentModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('appointments')
      .snapshots()
      .map((s) {
        final list = s.docs
            .map((d) => AppointmentModel.fromMap(d.data(), id: d.id))
            .toList();
        list.sort((a, b) => b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc));
        return list;
      });
});

final allPrescriptionsAdminProvider = StreamProvider<List<PrescriptionModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('prescriptions')
      .snapshots()
      .map((s) {
        final list = s.docs
            .map((d) => PrescriptionModel.fromMap(d.data(), id: d.id))
            .toList();
        list.sort((a, b) => b.issuedAtUtc.compareTo(a.issuedAtUtc));
        return list;
      });
});

final pendingDoctorsProvider = StreamProvider<List<DoctorModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('doctors')
      .where('verificationStatus', isEqualTo: 'pending')
      .snapshots()
      .map((s) {
        final pendingList = s.docs
            .map((d) => DoctorModel.fromMap(d.data(), id: d.id))
            .toList();

        // Trigger local notification for newly arrived pending doctor applications
        final user = ref.read(currentUserProvider);
        if (user != null &&
            user.isAdmin &&
            PreferencesService.instance.getDoctorVerificationAlertsEnabled()) {
          final alerted = PreferencesService.instance.getAlertedNotificationIds();
          for (final doc in pendingList) {
            final notifId = 'doc_verify_${doc.id}';
            if (!alerted.contains(notifId)) {
              PreferencesService.instance.markNotificationAlerted(notifId);
              NotificationService.instance.showLocalNotification(
                title: 'New Doctor Verification Request',
                body: '${doc.doctorName} (${doc.specialtyName}) submitted credentials for review.',
                payload: 'doctor_verify:${doc.id}:$notifId',
              );
            }
          }
        }
        return pendingList;
      });
});

/// Combines Doctor Verification items & Appointment/Prescription activity into a unified Admin Notification list.
final adminNotificationsProvider = Provider<List<AdminNotificationItem>>((ref) {
  final doctors = ref.watch(allDoctorsAdminProvider).valueOrNull ?? [];
  final appointments = ref.watch(allAppointmentsAdminProvider).valueOrNull ?? [];
  final prescriptions = ref.watch(allPrescriptionsAdminProvider).valueOrNull ?? [];

  final items = <AdminNotificationItem>[];

  // 1. Pending doctors first (Actionable)
  for (final doc in doctors) {
    if (doc.verificationStatus == VerificationStatus.pending) {
      items.add(
        AdminNotificationItem(
          id: 'doc_verify_${doc.id}',
          title: 'Credential Review Required: ${doc.doctorName}',
          subtitle:
              '${doc.specialtyName} • License ${doc.licenseNumber} • ${doc.experienceYears} yrs experience',
          timestampIso: DateTime.now().toUtc().toIso8601String(),
          type: AdminNotificationType.doctorVerification,
          targetId: doc.id,
          isActionable: true,
          statusLabel: 'Pending Approval',
        ),
      );
    }
  }

  // 2. Recent appointments (Requested, Confirmed, In Progress, Cancelled, Completed)
  for (final apt in appointments) {
    final statusText = switch (apt.status) {
      AppointmentStatus.requested => 'New Booking Request',
      AppointmentStatus.confirmed => 'Appointment Confirmed',
      AppointmentStatus.inProgress => 'Consultation In Progress',
      AppointmentStatus.completed => 'Consultation Completed',
      AppointmentStatus.cancelled => 'Appointment Cancelled',
      AppointmentStatus.rejected => 'Appointment Declined',
    };
    items.add(
      AdminNotificationItem(
        id: 'apt_${apt.id}_${apt.status.name}',
        title: '$statusText • ${apt.patientName}',
        subtitle: 'With ${apt.doctorName} (${apt.doctorSpecialty}) — ${apt.reasonForVisit}',
        timestampIso: apt.updatedAt.isNotEmpty ? apt.updatedAt : apt.scheduledTimeUtc,
        type: AdminNotificationType.appointmentActivity,
        targetId: apt.id,
        isActionable: true,
        statusLabel: apt.status.displayName,
      ),
    );
  }

  // 3. Prescriptions issued
  for (final rx in prescriptions) {
    items.add(
      AdminNotificationItem(
        id: 'rx_${rx.id}',
        title: 'Prescription Issued to ${rx.patientName}',
        subtitle: '${rx.doctorName} • Diagnosis: ${rx.diagnosis}',
        timestampIso: rx.issuedAtUtc,
        type: AdminNotificationType.prescriptionIssued,
        targetId: rx.id,
        isActionable: true,
        statusLabel: 'Prescription',
      ),
    );
  }

  // 4. Resolved doctor verifications (Approved / Rejected) — ONLY for doctors that previously triggered a verification notification
  final alertedIds = PreferencesService.instance.getAlertedNotificationIds();
  final readIds = ref.watch(readNotificationsProvider);
  for (final doc in doctors) {
    final notifId = 'doc_verify_${doc.id}';
    if (doc.verificationStatus != VerificationStatus.pending &&
        (alertedIds.contains(notifId) || readIds.contains(notifId))) {
      final isApproved = doc.verificationStatus == VerificationStatus.approved;
      items.add(
        AdminNotificationItem(
          id: notifId,
          title: 'Doctor Verification: ${doc.doctorName}',
          subtitle: '${doc.specialtyName} • License ${doc.licenseNumber}',
          timestampIso: DateTime.now().toUtc().toIso8601String(),
          type: AdminNotificationType.doctorVerification,
          targetId: doc.id,
          isActionable: false,
          statusLabel: isApproved ? 'Resolved • Approved' : 'Resolved • Declined',
        ),
      );
    }
  }

  return items;
});

final adminAnalyticsProvider = StreamProvider<AdminAnalyticsModel>((ref) {
  final firestore = FirebaseFirestore.instance;

  return firestore.collection('doctors').snapshots().asyncMap((docSnap) async {
    final allDoctors = docSnap.docs
        .map((d) => DoctorModel.fromMap(d.data(), id: d.id))
        .toList();

    final specialtiesSnap = await firestore.collection('specialties').get();
    final specialties = specialtiesSnap.docs
        .map((d) => SpecialtyModel.fromMap(d.data(), id: d.id))
        .toList();

    final appointmentsSnap = await firestore.collection('appointments').get();
    final appointments = appointmentsSnap.docs
        .map((d) => AppointmentModel.fromMap(d.data(), id: d.id))
        .toList();

    int prescriptionCount = 0;
    try {
      final rxSnap = await firestore.collection('prescriptions').get();
      prescriptionCount = rxSnap.docs.length;
    } catch (_) {}

    int patientCount = 0;
    try {
      final usersSnap = await firestore
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .get();
      patientCount = usersSnap.docs.length;
    } catch (_) {}

    final verifiedDocs = allDoctors
        .where((d) => d.verificationStatus == VerificationStatus.approved)
        .toList();
    final pendingDocs = allDoctors
        .where((d) => d.verificationStatus == VerificationStatus.pending)
        .toList();
    final rejectedDocs = allDoctors
        .where((d) => d.verificationStatus == VerificationStatus.rejected)
        .toList();

    final Map<String, int> docCountBySpec = {};
    final Map<String, double> avgFeeBySpec = {};
    for (final spec in specialties) {
      final specDocs = verifiedDocs.where((d) => d.specialtyId == spec.id).toList();
      docCountBySpec[spec.id] = specDocs.length;
      if (specDocs.isNotEmpty) {
        final totalSpecFee = specDocs.fold<double>(0.0, (acc, d) => acc + d.consultationFee);
        avgFeeBySpec[spec.id] = totalSpecFee / specDocs.length;
      } else {
        avgFeeBySpec[spec.id] = 0.0;
      }
    }

    double avgFee = 0.0;
    double minFee = 0.0;
    double maxFee = 0.0;
    double avgExp = 0.0;
    double avgRating = 0.0;
    int totalReviews = 0;

    if (verifiedDocs.isNotEmpty) {
      final fees = verifiedDocs.map((d) => d.consultationFee).toList()..sort();
      minFee = fees.first;
      maxFee = fees.last;
      avgFee = fees.fold<double>(0.0, (a, b) => a + b) / verifiedDocs.length;
      avgExp = verifiedDocs.fold<int>(0, (a, d) => a + d.experienceYears) / verifiedDocs.length;
      avgRating = verifiedDocs.fold<double>(0.0, (a, d) => a + d.rating) / verifiedDocs.length;
      totalReviews = verifiedDocs.fold<int>(0, (a, d) => a + d.reviewCount);
    }

    final sortedTopDoctors = List<DoctorModel>.from(verifiedDocs)
      ..sort((a, b) {
        final ratingCmp = b.rating.compareTo(a.rating);
        if (ratingCmp != 0) return ratingCmp;
        return b.reviewCount.compareTo(a.reviewCount);
      });

    final completedCount = appointments
        .where((a) => a.status == AppointmentStatus.completed)
        .length;
    final cancelledCount = appointments
        .where((a) => a.status == AppointmentStatus.cancelled)
        .length;
    final upcomingCount = appointments
        .where(
          (a) =>
              a.status == AppointmentStatus.requested ||
              a.status == AppointmentStatus.confirmed ||
              a.status == AppointmentStatus.inProgress,
        )
        .length;

    return AdminAnalyticsModel(
      totalPatients: patientCount,
      verifiedDoctors: verifiedDocs.length,
      pendingVerifications: pendingDocs.length,
      rejectedDoctors: rejectedDocs.length,
      totalSpecialties: specialties.length,
      totalAppointments: appointments.length,
      upcomingAppointments: upcomingCount,
      completedAppointments: completedCount,
      cancelledAppointments: cancelledCount,
      totalPrescriptions: prescriptionCount,
      avgConsultationFee: avgFee,
      minConsultationFee: minFee,
      maxConsultationFee: maxFee,
      avgExperienceYears: avgExp,
      avgDoctorRating: avgRating,
      totalReviewsCount: totalReviews,
      doctorCountBySpecialtyId: docCountBySpec,
      avgFeeBySpecialtyId: avgFeeBySpec,
      topDoctors: sortedTopDoctors.take(4).toList(),
    );
  });
});
