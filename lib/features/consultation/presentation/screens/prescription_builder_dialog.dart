import 'package:flutter/material.dart';
import 'package:healthcare_app/features/appointment/domain/entities/appointment_model.dart';
import 'doctor_prescription_screen.dart';

export 'doctor_prescription_screen.dart';

/// Legacy dialog wrapper: Redirects to [DoctorPrescriptionScreen]
/// to maintain backward compatibility while providing the modern full-screen UI.
class PrescriptionBuilderDialog extends StatelessWidget {
  final AppointmentModel appointment;
  final VoidCallback onPrescriptionCreated;

  const PrescriptionBuilderDialog({
    super.key,
    required this.appointment,
    required this.onPrescriptionCreated,
  });

  @override
  Widget build(BuildContext context) {
    // If ever invoked via showDialog, immediately push the full-screen DoctorPrescriptionScreen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DoctorPrescriptionScreen(
            appointment: appointment,
            onPrescriptionCreated: onPrescriptionCreated,
          ),
        ),
      );
    });

    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
