import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_app/core/data/mock_data_store.dart';
import 'package:healthcare_app/features/doctor/data/repositories/mock_doctor_repository.dart';
import 'package:healthcare_app/features/doctor/domain/entities/doctor_model.dart';

void main() {
  group('Challenge #4: Doctor Search, Verification & Multi-Attribute Filtering', () {
    late MockDoctorRepository repository;

    setUp(() {
      repository = MockDoctorRepository(MockDataStore.instance);
    });

    test('Returns only verified doctors by default', () async {
      final doctors = await repository.getDoctors(onlyVerified: true);
      expect(doctors, isNotEmpty);
      for (var d in doctors) {
        expect(d.isVerified, isTrue);
      }
    });

    test('Filters doctors by specialty correctly', () async {
      final cardioDocs = await repository.getDoctors(specialtyId: 'spec_cardiology');
      expect(cardioDocs, isNotEmpty);
      for (var d in cardioDocs) {
        expect(d.specialtyId, equals('spec_cardiology'));
      }
    });

    test('Filters doctors by minimum rating bracket', () async {
      final highRated = await repository.getDoctors(minRating: 4.9);
      expect(highRated, isNotEmpty);
      for (var d in highRated) {
        expect(d.rating, greaterThanOrEqualTo(4.9));
      }
    });

    test('Filters doctors by maximum consultation fee', () async {
      final affordable = await repository.getDoctors(maxFee: 70.0);
      expect(affordable, isNotEmpty);
      for (var d in affordable) {
        expect(d.consultationFee, lessThanOrEqualTo(70.0));
      }
    });

    test('Searches doctors by keyword in name or bio', () async {
      final results = await repository.getDoctors(query: 'Emily');
      expect(results.length, equals(1));
      expect(results.first.doctorName, contains('Emily'));
    });

    test('Admin approval workflow transitions pending doctor to verified and searchable', () async {
      final pendingDocs = await repository.getPendingVerificationDoctors();
      expect(pendingDocs, isNotEmpty);
      final target = pendingDocs.first;

      expect(target.isVerified, isFalse);

      // Admin approves
      await repository.updateVerificationStatus(target.id, VerificationStatus.approved);

      final updated = await repository.getDoctorById(target.id);
      expect(updated?.isVerified, isTrue);
      expect(updated?.verificationStatus, equals(VerificationStatus.approved));

      // Now discoverable in verified list
      final allVerified = await repository.getDoctors(onlyVerified: true);
      expect(allVerified.any((d) => d.id == target.id), isTrue);
    });
  });
}
