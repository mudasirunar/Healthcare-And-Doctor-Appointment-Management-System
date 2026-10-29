import '../entities/doctor_model.dart';
import '../entities/specialty_model.dart';

abstract class DoctorRepository {
  Future<List<DoctorModel>> getDoctors({
    String? specialtyId,
    String? query,
    double? minRating,
    double? maxFee,
    bool onlyVerified = true,
  });

  Future<DoctorModel?> getDoctorById(String id);
  Future<DoctorModel?> getDoctorByUserId(String userId);
  Future<List<SpecialtyModel>> getSpecialties();
  Future<List<DoctorModel>> getPendingVerificationDoctors();
  Future<void> updateVerificationStatus(String doctorId, VerificationStatus status, [String? notes]);
  Future<void> updateDoctorAvailability(String doctorId, Map<String, List<TimeWindow>> weeklyAvailability, List<String> blackoutDates);
  Future<void> registerDoctorProfile(DoctorModel doctor);
  Stream<List<DoctorModel>> watchDoctors();
}
