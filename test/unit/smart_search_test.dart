import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_app/core/utils/smart_search_utils.dart';
import 'package:healthcare_app/features/doctor/domain/entities/doctor_model.dart';

void main() {
  group('SmartSearchEngine', () {
    final sampleDoctors = [
      const DoctorModel(
        id: 'doc_z',
        userId: 'u_z',
        doctorName: 'Dr. Zachary Adams',
        specialtyId: 'spec_cardiology',
        specialtyName: 'Cardiology',
        licenseNumber: 'LIC-900',
        experienceYears: 14,
        consultationFee: 150,
        bio: 'Expert in heart rhythm disorders.',
      ),
      const DoctorModel(
        id: 'doc_a',
        userId: 'u_a',
        doctorName: 'Dr. Alice Carter',
        specialtyId: 'spec_dermatology',
        specialtyName: 'Dermatology',
        licenseNumber: 'LIC-100',
        experienceYears: 8,
        consultationFee: 110,
        bio: 'Board certified dermatologist.',
      ),
      const DoctorModel(
        id: 'doc_b',
        userId: 'u_b',
        doctorName: 'Dr. Brian Cardiology',
        specialtyId: 'spec_pediatrics',
        specialtyName: 'Pediatrics',
        licenseNumber: 'LIC-200',
        experienceYears: 10,
        consultationFee: 95,
        bio: 'Child wellness specialist.',
      ),
      const DoctorModel(
        id: 'doc_c',
        userId: 'u_c',
        doctorName: 'Dr. Carlos Mendez',
        specialtyId: 'spec_cardiology',
        specialtyName: 'Cardiology',
        licenseNumber: 'LIC-300',
        experienceYears: 18,
        consultationFee: 180,
        bio: 'Interventional cardiology specialist.',
      ),
    ];

    test('sorts alphabetically A-Z by stripped doctor name when query is empty', () {
      final sorted = SmartSearchEngine.filterAndSort<DoctorModel>(
        items: sampleDoctors,
        query: '',
        primaryTextBuilder: (d) => d.doctorName,
        secondaryTextsBuilder: (d) => [d.specialtyName, d.specialtyId, d.bio],
      );

      expect(
        sorted.map((d) => d.doctorName).toList(),
        [
          'Dr. Alice Carter',
          'Dr. Brian Cardiology',
          'Dr. Carlos Mendez',
          'Dr. Zachary Adams',
        ],
      );
    });

    test('prioritizes name prefix (Tier 1) -> name substring (Tier 2) -> secondary fields (Tier 3) in A-Z order', () {
      final results = SmartSearchEngine.filterAndSort<DoctorModel>(
        items: sampleDoctors,
        query: 'car',
        primaryTextBuilder: (d) => d.doctorName,
        secondaryTextsBuilder: (d) => [d.specialtyName, d.specialtyId, d.bio],
      );

      // Tier 1 (starts with "car"): Dr. Carlos Mendez
      // Tier 2 (name contains "car"): Dr. Alice Carter, Dr. Brian Cardiology (alphabetical A -> B)
      // Tier 3 (specialty/bio contains "car"): Dr. Zachary Adams (Cardiology)
      expect(
        results.map((d) => d.doctorName).toList(),
        [
          'Dr. Carlos Mendez',
          'Dr. Alice Carter',
          'Dr. Brian Cardiology',
          'Dr. Zachary Adams',
        ],
      );
    });

    test('matches secondary fields such as license number, bio, and category ID', () {
      final results = SmartSearchEngine.filterAndSort<DoctorModel>(
        items: sampleDoctors,
        query: 'LIC-900',
        primaryTextBuilder: (d) => d.doctorName,
        secondaryTextsBuilder: (d) => [
          d.specialtyName,
          d.specialtyId,
          d.licenseNumber,
          d.bio,
        ],
      );

      expect(results.length, 1);
      expect(results.first.doctorName, 'Dr. Zachary Adams');
    });
  });
}

