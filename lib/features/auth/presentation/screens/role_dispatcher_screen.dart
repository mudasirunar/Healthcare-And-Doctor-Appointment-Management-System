import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../domain/entities/user_model.dart';
import 'login_screen.dart';
import 'splash_screen.dart';
import '../../../patient/presentation/screens/patient_main_screen.dart';
import '../../../doctor/presentation/screens/doctor_main_screen.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';

class RoleDispatcherScreen extends ConsumerStatefulWidget {
  const RoleDispatcherScreen({super.key});

  @override
  ConsumerState<RoleDispatcherScreen> createState() =>
      _RoleDispatcherScreenState();
}

class _RoleDispatcherScreenState extends ConsumerState<RoleDispatcherScreen> {
  static bool _hasCompletedInitialSplash = false;
  bool _minimumSplashElapsed = _hasCompletedInitialSplash;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    if (!_hasCompletedInitialSplash) {
      _splashTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() {
            _minimumSplashElapsed = true;
            _hasCompletedInitialSplash = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authStreamAsync = ref.watch(currentUserStreamProvider);
    final user = ref.watch(currentUserProvider) ?? authStreamAsync.valueOrNull;

    // Always show the splash screen on app start, and wait until the auth session check finishes
    if (!_minimumSplashElapsed || (authStreamAsync.isLoading && user == null)) {
      return const SplashScreen();
    }

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
