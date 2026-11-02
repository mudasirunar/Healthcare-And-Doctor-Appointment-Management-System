import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointment/domain/entities/appointment_model.dart';

enum TelehealthCallState {
  calling,
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
  TelehealthCallState _callState = TelehealthCallState.calling;
  bool _isMicMuted = false;
  bool _isVideoOff = false;
  bool _isRecording = false;
  bool _isEnding = false;

  int _elapsedSeconds = 0;
  Timer? _sessionTimer;
  Timer? _stateProgressionTimer;
  late final Future<AppointmentModel?> _appointmentFuture;

  @override
  void initState() {
    super.initState();
    // Cache the future upfront so session timer ticks never cause screen flicker!
    _appointmentFuture = ref
        .read(appointmentRepositoryProvider)
        .getAppointmentById(widget.appointmentId);
    _startCallProgression();
  }

  void _startCallProgression() {
    // 1. Calling for ~1.2s
    _stateProgressionTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _callState = TelehealthCallState.ringing);

      // 2. Ringing for ~2.5s
      _stateProgressionTimer = Timer(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        setState(() => _callState = TelehealthCallState.connected);
        _startSessionTimer();
      });
    });
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  Future<void> _endCall() async {
    if (_isEnding) return;
    _isEnding = true;

    _stateProgressionTimer?.cancel();
    _sessionTimer?.cancel();

    final user = ref.read(currentUserProvider);
    final totalSecs = _elapsedSeconds;

    // Record the call log in appointment chat (WhatsApp style)
    if (user != null) {
      try {
        await ref.read(appointmentRepositoryProvider).sendMessage(
              appointmentId: widget.appointmentId,
              senderId: user.id,
              senderName: user.displayName,
              senderRole: user.role.name,
              content: 'VIDEO_CALL:$totalSecs',
            );
      } catch (_) {}
    }

    if (mounted) {
      Navigator.pop(context);
    }
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
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark clinical backdrop
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
          tooltip: 'End Call',
          onPressed: _endCall,
        ),
        title: null,
        actions: const [],
      ),
      body: FutureBuilder<AppointmentModel?>(
        future: _appointmentFuture, // Cached future prevents continuous flickering
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          final apt = snapshot.data;
          if (apt == null) {
            return const ErrorStateView(message: 'Appointment not found.');
          }

          final remoteParticipantName =
              user?.isDoctor == true ? apt.patientName : apt.doctorName;

          // Connection status label (no long doctor name, no overflow)
          String statusText;
          Color statusDotColor;
          switch (_callState) {
            case TelehealthCallState.calling:
              statusText = 'Calling...';
              statusDotColor = const Color(0xFFF59E0B);
              break;
            case TelehealthCallState.ringing:
              statusText = 'Ringing...';
              statusDotColor = const Color(0xFFF59E0B);
              break;
            case TelehealthCallState.connected:
              statusText = 'Connected';
              statusDotColor = AppColors.success;
              break;
          }

          return Column(
            children: [
              // Clean Connection Status Pill (Zero overflow)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
                        color: statusDotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
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
                      // Remote Feed Canvas
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
                                      ? remoteParticipantName
                                          .replaceFirst(RegExp(r'^Dr\.\s*'), '')
                                          .characters
                                          .first
                                          .toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
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

                              const SizedBox(height: 12),

                              // Call Duration in the Middle (Below Name and Specialty)
                              if (_callState == TelehealthCallState.connected) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 14,
                                        color: Color(0xFF38BDF8),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatTimer(_elapsedSeconds),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(
                                  width: 20,
                                  height: 20,
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
                            border:
                                Border.all(color: Colors.white24, width: 1.5),
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

              // Bottom Control Dock
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mic Toggle
                    _CallDockButton(
                      icon: _isMicMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      isActive: !_isMicMuted,
                      label: _isMicMuted ? 'Muted' : 'Mic On',
                      onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                    ),

                    // Video Toggle
                    _CallDockButton(
                      icon: _isVideoOff
                          ? Icons.videocam_off_rounded
                          : Icons.videocam_rounded,
                      isActive: !_isVideoOff,
                      label: _isVideoOff ? 'Video Off' : 'Video On',
                      onTap: () => setState(() => _isVideoOff = !_isVideoOff),
                    ),

                    // Visual Record Button (Toggles highlight/color)
                    _CallDockButton(
                      icon: _isRecording
                          ? Icons.stop_circle_rounded
                          : Icons.fiber_manual_record_rounded,
                      isActive: true,
                      isHighlighted: _isRecording,
                      label: _isRecording ? 'Recording' : 'Record',
                      onTap: () => setState(() => _isRecording = !_isRecording),
                    ),

                    // End Call Button
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _endCall,
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
  final bool isHighlighted;

  const _CallDockButton({
    required this.icon,
    required this.isActive,
    required this.label,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color buttonBg;
    final Color iconColor;

    if (isHighlighted) {
      buttonBg = Colors.white;
      iconColor = AppColors.error;
    } else {
      buttonBg = isActive
          ? Colors.white.withOpacity(0.15)
          : Colors.red.withOpacity(0.2);
      iconColor = isActive ? Colors.white : AppColors.error;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: buttonBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: isHighlighted ? Colors.white : Colors.white70,
              fontSize: 10.5,
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
