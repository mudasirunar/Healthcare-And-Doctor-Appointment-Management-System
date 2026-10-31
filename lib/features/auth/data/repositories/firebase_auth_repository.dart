import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/entities/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

/// Production-ready Firebase Authentication and Firestore User Store implementation.
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<UserModel?> getCurrentUser() async {
    final currentFirebaseUser = _firebaseAuth.currentUser;
    if (currentFirebaseUser == null) return null;

    final docSnapshot = await _firestore.collection('users').doc(currentFirebaseUser.uid).get();
    if (docSnapshot.exists && docSnapshot.data() != null) {
      return UserModel.fromMap(docSnapshot.data()!, id: docSnapshot.id);
    }

    // Fallback if firestore document hasn't synced yet
    return UserModel(
      id: currentFirebaseUser.uid,
      email: currentFirebaseUser.email ?? '',
      displayName: currentFirebaseUser.displayName ?? 'User',
      role: UserRole.patient,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  Stream<UserModel?> authStateChanges() {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      try {
        final docSnapshot = await _firestore.collection('users').doc(user.uid).get();
        if (docSnapshot.exists && docSnapshot.data() != null) {
          return UserModel.fromMap(docSnapshot.data()!, id: docSnapshot.id);
        }
      } catch (_) {}
      return UserModel(
        id: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'User',
        role: UserRole.patient,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
    });
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException('Authentication failed: user not returned.');
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, id: doc.id);
      }

      // Default model if record is pending
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final userModel = UserModel(
        id: user.uid,
        email: user.email ?? email,
        displayName: user.displayName ?? 'User',
        role: UserRole.patient,
        createdAt: nowIso,
        updatedAt: nowIso,
      );
      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      throw AuthException(e.toString());
    }
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
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException('Account creation failed.');
      }

      await user.updateDisplayName(displayName);

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final userModel = UserModel(
        id: user.uid,
        email: email.trim(),
        displayName: displayName.trim(),
        role: role,
        createdAt: nowIso,
        updatedAt: nowIso,
        dateOfBirth: dateOfBirth,
        gender: gender,
        bloodGroup: bloodGroup,
        emergencyContact: emergencyContact,
        medicalAllergies: medicalAllergies,
      );

      // Persist in Cloud Firestore users collection
      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    final updatedMap = user.toMap();
    updatedMap['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await _firestore.collection('users').doc(user.id).update(updatedMap);
    return user;
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or email credentials.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'The email address format is invalid.';
      case 'weak-password':
        return 'The password is too weak (minimum 6 characters).';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'internal-error':
        return 'Email delivery service is currently unavailable for this address.';
      default:
        return e.message ?? 'Authentication error occurred.';
    }
  }
}

