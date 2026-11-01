import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import 'patient_doctors_screen.dart';

class PatientAppointmentsScreen extends ConsumerWidget {
  final ScrollController? scrollController;

  const PatientAppointmentsScreen({super.key, this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final isDark = AppColors.isDark(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: surfaceColor,
            child: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
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
                  isDark: isDark,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  scrollController: scrollController,
                ),
                _AppointmentsList(
                  appointments: completed,
                  emptyTitle: 'No Completed Consultations',
                  emptyDescription: 'Past consultations and issued digital prescriptions will appear here.',
                  isUpcoming: false,
                  isDark: isDark,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                _AppointmentsList(
                  appointments: cancelled,
                  emptyTitle: 'No Cancelled Appointments',
                  emptyDescription: 'Any cancelled or declined requests will be archived here.',
                  isUpcoming: false,
                  isDark: isDark,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
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
  final bool isDark;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final ScrollController? scrollController;

  const _AppointmentsList({
    required this.appointments,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.isUpcoming,
    required this.isDark,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    this.scrollController,
  });

  void _showCancelDialog(
      BuildContext context, WidgetRef ref, AppointmentModel apt) {
    final isEligible =
        DateTimeUtils.isEligibleForCancellation(apt.scheduledTimeUtc);

    if (!isEligible) {
      showDialog(
        context: context,
        builder: (ctx) => AppDialog(
          icon: Icons.access_time_rounded,
          tone: AppDialogTone.warning,
          title: 'Cancellation Policy Alert',
          message:
              'Appointments can only be cancelled at least 2 hours before the scheduled time.\n\nYour appointment is scheduled in ${DateTimeUtils.hoursUntil(apt.scheduledTimeUtc).toStringAsFixed(1)} hours. Please contact customer support for emergency assistance.',
          confirmLabel: 'Understood',
          onConfirm: () => Navigator.pop(ctx),
        ),
      );
      return;
    }

    final reasonController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: !isProcessing,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: Icons.event_busy_rounded,
          tone: AppDialogTone.destructive,
          title: 'Cancel Appointment',
          message:
              'Are you sure you want to cancel your consultation with ${apt.doctorName}?',
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: reasonController,
              enabled: !isProcessing,
              decoration: InputDecoration(
                labelText: 'Reason for Cancellation (Required)',
                hintText: 'e.g. Schedule conflict...',
                labelStyle: TextStyle(fontSize: 13, color: textSecondary),
              ),
            ),
          ),
          cancelLabel: 'Keep',
          cancelIsEnabled: !isProcessing,
          onCancel: () => Navigator.pop(ctx),
          confirmLabel: 'Cancel',
          confirmIsDestructive: true,
          confirmIsLoading: isProcessing,
          confirmIsEnabled: !isProcessing,
          onConfirm: () async {
            final reason = reasonController.text.trim();
            if (reason.isEmpty) return;

            setDialogState(() => isProcessing = true);

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

              if (ctx.mounted) {
                Navigator.pop(ctx);
              }

              if (context.mounted) {
                AppSnackBar.showInfo(
                  context,
                  'Appointment cancelled successfully.',
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                setDialogState(() => isProcessing = false);
              }
              if (context.mounted) {
                AppSnackBar.showError(context, e.toString());
              }
            }
          },
        ),
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
        onAction: isUpcoming
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PatientDoctorsScreen(),
                  ),
                );
              }
            : null,
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 118),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final apt = appointments[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Booking #${apt.id.length > 8 ? apt.id.substring(0, 8).toUpperCase() : apt.id.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  StatusBadge(status: apt.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                apt.doctorName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                apt.doctorSpecialty,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? surfaceColor : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateTimeUtils.formatFullWithTimeZone(apt.scheduledTimeUtc),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (apt.reasonForVisit.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Reason: "${apt.reasonForVisit}"',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: textSecondary,
                  ),
                ),
              ],
              if (apt.cancellationReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Cancellation Note: ${apt.cancellationReason}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Divider(height: 1, thickness: 1, color: borderColor),
              const SizedBox(height: 10),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (apt.status == AppointmentStatus.confirmed ||
                      apt.status == AppointmentStatus.inProgress) ...[
                    OutlinedButton.icon(
                      onPressed: () => context.push('/consultation/chat/${apt.id}'),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                      label: const Text('Chat'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(76, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/consultation/room/${apt.id}'),
                      icon: const Icon(Icons.videocam_rounded, size: 15),
                      label: const Text('Join Video'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(100, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  if (apt.status == AppointmentStatus.requested ||
                      apt.status == AppointmentStatus.confirmed) ...[
                    TextButton(
                      onPressed: () => _showCancelDialog(context, ref, apt),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        minimumSize: const Size(60, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],

                  if (apt.prescriptionId != null) ...[
                    ElevatedButton.icon(
                      onPressed: () => context.push('/prescription/${apt.prescriptionId}'),
                      icon: const Icon(Icons.description_outlined, size: 15),
                      label: const Text('View Prescription'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(130, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
