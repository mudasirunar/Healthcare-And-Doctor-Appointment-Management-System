enum UserRole {
  patient,
  doctor,
  admin;

  static UserRole fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'doctor':
        return UserRole.doctor;
      case 'admin':
        return UserRole.admin;
      case 'patient':
      default:
        return UserRole.patient;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.patient:
        return 'Patient';
      case UserRole.doctor:
        return 'Doctor';
      case UserRole.admin:
        return 'Administrator';
    }
  }
}

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final String? phoneNumber;
  final String? avatarUrl;
  final String createdAt;
  final String updatedAt;

  // Patient-specific details
  final String? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String? emergencyContact;
  final String? medicalAllergies;

  // Real-time presence
  final bool isOnline;
  final String? lastSeenUtc;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.phoneNumber,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.emergencyContact,
    this.medicalAllergies,
    this.isOnline = false,
    this.lastSeenUtc,
  });

  bool get isDoctor => role == UserRole.doctor;
  bool get isPatient => role == UserRole.patient;
  bool get isAdmin => role == UserRole.admin;

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    UserRole? role,
    String? phoneNumber,
    String? avatarUrl,
    String? createdAt,
    String? updatedAt,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? emergencyContact,
    String? medicalAllergies,
    bool? isOnline,
    String? lastSeenUtc,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      medicalAllergies: medicalAllergies ?? this.medicalAllergies,
      isOnline: isOnline ?? this.isOnline,
      lastSeenUtc: lastSeenUtc ?? this.lastSeenUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'emergencyContact': emergencyContact,
      'medicalAllergies': medicalAllergies,
      'isOnline': isOnline,
      'lastSeenUtc': lastSeenUtc,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return UserModel(
      id: id ?? map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      role: UserRole.fromString(map['role'] as String? ?? 'patient'),
      phoneNumber: map['phoneNumber'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      createdAt: map['createdAt'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      updatedAt: map['updatedAt'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      dateOfBirth: map['dateOfBirth'] as String?,
      gender: map['gender'] as String?,
      bloodGroup: map['bloodGroup'] as String?,
      emergencyContact: map['emergencyContact'] as String?,
      medicalAllergies: map['medicalAllergies'] as String?,
      isOnline: map['isOnline'] as bool? ?? false,
      lastSeenUtc: map['lastSeenUtc'] as String?,
    );
  }
}
