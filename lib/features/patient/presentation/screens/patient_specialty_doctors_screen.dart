import 'package:flutter/material.dart';
import '../../../doctor/domain/entities/specialty_model.dart';
import '../../../doctor/presentation/screens/unified_specialties_screen.dart';
import '../../../doctor/presentation/screens/unified_specialty_doctors_screen.dart';

export '../../../doctor/presentation/screens/unified_specialty_doctors_screen.dart'
    show UnifiedSpecialtyDoctorsScreen;

class PatientSpecialtyDoctorsScreen extends StatelessWidget {
  final SpecialtyModel specialty;

  const PatientSpecialtyDoctorsScreen({
    super.key,
    required this.specialty,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedSpecialtyDoctorsScreen(
      specialty: specialty,
      role: SpecialtyScreenRole.patient,
    );
  }
}
