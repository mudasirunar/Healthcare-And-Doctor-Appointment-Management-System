import 'package:flutter/material.dart';
import '../../../doctor/presentation/screens/unified_specialties_screen.dart';

export '../../../doctor/presentation/screens/unified_specialties_screen.dart'
    show SpecialtyScreenRole, UnifiedSpecialtiesScreen;

/// Patient-facing Medical Specialties & Departments Screen.
/// Utilizes the clean [UnifiedSpecialtiesScreen] layout with chevron navigation,
/// without admin controls (edit/delete) and without the "+ Add" button.
class PatientSpecialtiesScreen extends StatelessWidget {
  const PatientSpecialtiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnifiedSpecialtiesScreen(
      role: SpecialtyScreenRole.patient,
      isStandalone: true,
    );
  }
}
