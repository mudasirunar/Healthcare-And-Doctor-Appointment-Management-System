import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointment/domain/entities/appointment_model.dart';

class VideoConsultationScreen extends ConsumerStatefulWidget {
  final String appointmentId;

  const VideoConsultationScreen({super.key, required this.appointmentId});

  @override
  ConsumerState<VideoConsultationScreen> createState() => _VideoConsultationScreenState();
}

class _VideoConsultationScreenState extends ConsumerState<VideoConsultationScreen> {
  bool _isMicMuted = false;
  bool _isVideoOff = false;
  int _elapsedSeconds = 0;
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  String _formatTimer(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final aptRepo = ref.watch(appointmentRepositoryProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark clinical room backdrop
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Encrypted Consultation Call', style: TextStyle(color: Colors.white, fontSize: 16)),
            Text(
              'Session: ${_formatTimer(_elapsedSeconds)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Appointment Chat',
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
            onPressed: () => context.push('/consultation/chat/${widget.appointmentId}'),
          ),
        ],
      ),
      body: FutureBuilder<AppointmentModel?>(
        future: aptRepo.getAppointmentById(widget.appointmentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          final apt = snapshot.data;
          if (apt == null) {
            return const ErrorStateView(message: 'Appointment not found.');
          }

          // Authorization Check (Challenge #5: Privacy & Permissions)
          final isAuthorized = user != null &&
              (user.id == apt.patientId ||
                  user.id == apt.doctorId ||
                  user.displayName == apt.doctorName ||
                  user.role.name == 'doctor' ||
                  user.role.name == 'admin');

          if (!isAuthorized) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Access Denied: You are not an authorized participant in this private consultation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            );
          }

          final remoteParticipantName = user.isDoctor ? apt.patientName : apt.doctorName;

          return SafeArea(
            child: Column(
              children: [
                // Call Status Pill
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Active Telehealth Room • Connected with $remoteParticipantName',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // Video Feeds
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Stack(
                      children: [
                        // Main Remote Video Area
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 54,
                                  backgroundColor: AppColors.primary.withOpacity(0.3),
                                  child: Text(
                                    remoteParticipantName.isNotEmpty ? remoteParticipantName[0] : 'U',
                                    style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  remoteParticipantName,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.isDoctor ? 'Patient' : apt.doctorSpecialty,
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Self Camera Picture-in-Picture
                        Positioned(
                          right: 16,
                          top: 16,
                          child: Container(
                            width: 110,
                            height: 150,
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white24, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                              ],
                            ),
                            child: Center(
                              child: _isVideoOff
                                  ? const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 28)
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person_rounded, color: Colors.white, size: 36),
                                        const SizedBox(height: 6),
                                        Text(
                                          user.displayName.split(' ').first,
                                          style: const TextStyle(color: Colors.white, fontSize: 11),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Control Dock
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mic toggle
                      _ControlButton(
                        icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        isActive: !_isMicMuted,
                        onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                      ),
                      // Video toggle
                      _ControlButton(
                        icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        isActive: !_isVideoOff,
                        onTap: () => setState(() => _isVideoOff = !_isVideoOff),
                      ),
                      // Chat shortcut
                      _ControlButton(
                        icon: Icons.chat_rounded,
                        isActive: true,
                        onTap: () => context.push('/consultation/chat/${widget.appointmentId}'),
                      ),
                      // End Call Button
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.15) : Colors.red.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : AppColors.error,
          size: 24,
        ),
      ),
    );
  }
}
