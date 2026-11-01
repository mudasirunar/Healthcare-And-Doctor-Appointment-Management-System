import 'package:flutter/widgets.dart';
import 'unified_chat_screen.dart';

export 'unified_chat_screen.dart';

/// Legacy alias preserving backward compatibility across all call sites and tests.
class AppointmentChatScreen extends StatelessWidget {
  final String appointmentId;

  const AppointmentChatScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedChatScreen(appointmentId: appointmentId);
  }
}
