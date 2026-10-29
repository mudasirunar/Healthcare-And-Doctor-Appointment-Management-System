import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../consultation/presentation/screens/prescription_builder_dialog.dart';

class DoctorAgendaScreen extends ConsumerWidget {
  const DoctorAgendaScreen({super.key});

  void _showNotesDialog(BuildContext context, WidgetRef ref, AppointmentModel apt) {
    final notesController = TextEditingController(text: apt.consultationNotes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clinical Notes - ${apt.patientName}', style: AppTypography.headline),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reason for visit: "${apt.reasonForVisit}"', style: AppTypography.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Private Clinical Observations',
                hintText: 'Enter clinical impressions, vitals, or symptoms...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final user = ref.read(currentUserProvider);
              await ref.read(appointmentRepositoryProvider).updateStatus(
                appointmentId: apt.id,
                targetStatus: apt.status,
                actorUserId: user?.id ?? 'doctor',
                note: notesController.text.trim(),
              );
              ref.invalidate(userAppointmentsProvider);
            },
            child: const Text('Save Notes'),
          ),
        ],
      ),
    );
  }

  void _startConsultation(BuildContext context, WidgetRef ref, AppointmentModel apt) async {
    final user = ref.read(currentUserProvider);
    // If status is confirmed, transition to inProgress
    if (apt.status == AppointmentStatus.confirmed) {
      await ref.read(appointmentRepositoryProvider).updateStatus(
        appointmentId: apt.id,
        targetStatus: AppointmentStatus.inProgress,
        actorUserId: user?.id ?? 'doctor',
        note: 'Doctor initiated consultation call',
      );
      ref.invalidate(userAppointmentsProvider);
    }
    if (context.mounted) {
      context.push('/consultation/room/${apt.id}');
    }
  }

  void _openPrescriptionBuilder(BuildContext context, WidgetRef ref, AppointmentModel apt) {
    showDialog(
      context: context,
      builder: (ctx) => PrescriptionBuilderDialog(
        appointment: apt,
        onPrescriptionCreated: () {
          ref.invalidate(userAppointmentsProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(userAppointmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Consultation Agenda'),
      ),
      body: appointmentsAsync.when(
        data: (appointments) {
          final activeAgenda = appointments.where((a) =>
              a.status == AppointmentStatus.confirmed ||
              a.status == AppointmentStatus.inProgress).toList();

          if (activeAgenda.isEmpty) {
            return const EmptyStateView(
              icon: Icons.event_available_rounded,
              title: 'No Active Consultations',
              description: 'You have no confirmed consultations for today. Check the "Requests" tab for incoming appointment bookings.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: activeAgenda.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final apt = activeAgenda[index];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primaryLight,
                                child: Text(
                                  apt.patientName.isNotEmpty ? apt.patientName[0] : 'P',
                                  style: AppTypography.headline.copyWith(color: AppColors.primary, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(apt.patientName, style: AppTypography.headline.copyWith(fontSize: 16)),
                                  Text(apt.patientEmail, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                                ],
                              ),
                            ],
                          ),
                          StatusBadge(status: apt.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateTimeUtils.formatFullWithTimeZone(apt.scheduledTimeUtc),
                                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Reason: "${apt.reasonForVisit}"', style: AppTypography.bodyMedium),
                      const Divider(height: 24, color: AppColors.border),

                      // Doctor Action Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showNotesDialog(context, ref, apt),
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: const Text('Notes'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(80, 38),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/consultation/chat/${apt.id}'),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            label: const Text('Chat'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(80, 38),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _startConsultation(context, ref, apt),
                            icon: const Icon(Icons.videocam_rounded, size: 16),
                            label: Text(apt.status == AppointmentStatus.inProgress ? 'Resume Room' : 'Start Video'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(120, 38),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openPrescriptionBuilder(context, ref, apt),
                            icon: const Icon(Icons.medication_rounded, size: 16),
                            label: const Text('Prescribe'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              minimumSize: const Size(100, 38),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.invalidate(userAppointmentsProvider),
        ),
      ),
    );
  }
}
