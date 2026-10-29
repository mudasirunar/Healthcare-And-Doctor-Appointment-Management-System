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
  Future<void> sendPasswordResetEmail(String email);
  Future<UserModel> updateProfile(UserModel user);
}
