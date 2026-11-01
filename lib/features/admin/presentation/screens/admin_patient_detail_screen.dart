import 'package:flutter/material.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../patient/presentation/screens/unified_patient_detail_screen.dart';

export '../../../patient/presentation/screens/unified_patient_detail_screen.dart'
    show UnifiedPatientDetailScreen;

/// Admin-facing view of the patient profile.
/// Powered by UnifiedPatientDetailScreen with role set to Admin.
class AdminPatientDetailScreen extends StatelessWidget {
  final String patientId;

  const AdminPatientDetailScreen({
    super.key,
    required this.patientId,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedPatientDetailScreen(
      patientId: patientId,
      role: UserRole.admin,
    );
  }
}
