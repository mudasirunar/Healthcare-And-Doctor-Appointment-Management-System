import 'package:flutter/material.dart';
import '../../../notifications/presentation/screens/unified_notifications_screen.dart';

/// Admin Notifications Screen - delegating to the unified reusable notifications interface
class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnifiedNotificationsScreen(
      role: NotificationRole.admin,
    );
  }
}
