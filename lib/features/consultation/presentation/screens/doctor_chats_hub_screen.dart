import 'package:flutter/material.dart';
import '../../../auth/domain/entities/user_model.dart';
import 'unified_chats_hub_screen.dart';

export 'unified_chats_hub_screen.dart' show UnifiedChatsHubScreen;

class DoctorChatsHubScreen extends StatelessWidget {
  const DoctorChatsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnifiedChatsHubScreen(role: UserRole.doctor);
  }
}

