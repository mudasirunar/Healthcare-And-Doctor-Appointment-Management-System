import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../../core/data/mock_data_store.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/entities/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  final MockDataStore _dataStore;
  final _uuid = const Uuid();

  UserModel? _currentUser;
  final _authStreamController = StreamController<UserModel?>.broadcast();

  MockAuthRepository([MockDataStore? dataStore])
      : _dataStore = dataStore ?? MockDataStore.instance {
    // Default signed in user is patient for instant interactive experience
    _currentUser = _dataStore.getAllUsers().firstWhere(
          (u) => u.email == 'patient@healthcare.com',
          orElse: () => _dataStore.getAllUsers().first,
        );
    _authStreamController.add(_currentUser);
  }

  @override
  Future<UserModel?> getCurrentUser() async => _currentUser;

  @override
  Stream<UserModel?> authStateChanges() => _authStreamController.stream;

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    // Simulate minimal network latency
    await Future.delayed(const Duration(milliseconds: 300));

    final user = await _dataStore.getUserByEmail(email);
    if (user == null) {
      throw const AuthException('No user found matching this email address.');
    }

    _currentUser = user;
    _authStreamController.add(_currentUser);
    return user;
  }

  @override
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
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final existing = await _dataStore.getUserByEmail(email);
    if (existing != null) {
      throw const AuthException('An account already exists with this email.');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final newUser = UserModel(
      id: 'usr_${_uuid.v4().substring(0, 8)}',
      email: email,
      displayName: displayName,
      role: role,
      createdAt: nowIso,
      updatedAt: nowIso,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodGroup: bloodGroup,
      emergencyContact: emergencyContact,
      medicalAllergies: medicalAllergies,
    );

    await _dataStore.saveUser(newUser);
    _currentUser = newUser;
    _authStreamController.add(_currentUser);
    return newUser;
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _currentUser = null;
    _authStreamController.add(null);
  }

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    await _dataStore.saveUser(user);
    if (_currentUser?.id == user.id) {
      _currentUser = user;
      _authStreamController.add(_currentUser);
    }
    return user;
  }
}
