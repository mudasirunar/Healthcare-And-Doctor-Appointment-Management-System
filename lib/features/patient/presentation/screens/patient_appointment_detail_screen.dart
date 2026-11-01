import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../consultation/presentation/screens/appointment_chat_screen.dart';
import '../../../consultation/presentation/screens/prescription_viewer_screen.dart';
import '../../../consultation/presentation/screens/video_consultation_screen.dart';
import 'doctor_details_screen.dart';

class PatientAppointmentDetailScreen extends ConsumerWidget {
  final String appointmentId;

  const PatientAppointmentDetailScreen({
    super.key,
    required this.appointmentId,
  });

  void _showCancelDialog(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel apt,
  ) {
    final textSecondary = AppColors.textSecondaryOf(context);

    // Enforce 2-hour cancellation rule
    if (!DateTimeUtils.isEligibleForCancellation(apt.scheduledTimeUtc)) {
      showDialog(
        context: context,
        builder: (ctx) => AppDialog(
          icon: Icons.access_time_filled_rounded,
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
          confirmLabel: 'Cancel Appointment',
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
    final appointmentAsync = ref.watch(singleAppointmentStreamProvider(appointmentId));
    final userAppointments = ref.watch(userAppointmentsProvider).valueOrNull ?? [];
    final appointment = appointmentAsync.valueOrNull ??
        userAppointments.where((a) => a.id == appointmentId).firstOrNull;

    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);
    final surfaceColor = AppColors.surfaceOf(context);

    if (appointment == null) {
      if (appointmentAsync.isLoading) {
        return Scaffold(
          backgroundColor: AppColors.backgroundOf(context),
          appBar: AppBar(
            title: const Text('Appointment Details'),
            backgroundColor: surfaceColor,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        );
      }
      return Scaffold(
        backgroundColor: AppColors.backgroundOf(context),
        appBar: AppBar(
          title: const Text('Appointment Details'),
          backgroundColor: surfaceColor,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: Center(
          child: Text(
            'Appointment record not found.',
            style: AppTypography.bodyMedium.copyWith(color: textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Appointment Details'),
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
      ),
      body: _buildDetailContent(context, ref, appointment, textPrimary, textSecondary, borderColor, surfaceColor),
    );
  }

  Widget _buildDetailContent(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    Color surfaceColor,
  ) {
    final canJoinCall = appointment.status == AppointmentStatus.confirmed ||
        appointment.status == AppointmentStatus.inProgress;
    final canCancel = !appointment.status.isTerminal;

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // 1. Header Status & Schedule (Flat on screen)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      DateTimeUtils.formatFullWithTimeZone(
                        appointment.scheduledTimeUtc,
                      ),
                      style: AppTypography.headline.copyWith(
                        fontSize: 18,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: appointment.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Duration: ${appointment.durationMinutes} mins • Room: ${appointment.displayRoomName} • Booking #${appointment.id.length > 8 ? appointment.id.substring(0, 8).toUpperCase() : appointment.id.toUpperCase()}',
                style: AppTypography.caption.copyWith(color: textSecondary),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),

        // 2. Participants (Doctor Clickable -> Doctor Details; Patient Non-Clickable "You")
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'Participants',
            style: AppTypography.headline.copyWith(color: textPrimary),
          ),
        ),
        // Doctor Row (Clickable)
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorDetailsScreen(
                  doctorId: appointment.doctorId,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medical_services_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.doctorName,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Specialist • ${appointment.doctorSpecialty}',
                        style: AppTypography.caption.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: textSecondary),
              ],
            ),
          ),
        ),
        Divider(height: 1, indent: 78, endIndent: 20, color: borderColor),

        // Patient Row (Non-clickable "You", as patient is viewing their own record)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${appointment.patientName} (You)',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Patient • ${appointment.patientEmail}',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),

        // 3. Reason for Visit, Notes & Cancellation Reason
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reason for Visit',
                style: AppTypography.headline.copyWith(color: textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                appointment.reasonForVisit.isNotEmpty
                    ? appointment.reasonForVisit
                    : 'Routine clinical consultation.',
                style: AppTypography.bodyMedium.copyWith(
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              if (appointment.consultationNotes != null &&
                  appointment.consultationNotes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Consultation Notes',
                  style: AppTypography.headline.copyWith(color: textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  appointment.consultationNotes!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              if (appointment.cancellationReason != null &&
                  appointment.cancellationReason!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Cancellation Reason',
                  style: AppTypography.headline.copyWith(
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  appointment.cancellationReason!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),

        // 4. Linked Prescription (if issued)
        if (appointment.prescriptionId != null &&
            appointment.prescriptionId!.isNotEmpty) ...[
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrescriptionViewerScreen(
                    prescriptionId: appointment.prescriptionId!,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppColors.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'View Digital Prescription',
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Issued during this consultation by Dr. ${appointment.doctorName}',
                          style: AppTypography.caption.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: textSecondary),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: borderColor),
        ],

        // 5. Status History Timeline
        if (appointment.statusHistory.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Status Timeline',
              style: AppTypography.headline.copyWith(color: textPrimary),
            ),
          ),
          ...appointment.statusHistory.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.status.displayName,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        if (entry.note != null && entry.note!.isNotEmpty)
                          Text(
                            entry.note!,
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    DateTimeUtils.formatFullWithTimeZone(entry.timestampUtc),
                    style: AppTypography.caption.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        // 6. Action Buttons for Patient
        if (canJoinCall || canCancel) ...[
          const SizedBox(height: 16),
          Divider(height: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Consultation Actions',
              style: AppTypography.headline.copyWith(color: textPrimary),
            ),
          ),
          if (canJoinCall) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoConsultationScreen(
                        appointmentId: appointment.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.videocam_rounded, size: 20),
                label: const Text('Join Video Consultation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppointmentChatScreen(
                        appointmentId: appointment.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                label: const Text('Chat with Doctor'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
          if (canCancel)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: OutlinedButton.icon(
                onPressed: () => _showCancelDialog(context, ref, appointment),
                icon: const Icon(Icons.cancel_outlined, size: 20),
                label: const Text('Cancel Consultation'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
