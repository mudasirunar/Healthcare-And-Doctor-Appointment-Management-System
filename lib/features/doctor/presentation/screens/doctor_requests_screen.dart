import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointment/domain/entities/appointment_model.dart';

class DoctorRequestsScreen extends ConsumerWidget {
  const DoctorRequestsScreen({super.key});

  void _handleApprove(BuildContext context, WidgetRef ref, AppointmentModel apt) async {
    final user = ref.read(currentUserProvider);
    try {
      await ref.read(appointmentRepositoryProvider).updateStatus(
        appointmentId: apt.id,
        targetStatus: AppointmentStatus.confirmed,
        actorUserId: user?.id ?? 'doctor',
        note: 'Doctor accepted appointment request',
      );
      ref.invalidate(userAppointmentsProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(
          context,
          'Appointment confirmed successfully!',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(context, e.toString());
      }
    }
  }

  void _handleDecline(BuildContext context, WidgetRef ref, AppointmentModel apt) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Appointment Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to decline ${apt.patientName}\'s request?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for declining',
                hintText: 'e.g. Schedule emergency...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final user = ref.read(currentUserProvider);
              try {
                await ref.read(appointmentRepositoryProvider).updateStatus(
                  appointmentId: apt.id,
                  targetStatus: AppointmentStatus.rejected,
                  actorUserId: user?.id ?? 'doctor',
                  note: reasonController.text.trim().isNotEmpty
                      ? reasonController.text.trim()
                      : 'Doctor declined request',
                );
                ref.invalidate(userAppointmentsProvider);
                if (context.mounted) {
                  AppSnackBar.showInfo(context, 'Appointment declined.');
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackBar.showError(context, e.toString());
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(userAppointmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Appointment Requests'),
      ),
      body: appointmentsAsync.when(
        data: (appointments) {
          final requests = appointments
              .where((a) => a.status == AppointmentStatus.requested)
              .toList();

          if (requests.isEmpty) {
            return const EmptyStateView(
              icon: Icons.inbox_rounded,
              title: 'No Pending Requests',
              description: 'You have reviewed all incoming consultation bookings. New patient requests will appear here in real time.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final apt = requests[index];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Request #${apt.id.toUpperCase()}', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Awaiting Action',
                              style: AppTypography.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(apt.patientName, style: AppTypography.headline),
                      Text(apt.patientEmail, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _handleDecline(context, ref, apt),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              minimumSize: const Size(100, 38),
                            ),
                            child: const Text('Decline'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => _handleApprove(context, ref, apt),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              minimumSize: const Size(110, 38),
                            ),
                            child: const Text('Accept'),
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
