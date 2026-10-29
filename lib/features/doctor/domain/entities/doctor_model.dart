enum VerificationStatus {
  pending,
  approved,
  rejected;

  static VerificationStatus fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'approved':
        return VerificationStatus.approved;
      case 'rejected':
        return VerificationStatus.rejected;
      case 'pending':
      default:
        return VerificationStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case VerificationStatus.approved:
        return 'Verified';
      case VerificationStatus.rejected:
        return 'Rejected';
      case VerificationStatus.pending:
        return 'Pending Verification';
    }
  }
}

class TimeWindow {
  final String start; // "09:00" (24h format)
  final String end;   // "13:00"

  const TimeWindow({required this.start, required this.end});

  Map<String, dynamic> toMap() => {'start': start, 'end': end};

  factory TimeWindow.fromMap(Map<String, dynamic> map) {
    return TimeWindow(
      start: map['start'] as String? ?? '09:00',
      end: map['end'] as String? ?? '17:00',
    );
  }
}

class DoctorModel {
  final String id;
  final String userId;
  final String doctorName;
  final String specialtyId;
  final String specialtyName;
  final String licenseNumber;
  final int experienceYears;
  final double consultationFee;
  final String currency;
  final String bio;
  final double rating;
  final int reviewCount;
  final VerificationStatus verificationStatus;
  final String? verificationNotes;
  final List<String> documentUrls;
  final Map<String, List<TimeWindow>> weeklyAvailability;
  final List<String> blackoutDates; // "2026-11-05"
  final int slotDurationMinutes;
  final String? avatarUrl;

  const DoctorModel({
    required this.id,
    required this.userId,
    required this.doctorName,
    required this.specialtyId,
    required this.specialtyName,
    required this.licenseNumber,
    required this.experienceYears,
    required this.consultationFee,
    this.currency = 'USD',
    required this.bio,
    this.rating = 5.0,
    this.reviewCount = 0,
    this.verificationStatus = VerificationStatus.pending,
    this.verificationNotes,
    this.documentUrls = const [],
    this.weeklyAvailability = const {},
    this.blackoutDates = const [],
    this.slotDurationMinutes = 30,
    this.avatarUrl,
  });

  bool get isVerified => verificationStatus == VerificationStatus.approved;

  DoctorModel copyWith({
    String? id,
    String? userId,
    String? doctorName,
    String? specialtyId,
    String? specialtyName,
    String? licenseNumber,
    int? experienceYears,
    double? consultationFee,
    String? currency,
    String? bio,
    double? rating,
    int? reviewCount,
    VerificationStatus? verificationStatus,
    String? verificationNotes,
    List<String>? documentUrls,
    Map<String, List<TimeWindow>>? weeklyAvailability,
    List<String>? blackoutDates,
    int? slotDurationMinutes,
    String? avatarUrl,
  }) {
    return DoctorModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      doctorName: doctorName ?? this.doctorName,
      specialtyId: specialtyId ?? this.specialtyId,
      specialtyName: specialtyName ?? this.specialtyName,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      experienceYears: experienceYears ?? this.experienceYears,
      consultationFee: consultationFee ?? this.consultationFee,
      currency: currency ?? this.currency,
      bio: bio ?? this.bio,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationNotes: verificationNotes ?? this.verificationNotes,
      documentUrls: documentUrls ?? this.documentUrls,
      weeklyAvailability: weeklyAvailability ?? this.weeklyAvailability,
      blackoutDates: blackoutDates ?? this.blackoutDates,
      slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'doctorName': doctorName,
      'specialtyId': specialtyId,
      'specialtyName': specialtyName,
      'licenseNumber': licenseNumber,
      'experienceYears': experienceYears,
      'consultationFee': consultationFee,
      'currency': currency,
      'bio': bio,
      'rating': rating,
      'reviewCount': reviewCount,
      'verificationStatus': verificationStatus.name,
      'verificationNotes': verificationNotes,
      'documentUrls': documentUrls,
      'weeklyAvailability': weeklyAvailability.map(
        (key, value) => MapEntry(key, value.map((w) => w.toMap()).toList()),
      ),
      'blackoutDates': blackoutDates,
      'slotDurationMinutes': slotDurationMinutes,
      'avatarUrl': avatarUrl,
    };
  }

  factory DoctorModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawAvailability = map['weeklyAvailability'] as Map<String, dynamic>? ?? {};
    final parsedAvailability = <String, List<TimeWindow>>{};
    rawAvailability.forEach((day, windows) {
      if (windows is List) {
        parsedAvailability[day] = windows
            .map((w) => TimeWindow.fromMap(w as Map<String, dynamic>))
            .toList();
      }
    });

    return DoctorModel(
      id: id ?? map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      doctorName: map['doctorName'] as String? ?? '',
      specialtyId: map['specialtyId'] as String? ?? '',
      specialtyName: map['specialtyName'] as String? ?? '',
      licenseNumber: map['licenseNumber'] as String? ?? '',
      experienceYears: (map['experienceYears'] as num?)?.toInt() ?? 0,
      consultationFee: (map['consultationFee'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'USD',
      bio: map['bio'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      verificationStatus: VerificationStatus.fromString(map['verificationStatus'] as String? ?? 'pending'),
      verificationNotes: map['verificationNotes'] as String?,
      documentUrls: List<String>.from(map['documentUrls'] as List? ?? []),
      weeklyAvailability: parsedAvailability,
      blackoutDates: List<String>.from(map['blackoutDates'] as List? ?? []),
      slotDurationMinutes: (map['slotDurationMinutes'] as num?)?.toInt() ?? 30,
      avatarUrl: map['avatarUrl'] as String?,
    );
  }
}
