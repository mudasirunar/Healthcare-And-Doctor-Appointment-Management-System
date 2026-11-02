import 'package:flutter/material.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../patient/presentation/screens/unified_edit_patient_screen.dart';

export '../../../patient/presentation/screens/unified_edit_patient_screen.dart'
    show UnifiedEditPatientScreen;

/// Admin-facing edit patient screen wrapper.
/// Delegates directly to UnifiedEditPatientScreen with editorRole set to Admin.
class AdminEditPatientScreen extends StatelessWidget {
  final UserModel patient;

  const AdminEditPatientScreen({
    super.key,
    required this.patient,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedEditPatientScreen(
      patient: patient,
      editorRole: UserRole.admin,
    );
  }
}
