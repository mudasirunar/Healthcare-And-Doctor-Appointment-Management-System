class MedicationItem {
  final String name;
  final String dosage;       // e.g. "500mg"
  final String frequency;    // e.g. "Twice daily after meals"
  final String duration;     // e.g. "5 days"
  final String? instructions;// e.g. "Take with plenty of water"

  const MedicationItem({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'duration': duration,
        'instructions': instructions,
      };

  factory MedicationItem.fromMap(Map<String, dynamic> map) {
    return MedicationItem(
      name: map['name'] as String? ?? '',
      dosage: map['dosage'] as String? ?? '',
      frequency: map['frequency'] as String? ?? '',
      duration: map['duration'] as String? ?? '',
      instructions: map['instructions'] as String?,
    );
  }
}

class PrescriptionModel {
  final String id;
  final String appointmentId;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String diagnosis;
  final List<MedicationItem> medications;
  final String? notes;
  final String issuedAtUtc;

  const PrescriptionModel({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.diagnosis,
    required this.medications,
    this.notes,
    required this.issuedAtUtc,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'doctorSpecialty': doctorSpecialty,
      'diagnosis': diagnosis,
      'medications': medications.map((m) => m.toMap()).toList(),
      'notes': notes,
      'issuedAtUtc': issuedAtUtc,
    };
  }

  factory PrescriptionModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawMeds = map['medications'] as List? ?? [];
    final meds = rawMeds
        .map((m) => MedicationItem.fromMap(m as Map<String, dynamic>))
        .toList();

    return PrescriptionModel(
      id: id ?? map['id'] as String? ?? '',
      appointmentId: map['appointmentId'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      patientName: map['patientName'] as String? ?? '',
      doctorId: map['doctorId'] as String? ?? '',
      doctorName: map['doctorName'] as String? ?? '',
      doctorSpecialty: map['doctorSpecialty'] as String? ?? '',
      diagnosis: map['diagnosis'] as String? ?? '',
      medications: meds,
      notes: map['notes'] as String?,
      issuedAtUtc: map['issuedAtUtc'] as String? ?? DateTime.now().toUtc().toIso8601String(),
    );
  }
}
