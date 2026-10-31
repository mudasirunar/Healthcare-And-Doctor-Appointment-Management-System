import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/user_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../consultation/presentation/screens/prescription_viewer_screen.dart';
import 'admin_doctor_detail_screen.dart';
import 'admin_patient_detail_screen.dart';

class AdminAppointmentDetailScreen extends ConsumerWidget {
  final String appointmentId;

  const AdminAppointmentDetailScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allApts = ref.watch(allAppointmentsAdminProvider).valueOrNull ?? [];
    final appointment =
        allApts.where((a) => a.id == appointmentId).firstOrNull;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);

    if (appointment == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundOf(context),
        appBar: AppBar(title: const Text('Appointment Details')),
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
        actions: [
          if (!appointment.status.isTerminal)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) {
                if (val == 'cancel') {
                  _showCancelDialog(context, ref, appointment);
                } else if (val == 'confirm') {
                  _confirmAppointment(context, ref, appointment);
                } else if (val == 'complete') {
                  _completeAppointment(context, ref, appointment);
                }
              },
              itemBuilder: (ctx) => [
                if (appointment.status == AppointmentStatus.requested)
                  const PopupMenuItem(
                    value: 'confirm',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppColors.success,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text('Confirm Booking'),
                      ],
                    ),
                  ),
                if (appointment.status == AppointmentStatus.inProgress)
                  const PopupMenuItem(
                    value: 'complete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text('Complete Consultation'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: AppColors.error,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text('Cancel Consultation (Admin)'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // 1. Header Status & Schedule
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
                  'Duration: ${appointment.durationMinutes} minutes • Room: ${appointment.videoRoomId}',
                  style: AppTypography.caption.copyWith(color: textSecondary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),

          // 2. Clickable Patient & Specialist Rows
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Participants',
              style: AppTypography.headline.copyWith(color: textPrimary),
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminDoctorDetailScreen(
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
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminPatientDetailScreen(
                    patientId: appointment.patientId,
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
                          appointment.patientName,
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
                  Icon(Icons.chevron_right_rounded, color: textSecondary),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: borderColor),

          // 3. Reason for Visit, Notes & Cancellation
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
                    'Cancellation / Decline Reason',
                    style: AppTypography.headline.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    appointment.cancellationReason!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.error,
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
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.description_outlined,
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
                            'View Digital Prescription',
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Issued during this consultation',
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

          // 6. Administrative Actions (when not in a terminal state)
          if (!appointment.status.isTerminal) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Administrative Actions',
                style: AppTypography.headline.copyWith(color: textPrimary),
              ),
            ),
            if (appointment.status == AppointmentStatus.requested)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: ElevatedButton.icon(
                  onPressed: () => _confirmAppointment(context, ref, appointment),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: const Text('Confirm Consultation Booking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            if (appointment.status == AppointmentStatus.inProgress)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: ElevatedButton.icon(
                  onPressed: () => _completeAppointment(context, ref, appointment),
                  icon: const Icon(Icons.task_alt_rounded, size: 20),
                  label: const Text('Mark Consultation as Completed'),
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
                onPressed: () => _showCancelDialog(context, ref, appointment),
                icon: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.error,
                  size: 20,
                ),
                label: const Text('Cancel Consultation (Admin Action)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCancelDialog(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
  ) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.cancel_outlined,
        tone: AppDialogTone.destructive,
        title: 'Cancel Consultation',
        message:
            'Are you sure you want to cancel this booking between ${appointment.patientName} and ${appointment.doctorName}? This releases the slot lock in the schedule.',
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason *',
                hintText:
                    'e.g., Doctor emergency reassignment, hospital maintenance...',
                alignLabelWithHint: true,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please provide a valid cancellation reason.';
                }
                return null;
              },
            ),
          ),
        ),
        cancelLabel: 'Dismiss',
        onCancel: () => Navigator.pop(ctx),
        confirmLabel: 'Confirm Cancellation',
        confirmIsDestructive: true,
        onConfirm: () async {
          if (!formKey.currentState!.validate()) return;
          final reason = reasonController.text.trim();
          Navigator.pop(ctx);

          try {
            final adminUser = ref.read(currentUserProvider);
            await ref.read(appointmentRepositoryProvider).updateStatus(
                  appointmentId: appointment.id,
                  targetStatus: AppointmentStatus.cancelled,
                  actorUserId: adminUser?.id ?? 'admin',
                  isPatientActor: false,
                  note: 'Admin Cancellation: $reason',
                  cancellationReason: reason,
                );

            ref.invalidate(allAppointmentsAdminProvider);
            ref.invalidate(userAppointmentsProvider);
            ref.invalidate(adminAnalyticsProvider);

            final allDoctors =
                ref.read(allDoctorsAdminProvider).valueOrNull ?? [];
            final doctor = allDoctors
                .where((d) =>
                    d.id == appointment.doctorId ||
                    d.userId == appointment.doctorId)
                .firstOrNull;
            final doctorUserId = doctor?.userId ?? appointment.doctorId;

            await UserNotificationService.instance.sendDoctorNotification(
              doctorUserId: doctorUserId,
              title: 'Consultation Cancelled by Administration',
              body:
                  'Consultation with ${appointment.patientName} was cancelled by Admin. Reason: $reason',
              type: 'appointment_cancelled_by_admin',
            );

            await UserNotificationService.instance.sendPatientNotification(
              patientUserId: appointment.patientId,
              title: 'Consultation Cancelled by Administration',
              body:
                  'Your appointment with ${appointment.doctorName} was cancelled by Admin. Reason: $reason',
              type: 'appointment_cancelled_by_admin',
            );

            if (context.mounted) {
              AppSnackBar.showSuccess(
                context,
                'Consultation cancelled by administration.',
              );
            }
          } catch (e) {
            if (context.mounted) {
              AppSnackBar.showError(
                context,
                'Failed to cancel consultation: $e',
              );
            }
          }
        },
      ),
    );
  }

  void _confirmAppointment(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.check_circle_outline_rounded,
        tone: AppDialogTone.success,
        title: 'Confirm Consultation',
        message:
            'Confirm booking for ${appointment.patientName} with ${appointment.doctorName} on ${DateTimeUtils.formatFullWithTimeZone(appointment.scheduledTimeUtc)}?',
        cancelLabel: 'Cancel',
        onCancel: () => Navigator.pop(ctx),
        confirmLabel: 'Confirm Booking',
        onConfirm: () async {
          Navigator.pop(ctx);
          try {
            final adminUser = ref.read(currentUserProvider);
            await ref.read(appointmentRepositoryProvider).updateStatus(
                  appointmentId: appointment.id,
                  targetStatus: AppointmentStatus.confirmed,
                  actorUserId: adminUser?.id ?? 'admin',
                  isPatientActor: false,
                  note: 'Confirmed by Administrator',
                );

            ref.invalidate(allAppointmentsAdminProvider);
            ref.invalidate(userAppointmentsProvider);
            ref.invalidate(adminAnalyticsProvider);

            final allDoctors =
                ref.read(allDoctorsAdminProvider).valueOrNull ?? [];
            final doctor = allDoctors
                .where((d) =>
                    d.id == appointment.doctorId ||
                    d.userId == appointment.doctorId)
                .firstOrNull;
            final doctorUserId = doctor?.userId ?? appointment.doctorId;

            await UserNotificationService.instance.sendDoctorNotification(
              doctorUserId: doctorUserId,
              title: 'Consultation Confirmed by Admin',
              body:
                  'Appointment with ${appointment.patientName} has been approved by administration.',
              type: 'appointment_confirmed',
            );

            await UserNotificationService.instance.sendPatientNotification(
              patientUserId: appointment.patientId,
              title: 'Consultation Confirmed by Admin',
              body:
                  'Your appointment with ${appointment.doctorName} has been confirmed by administration.',
              type: 'appointment_confirmed',
            );

            if (context.mounted) {
              AppSnackBar.showSuccess(
                context,
                'Consultation confirmed successfully.',
              );
            }
          } catch (e) {
            if (context.mounted) {
              AppSnackBar.showError(
                context,
                'Failed to confirm consultation: $e',
              );
            }
          }
        },
      ),
    );
  }

  void _completeAppointment(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.task_alt_rounded,
        tone: AppDialogTone.primary,
        title: 'Complete Consultation',
        message:
            'Mark consultation between ${appointment.patientName} and ${appointment.doctorName} as completed?',
        cancelLabel: 'Cancel',
        onCancel: () => Navigator.pop(ctx),
        confirmLabel: 'Mark Completed',
        onConfirm: () async {
          Navigator.pop(ctx);
          try {
            final adminUser = ref.read(currentUserProvider);
            await ref.read(appointmentRepositoryProvider).updateStatus(
                  appointmentId: appointment.id,
                  targetStatus: AppointmentStatus.completed,
                  actorUserId: adminUser?.id ?? 'admin',
                  isPatientActor: false,
                  note: 'Marked completed by Administrator',
                );

            ref.invalidate(allAppointmentsAdminProvider);
            ref.invalidate(userAppointmentsProvider);
            ref.invalidate(adminAnalyticsProvider);

            final allDoctors =
                ref.read(allDoctorsAdminProvider).valueOrNull ?? [];
            final doctor = allDoctors
                .where((d) =>
                    d.id == appointment.doctorId ||
                    d.userId == appointment.doctorId)
                .firstOrNull;
            final doctorUserId = doctor?.userId ?? appointment.doctorId;

            await UserNotificationService.instance.sendDoctorNotification(
              doctorUserId: doctorUserId,
              title: 'Consultation Completed',
              body:
                  'Appointment with ${appointment.patientName} was concluded and marked completed by administration.',
              type: 'appointment_completed',
            );

            await UserNotificationService.instance.sendPatientNotification(
              patientUserId: appointment.patientId,
              title: 'Consultation Completed',
              body:
                  'Your consultation with ${appointment.doctorName} was marked completed by administration.',
              type: 'appointment_completed',
            );

            if (context.mounted) {
              AppSnackBar.showSuccess(
                context,
                'Consultation marked as completed.',
              );
            }
          } catch (e) {
            if (context.mounted) {
              AppSnackBar.showError(
                context,
                'Failed to complete consultation: $e',
              );
            }
          }
        },
      ),
    );
  }
}
