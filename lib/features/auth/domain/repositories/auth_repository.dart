import '../entities/user_model.dart';

abstract class AuthRepository {
  Future<UserModel?> getCurrentUser();
  Stream<UserModel?> authStateChanges();

  Future<UserModel> signIn({
    required String email,
    required String password,
  });

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? emergencyContact,
    String? medicalAllergies,
  });

  Future<void> signOut();
  Future<UserModel> updateProfile(UserModel user);
  Future<UserModel> registerPatientByAdmin({
    required UserModel patient,
    required String password,
  });
  Future<void> deletePatientRecord(String userId);
}
