import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_app/features/doctor/domain/entities/doctor_model.dart';

void main() {
  group('Patient Doctor Filtering & Sorting Engine Tests', () {
    final docA = const DoctorModel(
      id: 'doc_1',
      userId: 'user_1',
      doctorName: 'Dr. Aaron Smith',
      specialtyId: 'spec_cardio',
      specialtyName: 'Cardiology',
      licenseNumber: 'LIC-001',
      experienceYears: 12,
      consultationFee: 120.0,
      bio: 'Expert in adult heart surgery.',
      rating: 4.9,
      reviewCount: 38,
      verificationStatus: VerificationStatus.approved,
    );

    final docB = const DoctorModel(
      id: 'doc_2',
      userId: 'user_2',
      doctorName: 'Dr. Bella Jones',
      specialtyId: 'spec_derm',
      specialtyName: 'Dermatology',
      licenseNumber: 'LIC-002',
      experienceYears: 6,
      consultationFee: 50.0,
      bio: 'Skin and laser specialist.',
      rating: 4.4,
      reviewCount: 15,
      verificationStatus: VerificationStatus.approved,
    );

    final docC = const DoctorModel(
      id: 'doc_3',
      userId: 'user_3',
      doctorName: 'Dr. Charles Clark',
      specialtyId: 'spec_cardio',
      specialtyName: 'Cardiology',
      licenseNumber: 'LIC-003',
      experienceYears: 18,
      consultationFee: 75.0,
      bio: 'Preventive cardiology consultant.',
      rating: 4.7,
      reviewCount: 52,
      verificationStatus: VerificationStatus.approved,
    );

    final allDocs = [docA, docB, docC];

    test('Filters strictly by minimum rating threshold', () {
      final filtered = allDocs.where((d) => d.rating >= 4.5).toList();
      expect(filtered.length, 2);
      expect(filtered.map((d) => d.id), containsAll(['doc_1', 'doc_3']));
      expect(filtered.map((d) => d.id), isNot(contains('doc_2')));
    });

    test('Filters strictly by maximum consultation fee threshold', () {
      final filtered = allDocs.where((d) => d.consultationFee <= 80.0).toList();
      expect(filtered.length, 2);
      expect(filtered.map((d) => d.id), containsAll(['doc_2', 'doc_3']));
      expect(filtered.map((d) => d.id), isNot(contains('doc_1')));
    });

    test('Sorts by lowest fee ascending', () {
      final sorted = List<DoctorModel>.from(allDocs)
        ..sort((a, b) => a.consultationFee.compareTo(b.consultationFee));
      expect(sorted.first.id, 'doc_2'); // $50
      expect(sorted[1].id, 'doc_3');    // $75
      expect(sorted.last.id, 'doc_1');  // $120
    });

    test('Sorts by highest rating descending', () {
      final sorted = List<DoctorModel>.from(allDocs)
        ..sort((a, b) => b.rating.compareTo(a.rating));
      expect(sorted.first.id, 'doc_1'); // 4.9
      expect(sorted[1].id, 'doc_3');    // 4.7
      expect(sorted.last.id, 'doc_2');  // 4.4
    });

    test('Sorts by clinical experience years descending', () {
      final sorted = List<DoctorModel>.from(allDocs)
        ..sort((a, b) => b.experienceYears.compareTo(a.experienceYears));
      expect(sorted.first.id, 'doc_3'); // 18y
      expect(sorted[1].id, 'doc_1');    // 12y
      expect(sorted.last.id, 'doc_2');  // 6y
    });
  });
}

