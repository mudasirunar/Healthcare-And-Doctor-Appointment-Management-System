import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointment/domain/entities/appointment_model.dart';

enum TelehealthCallState {
  initiating,
  ringing,
  connected,
}

class VideoConsultationScreen extends ConsumerStatefulWidget {
  final String appointmentId;

  const VideoConsultationScreen({super.key, required this.appointmentId});

  @override
  ConsumerState<VideoConsultationScreen> createState() =>
      _VideoConsultationScreenState();
}

class _VideoConsultationScreenState
    extends ConsumerState<VideoConsultationScreen> {
  TelehealthCallState _callState = TelehealthCallState.initiating;
  bool _isMicMuted = false;
  bool _isVideoOff = false;
  int _elapsedSeconds = 0;
  Timer? _sessionTimer;
  Timer? _stateProgressionTimer;

  @override
  void initState() {
    super.initState();
    _startCallProgression();
  }

  void _startCallProgression() {
    // 1. Simulates initiating connection
    _stateProgressionTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _callState = TelehealthCallState.ringing);

        // 2. Simulates doctor answering call and connecting audio/video stream
        _stateProgressionTimer = Timer(const Duration(milliseconds: 2200), () {
          if (mounted) {
            setState(() {
              _callState = TelehealthCallState.connected;
            });
            _startSessionTimer();
          }
        });
      }
    });
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  @override
  void dispose() {
    _stateProgressionTimer?.cancel();
    _sessionTimer?.cancel();
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
            const Text(
              'Encrypted Consultation Call',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _callState == TelehealthCallState.initiating
                  ? 'Connecting to secure telehealth server...'
                  : _callState == TelehealthCallState.ringing
                      ? 'Ringing specialist device...'
                      : 'Session Duration: ${_formatTimer(_elapsedSeconds)}',
              style: TextStyle(
                color: _callState == TelehealthCallState.connected
                    ? const Color(0xFF38BDF8)
                    : Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Appointment Chat',
            icon: const Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.white),
            onPressed: () =>
                context.push('/consultation/chat/${widget.appointmentId}'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<AppointmentModel?>(
        future: aptRepo.getAppointmentById(widget.appointmentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          final apt = snapshot.data;
          if (apt == null) {
            return const ErrorStateView(message: 'Appointment not found.');
          }

          final remoteParticipantName =
              user?.isDoctor == true ? apt.patientName : apt.doctorName;

          return Column(
            children: [
              // Connection Status Pill
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _callState == TelehealthCallState.connected
                            ? AppColors.success
                            : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _callState == TelehealthCallState.connected
                          ? 'Connected with $remoteParticipantName • HD 60fps Encrypted'
                          : _callState == TelehealthCallState.ringing
                              ? 'Ringing $remoteParticipantName...'
                              : 'Initiating Consultation...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Main Video Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    children: [
                      // Remote Feed
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.3),
                                child: Text(
                                  remoteParticipantName.isNotEmpty
                                      ? remoteParticipantName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 42,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                remoteParticipantName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.isDoctor == true
                                    ? 'Patient'
                                    : apt.doctorSpecialty,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              if (_callState !=
                                  TelehealthCallState.connected) ...[
                                const SizedBox(height: 16),
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Self Camera Preview PIP
                      Positioned(
                        right: 14,
                        top: 14,
                        child: Container(
                          width: 96,
                          height: 130,
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24, width: 1.5),
                          ),
                          child: Center(
                            child: _isVideoOff
                                ? const Icon(Icons.videocam_off_rounded,
                                    color: Colors.white70, size: 24)
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_rounded,
                                          color: Colors.white, size: 30),
                                      const SizedBox(height: 4),
                                      Text(
                                        user?.displayName.split(' ').first ??
                                            'You',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
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

              // Bottom Flat Control Dock
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallDockButton(
                      icon: _isMicMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      isActive: !_isMicMuted,
                      label: _isMicMuted ? 'Muted' : 'Mic On',
                      onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                    ),
                    _CallDockButton(
                      icon: _isVideoOff
                          ? Icons.videocam_off_rounded
                          : Icons.videocam_rounded,
                      isActive: !_isVideoOff,
                      label: _isVideoOff ? 'Video Off' : 'Video On',
                      onTap: () => setState(() => _isVideoOff = !_isVideoOff),
                    ),
                    _CallDockButton(
                      icon: Icons.chat_rounded,
                      isActive: true,
                      label: 'Chat',
                      onTap: () => context
                          .push('/consultation/chat/${widget.appointmentId}'),
                    ),
                    // End Call
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_end_rounded,
                            color: Colors.white, size: 26),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CallDockButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final String label;
  final VoidCallback onTap;

  const _CallDockButton({
    required this.icon,
    required this.isActive,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withOpacity(0.15)
                  : Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : AppColors.error,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
