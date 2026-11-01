import 'package:flutter/material.dart';
import '../../../auth/domain/entities/user_model.dart';
import 'unified_chats_hub_screen.dart';

export 'unified_chats_hub_screen.dart' show UnifiedChatsHubScreen;

class PatientChatsHubScreen extends StatelessWidget {
  const PatientChatsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnifiedChatsHubScreen(role: UserRole.patient);
  }
}
