import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../appointment/domain/entities/appointment_model.dart';

class PatientAppointmentsScreen extends ConsumerWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(userAppointmentsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Appointments'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: appointmentsAsync.when(
          data: (appointments) {
            final upcoming = appointments.where((a) =>
                a.status == AppointmentStatus.requested ||
                a.status == AppointmentStatus.confirmed ||
                a.status == AppointmentStatus.inProgress).toList();

            final completed = appointments.where((a) =>
                a.status == AppointmentStatus.completed).toList();

            final cancelled = appointments.where((a) =>
                a.status == AppointmentStatus.cancelled ||
                a.status == AppointmentStatus.rejected).toList();

            return TabBarView(
              children: [
                _AppointmentsList(
                  appointments: upcoming,
                  emptyTitle: 'No Upcoming Appointments',
                  emptyDescription: 'You do not have any scheduled consultations. Find a specialist to book an appointment.',
                  isUpcoming: true,
                ),
                _AppointmentsList(
                  appointments: completed,
                  emptyTitle: 'No Completed Consultations',
                  emptyDescription: 'Past consultations and issued digital prescriptions will appear here.',
                  isUpcoming: false,
                ),
                _AppointmentsList(
                  appointments: cancelled,
                  emptyTitle: 'No Cancelled Appointments',
                  emptyDescription: 'Any cancelled or declined requests will be archived here.',
                  isUpcoming: false,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorStateView(
            message: e.toString(),
            onRetry: () => ref.invalidate(userAppointmentsProvider),
          ),
        ),
      ),
    );
  }
}

class _AppointmentsList extends ConsumerWidget {
  final List<AppointmentModel> appointments;
  final String emptyTitle;
  final String emptyDescription;
  final bool isUpcoming;

  const _AppointmentsList({
    required this.appointments,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.isUpcoming,
  });

  void _showCancelDialog(BuildContext context, WidgetRef ref, AppointmentModel apt) {
    final isEligible = DateTimeUtils.isEligibleForCancellation(apt.scheduledTimeUtc);

    if (!isEligible) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancellation Policy Alert'),
          content: Text(
            'Appointments can only be cancelled at least 2 hours before the scheduled time.\n\nYour appointment is scheduled in ${DateTimeUtils.hoursUntil(apt.scheduledTimeUtc).toStringAsFixed(1)} hours. Please contact customer support for emergency assistance.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel your consultation with ${apt.doctorName}?',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Cancellation (Required)',
                hintText: 'e.g. Schedule conflict...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Appointment'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);

              try {
                final user = ref.read(currentUserProvider);
                await ref.read(appointmentRepositoryProvider).updateStatus(
                  appointmentId: apt.id,
                  targetStatus: AppointmentStatus.cancelled,
                  actorUserId: user?.id ?? 'patient',
                  isPatientActor: true,
                  cancellationReason: reason,
                );
                ref.invalidate(userAppointmentsProvider);

                if (context.mounted) {
                  AppSnackBar.showInfo(
                    context,
                    'Appointment cancelled successfully.',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackBar.showError(context, e.toString());
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(110, 42),
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (appointments.isEmpty) {
      return EmptyStateView(
        icon: Icons.event_note_rounded,
        title: emptyTitle,
        description: emptyDescription,
        actionLabel: isUpcoming ? 'Find a Specialist' : null,
        onAction: isUpcoming ? () => context.go('/patient/home') : null,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final apt = appointments[index];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Booking #${apt.id.toUpperCase()}',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    ),
                    StatusBadge(status: apt.status),
                  ],
                ),
                const SizedBox(height: 10),
                Text(apt.doctorName, style: AppTypography.headline),
                Text(
                  apt.doctorSpecialty,
                  style: AppTypography.subtitle.copyWith(color: AppColors.primary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 18, color: AppColors.textSecondary),
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
                if (apt.reasonForVisit.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Reason: "${apt.reasonForVisit}"',
                    style: AppTypography.bodyMedium.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
                if (apt.cancellationReason != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Cancellation Note: ${apt.cancellationReason}',
                    style: AppTypography.caption.copyWith(color: AppColors.error),
                  ),
                ],
                const Divider(height: 24, color: AppColors.border),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (apt.status == AppointmentStatus.confirmed ||
                        apt.status == AppointmentStatus.inProgress) ...[
                      OutlinedButton.icon(
                        onPressed: () => context.push('/consultation/chat/${apt.id}'),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: const Text('Chat'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(80, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/consultation/room/${apt.id}'),
                        icon: const Icon(Icons.videocam_rounded, size: 16),
                        label: const Text('Join Video'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(110, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (apt.status == AppointmentStatus.requested ||
                        apt.status == AppointmentStatus.confirmed) ...[
                      TextButton(
                        onPressed: () => _showCancelDialog(context, ref, apt),
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        child: const Text('Cancel'),
                      ),
                    ],

                    if (apt.prescriptionId != null) ...[
                      ElevatedButton.icon(
                        onPressed: () => context.push('/prescription/${apt.prescriptionId}'),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('View Prescription'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          minimumSize: const Size(140, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
