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
import 'patient_appointment_detail_screen.dart';
import 'patient_doctors_screen.dart';

class PatientAppointmentsScreen extends ConsumerWidget {
  final ScrollController? scrollController;
  final bool isStandalone;

  const PatientAppointmentsScreen({
    super.key,
    this.scrollController,
    this.isStandalone = false,
  });

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
        appBar: isStandalone
            ? AppBar(
                backgroundColor: surfaceColor,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: textPrimary,
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      context.go('/patient');
                    }
                  },
                ),
                title: Text(
                  'My Consultations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                bottom: PreferredSize(
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
              )
            : PreferredSize(
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
              ) as PreferredSizeWidget,
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
        final bookingCode = apt.id.length > 8 ? apt.id.substring(0, 8).toUpperCase() : apt.id.toUpperCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientAppointmentDetailScreen(appointmentId: apt.id),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: Doctor Profile & Status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primaryLight,
                          child: Text(
                            apt.doctorName.isNotEmpty
                                ? (apt.doctorName.startsWith('Dr.') && apt.doctorName.length > 4
                                    ? apt.doctorName.substring(4, 5).toUpperCase()
                                    : apt.doctorName[0].toUpperCase())
                                : 'D',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                apt.doctorName,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                apt.doctorSpecialty,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusBadge(status: apt.status),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: textSecondary.withOpacity(0.4),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Divider(height: 1, thickness: 1, color: borderColor),
                    const SizedBox(height: 12),

                    // Flat Schedule & Room Metadata Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.03)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
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
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.meeting_room_outlined,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Duration: ${apt.durationMinutes} mins • Room: ${apt.displayRoomName} • Booking #$bookingCode',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (apt.reasonForVisit.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reason: ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              apt.reasonForVisit,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (apt.cancellationReason != null && apt.cancellationReason!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'Cancellation Reason: ',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.error,
                                      ),
                                    ),
                                    TextSpan(
                                      text: apt.cancellationReason!,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w400,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Action Buttons Row
                    if (apt.status == AppointmentStatus.confirmed ||
                        apt.status == AppointmentStatus.inProgress ||
                        apt.status == AppointmentStatus.requested ||
                        apt.prescriptionId != null) ...[
                      const SizedBox(height: 12),
                      Divider(height: 1, thickness: 1, color: borderColor),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (apt.status == AppointmentStatus.requested ||
                              apt.status == AppointmentStatus.confirmed) ...[
                            OutlinedButton.icon(
                              onPressed: () => _showCancelDialog(context, ref, apt),
                              icon: const Icon(Icons.event_busy_rounded, size: 14),
                              label: const Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: BorderSide(color: AppColors.error.withOpacity(0.4)),
                                minimumSize: const Size(82, 34),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const Spacer(),
                          ] else ...[
                            const Spacer(),
                          ],

                          if (apt.status == AppointmentStatus.confirmed ||
                              apt.status == AppointmentStatus.inProgress) ...[
                            OutlinedButton.icon(
                              onPressed: () => context.push('/consultation/chat/${apt.id}'),
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                              label: const Text('Chat'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textPrimary,
                                side: BorderSide(color: borderColor),
                                minimumSize: const Size(78, 34),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
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
                                minimumSize: const Size(106, 34),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],

                          if (apt.prescriptionId != null) ...[
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => context.push('/prescription/${apt.prescriptionId}'),
                              icon: const Icon(Icons.description_outlined, size: 14),
                              label: const Text('Prescription'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(116, 34),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
