enum AppointmentStatus {
  requested,
  confirmed,
  inProgress,
  completed,
  cancelled,
  rejected;

  static AppointmentStatus fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'confirmed':
        return AppointmentStatus.confirmed;
      case 'inprogress':
      case 'in_progress':
        return AppointmentStatus.inProgress;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
      case 'canceled':
        return AppointmentStatus.cancelled;
      case 'rejected':
        return AppointmentStatus.rejected;
      case 'requested':
      default:
        return AppointmentStatus.requested;
    }
  }

  String get displayName {
    switch (this) {
      case AppointmentStatus.requested:
        return 'Requested';
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.inProgress:
        return 'In Progress';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.rejected:
        return 'Rejected';
    }
  }

  bool get isTerminal =>
      this == AppointmentStatus.completed ||
      this == AppointmentStatus.cancelled ||
      this == AppointmentStatus.rejected;
}

class StatusHistoryEntry {
  final AppointmentStatus status;
  final String timestampUtc;
  final String byUserId;
  final String? note;

  const StatusHistoryEntry({
    required this.status,
    required this.timestampUtc,
    required this.byUserId,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'timestamp': timestampUtc,
        'by': byUserId,
        'note': note,
      };

  factory StatusHistoryEntry.fromMap(Map<String, dynamic> map) {
    return StatusHistoryEntry(
      status: AppointmentStatus.fromString(map['status'] as String? ?? 'requested'),
      timestampUtc: map['timestamp'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      byUserId: map['by'] as String? ?? '',
      note: map['note'] as String?,
    );
  }
}

class AppointmentModel {
  final String id;
  final String patientId;
  final String patientName;
  final String patientEmail;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String scheduledTimeUtc; // ISO-8601 UTC string
  final int durationMinutes;
  final AppointmentStatus status;
  final List<StatusHistoryEntry> statusHistory;
  final String reasonForVisit;
  final String? consultationNotes;
  final String? prescriptionId;
  final String? cancellationReason;
  final String videoRoomId;
  final String createdAt;
  final String updatedAt;

  /// Formats the room identifier into a compact hospital room code (e.g., "AB-12", "BC-04").
  String get displayRoomName {
    if (videoRoomId.isEmpty) return 'AB-12';

    // If it's already a clean short code (e.g. AB-12, BC-04), return it
    if (RegExp(r'^[A-Z]{1,2}-\d{1,2}$').hasMatch(videoRoomId)) {
      return videoRoomId;
    }

    final cleanId = videoRoomId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final hash = cleanId.codeUnits.fold(0, (acc, c) => acc + c);
    final wings = ['AB', 'BC', 'AC', 'CD', 'A', 'B', 'C'];
    final wing = wings[hash % wings.length];
    final num = ((hash ~/ 7) % 30 + 1).toString().padLeft(2, '0');
    return '$wing-$num';
  }

  /// Generates a compact hospital room code based on a seed ID (e.g., "AB-12").
  static String generateHospitalRoomName(String seedId) {
    final cleanId = seedId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final hash = cleanId.codeUnits.fold(0, (acc, c) => acc + c);
    final wings = ['AB', 'BC', 'AC', 'CD', 'A', 'B', 'C'];
    final wing = wings[hash % wings.length];
    final num = ((hash ~/ 7) % 30 + 1).toString().padLeft(2, '0');
    return '$wing-$num';
  }

  const AppointmentModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.scheduledTimeUtc,
    this.durationMinutes = 30,
    this.status = AppointmentStatus.requested,
    this.statusHistory = const [],
    required this.reasonForVisit,
    this.consultationNotes,
    this.prescriptionId,
    this.cancellationReason,
    required this.videoRoomId,
    required this.createdAt,
    required this.updatedAt,
  });

  AppointmentModel copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? patientEmail,
    String? doctorId,
    String? doctorName,
    String? doctorSpecialty,
    String? scheduledTimeUtc,
    int? durationMinutes,
    AppointmentStatus? status,
    List<StatusHistoryEntry>? statusHistory,
    String? reasonForVisit,
    String? consultationNotes,
    String? prescriptionId,
    String? cancellationReason,
    String? videoRoomId,
    String? createdAt,
    String? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      patientEmail: patientEmail ?? this.patientEmail,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      doctorSpecialty: doctorSpecialty ?? this.doctorSpecialty,
      scheduledTimeUtc: scheduledTimeUtc ?? this.scheduledTimeUtc,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      statusHistory: statusHistory ?? this.statusHistory,
      reasonForVisit: reasonForVisit ?? this.reasonForVisit,
      consultationNotes: consultationNotes ?? this.consultationNotes,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      videoRoomId: videoRoomId ?? this.videoRoomId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'patientEmail': patientEmail,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'doctorSpecialty': doctorSpecialty,
      'scheduledTimeUtc': scheduledTimeUtc,
      'durationMinutes': durationMinutes,
      'status': status.name,
      'statusHistory': statusHistory.map((s) => s.toMap()).toList(),
      'reasonForVisit': reasonForVisit,
      'consultationNotes': consultationNotes,
      'prescriptionId': prescriptionId,
      'cancellationReason': cancellationReason,
      'videoRoomId': videoRoomId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final historyRaw = map['statusHistory'] as List? ?? [];
    final parsedHistory = historyRaw
        .map((e) => StatusHistoryEntry.fromMap(e as Map<String, dynamic>))
        .toList();

    return AppointmentModel(
      id: id ?? map['id'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      patientName: map['patientName'] as String? ?? '',
      patientEmail: map['patientEmail'] as String? ?? '',
      doctorId: map['doctorId'] as String? ?? '',
      doctorName: map['doctorName'] as String? ?? '',
      doctorSpecialty: map['doctorSpecialty'] as String? ?? '',
      scheduledTimeUtc: map['scheduledTimeUtc'] as String? ?? '',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
      status: AppointmentStatus.fromString(map['status'] as String? ?? 'requested'),
      statusHistory: parsedHistory,
      reasonForVisit: map['reasonForVisit'] as String? ?? '',
      consultationNotes: map['consultationNotes'] as String?,
      prescriptionId: map['prescriptionId'] as String?,
      cancellationReason: map['cancellationReason'] as String?,
      videoRoomId: map['videoRoomId'] as String? ?? '',
      createdAt: map['createdAt'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      updatedAt: map['updatedAt'] as String? ?? DateTime.now().toUtc().toIso8601String(),
    );
  }
}
