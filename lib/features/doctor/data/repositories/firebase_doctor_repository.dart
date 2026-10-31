import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/entities/doctor_model.dart';
import '../../domain/entities/specialty_model.dart';
import '../../domain/repositories/doctor_repository.dart';

/// Cloud Firestore implementation of DoctorRepository with search, filters & admin approval.
class FirebaseDoctorRepository implements DoctorRepository {
  final FirebaseFirestore _firestore;

  FirebaseDoctorRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<DoctorModel>> getDoctors({
    String? specialtyId,
    String? query,
    double? minRating,
    double? maxFee,
    bool onlyVerified = true,
  }) async {
    Query<Map<String, dynamic>> ref = _firestore.collection('doctors');

    if (onlyVerified) {
      ref = ref.where('verificationStatus', isEqualTo: 'approved');
    }

    if (specialtyId != null && specialtyId.isNotEmpty) {
      ref = ref.where('specialtyId', isEqualTo: specialtyId);
    }

    final querySnapshot = await ref.get();
    var docs = querySnapshot.docs.map((d) => DoctorModel.fromMap(d.data(), id: d.id)).toList();

    // Client-side filtering for complex criteria (ratings, fee ceilings, and search text)
    if (minRating != null) {
      docs = docs.where((d) => d.rating >= minRating).toList();
    }
    if (maxFee != null) {
      docs = docs.where((d) => d.consultationFee <= maxFee).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      docs = docs.where((d) {
        return d.doctorName.toLowerCase().contains(q) ||
            d.specialtyName.toLowerCase().contains(q) ||
            d.bio.toLowerCase().contains(q);
      }).toList();
    }

    return docs;
  }

  @override
  Future<DoctorModel?> getDoctorById(String id) async {
    final docSnapshot = await _firestore.collection('doctors').doc(id).get();
    if (!docSnapshot.exists || docSnapshot.data() == null) return null;
    return DoctorModel.fromMap(docSnapshot.data()!, id: docSnapshot.id);
  }

  @override
  Future<DoctorModel?> getDoctorByUserId(String userId) async {
    final querySnapshot = await _firestore
        .collection('doctors')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (querySnapshot.docs.isEmpty) return null;
    final d = querySnapshot.docs.first;
    return DoctorModel.fromMap(d.data(), id: d.id);
  }

  @override
  Future<List<SpecialtyModel>> getSpecialties() async {
    final querySnapshot = await _firestore.collection('specialties').get();
    return querySnapshot.docs.map((d) => SpecialtyModel.fromMap(d.data(), id: d.id)).toList();
  }

  @override
  Future<void> saveSpecialty(SpecialtyModel specialty) async {
    await _firestore
        .collection('specialties')
        .doc(specialty.id)
        .set(specialty.toMap(), SetOptions(merge: true));
  }

  @override
  Future<List<DoctorModel>> getPendingVerificationDoctors() async {
    final querySnapshot = await _firestore
        .collection('doctors')
        .where('verificationStatus', isEqualTo: 'pending')
        .get();
    return querySnapshot.docs.map((d) => DoctorModel.fromMap(d.data(), id: d.id)).toList();
  }

  @override
  Future<void> updateVerificationStatus(
    String doctorId,
    VerificationStatus status, [
    String? notes,
  ]) async {
    final docRef = _firestore.collection('doctors').doc(doctorId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw const NotFoundException('Doctor record not found.');
    }

    await docRef.update({
      'verificationStatus': status.name,
      'verificationNotes': notes,
    });
  }

  @override
  Future<void> updateDoctorAvailability(
    String doctorId,
    Map<String, List<TimeWindow>> weeklyAvailability,
    List<String> blackoutDates,
  ) async {
    final docRef = _firestore.collection('doctors').doc(doctorId);
    final mappedAvailability = weeklyAvailability.map(
      (key, value) => MapEntry(key, value.map((w) => w.toMap()).toList()),
    );

    await docRef.update({
      'weeklyAvailability': mappedAvailability,
      'blackoutDates': blackoutDates,
    });
  }

  @override
  Future<void> registerDoctorProfile(DoctorModel doctor) async {
    await _firestore.collection('doctors').doc(doctor.id).set(doctor.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> updateDoctorProfile(DoctorModel doctor) async {
    await _firestore
        .collection('doctors')
        .doc(doctor.id)
        .set(doctor.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteDoctor(String doctorId) async {
    await _firestore.collection('doctors').doc(doctorId).delete();
  }

  @override
  Future<void> deleteSpecialty(String specialtyId) async {
    await _firestore.collection('specialties').doc(specialtyId).delete();
  }

  @override
  Stream<List<DoctorModel>> watchDoctors() {
    return _firestore
        .collection('doctors')
        .where('verificationStatus', isEqualTo: 'approved')
        .snapshots()
        .map((s) => s.docs.map((d) => DoctorModel.fromMap(d.data(), id: d.id)).toList());
  }
}

