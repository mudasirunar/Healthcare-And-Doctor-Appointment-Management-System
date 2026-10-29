import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../domain/entities/user_model.dart';
import 'login_screen.dart';
import '../../../patient/presentation/screens/patient_main_screen.dart';
import '../../../doctor/presentation/screens/doctor_main_screen.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';

class RoleDispatcherScreen extends ConsumerWidget {
  const RoleDispatcherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const LoginScreen();
    }

    switch (user.role) {
      case UserRole.patient:
        return const PatientMainScreen();
      case UserRole.doctor:
        return const DoctorMainScreen();
      case UserRole.admin:
        return const AdminDashboardScreen();
    }
  }
}
