import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare_app/core/services/preferences_service.dart';
import 'package:healthcare_app/features/admin/domain/entities/admin_analytics_model.dart';
import 'package:healthcare_app/features/auth/domain/entities/user_model.dart';
import 'package:healthcare_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:healthcare_app/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:healthcare_app/features/doctor/domain/entities/doctor_model.dart';
import 'package:healthcare_app/features/doctor/domain/entities/specialty_model.dart';
import 'package:healthcare_app/features/doctor/domain/repositories/doctor_repository.dart';
import 'package:healthcare_app/features/doctor/data/repositories/firebase_doctor_repository.dart';
import 'package:healthcare_app/features/appointment/domain/entities/appointment_model.dart';
import 'package:healthcare_app/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:healthcare_app/features/appointment/data/repositories/firebase_appointment_repository.dart';

// --- THEME PREFERENCE STATE ---
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

// --- ADMIN LIVE METRICS & VERIFICATIONS (REAL-TIME STREAMS) ---
final pendingDoctorsProvider = StreamProvider<List<DoctorModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('doctors')
      .where('verificationStatus', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map((d) => DoctorModel.fromMap(d.data(), id: d.id)).toList());
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
