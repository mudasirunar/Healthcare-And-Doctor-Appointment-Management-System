import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// --- DOCTORS & SPECIALTIES ---
final specialtiesProvider = FutureProvider<List<SpecialtyModel>>((ref) async {
  final repo = ref.watch(doctorRepositoryProvider);
  return repo.getSpecialties();
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
