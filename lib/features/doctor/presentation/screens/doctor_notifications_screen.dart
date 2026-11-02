import 'package:flutter/material.dart';
import 'package:healthcare_app/features/notifications/presentation/screens/unified_notifications_screen.dart';

/// Doctor-facing notification center powered by UnifiedNotificationsScreen.
class DoctorNotificationsScreen extends StatelessWidget {
  const DoctorNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnifiedNotificationsScreen(
      role: NotificationRole.doctor,
      title: 'Doctor Notifications',
    );
  }
}
