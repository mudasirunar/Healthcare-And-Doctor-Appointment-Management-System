import 'package:flutter/material.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../doctor/presentation/screens/unified_doctor_detail_screen.dart';

export '../../../doctor/presentation/screens/unified_doctor_detail_screen.dart'
    show UnifiedDoctorDetailScreen;

/// Patient-facing view of the specialist profile.
/// Powered by UnifiedDoctorDetailScreen with role set to Patient.
class DoctorDetailsScreen extends StatelessWidget {
  final String doctorId;

  const DoctorDetailsScreen({
    super.key,
    required this.doctorId,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedDoctorDetailScreen(
      doctorId: doctorId,
      role: UserRole.patient,
    );
  }
}
