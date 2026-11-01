import 'package:flutter/material.dart';
import '../../../notifications/presentation/screens/unified_notifications_screen.dart';

/// Patient Notifications Screen - delegating to the unified reusable notifications interface
class PatientNotificationsScreen extends StatelessWidget {
  const PatientNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnifiedNotificationsScreen(
      role: NotificationRole.patient,
    );
  }
}
