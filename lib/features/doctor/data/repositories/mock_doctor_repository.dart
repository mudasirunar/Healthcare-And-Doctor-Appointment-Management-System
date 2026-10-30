import '../../../../core/data/mock_data_store.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/entities/doctor_model.dart';
import '../../domain/entities/specialty_model.dart';
import '../../domain/repositories/doctor_repository.dart';

class MockDoctorRepository implements DoctorRepository {
  final MockDataStore _dataStore;

  MockDoctorRepository([MockDataStore? dataStore])
      : _dataStore = dataStore ?? MockDataStore.instance;

  @override
  Future<List<DoctorModel>> getDoctors({
    String? specialtyId,
    String? query,
    double? minRating,
    double? maxFee,
    bool onlyVerified = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _dataStore.getDoctors(
      specialtyId: specialtyId,
      query: query,
      minRating: minRating,
      maxFee: maxFee,
      onlyVerified: onlyVerified,
    );
  }

  @override
  Future<DoctorModel?> getDoctorById(String id) async {
    return _dataStore.getDoctorById(id);
  }

  @override
  Future<DoctorModel?> getDoctorByUserId(String userId) async {
    return _dataStore.getDoctorByUserId(userId);
  }

  @override
  Future<List<SpecialtyModel>> getSpecialties() async {
    return _dataStore.getSpecialties();
  }

  @override
  Future<void> saveSpecialty(SpecialtyModel specialty) async {
    await _dataStore.saveSpecialty(specialty);
  }

  @override
  Future<List<DoctorModel>> getPendingVerificationDoctors() async {
    return _dataStore.getPendingVerificationDoctors();
  }

  @override
  Future<void> updateVerificationStatus(
    String doctorId,
    VerificationStatus status, [
    String? notes,
  ]) async {
    final doc = _dataStore.getDoctorById(doctorId);
    if (doc == null) {
      throw const NotFoundException('Doctor not found.');
    }
    final updated = doc.copyWith(
      verificationStatus: status,
      verificationNotes: notes,
    );
    await _dataStore.updateDoctor(updated);
  }

  @override
  Future<void> updateDoctorAvailability(
    String doctorId,
    Map<String, List<TimeWindow>> weeklyAvailability,
    List<String> blackoutDates,
  ) async {
    final doc = _dataStore.getDoctorById(doctorId);
    if (doc == null) {
      throw const NotFoundException('Doctor not found.');
    }
    final updated = doc.copyWith(
      weeklyAvailability: weeklyAvailability,
      blackoutDates: blackoutDates,
    );
    await _dataStore.updateDoctor(updated);
  }

  @override
  Future<void> registerDoctorProfile(DoctorModel doctor) async {
    await _dataStore.updateDoctor(doctor);
  }

  @override
  Stream<List<DoctorModel>> watchDoctors() {
    return _dataStore.doctorsStream;
  }
}
