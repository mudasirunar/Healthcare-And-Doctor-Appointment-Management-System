import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/status_badge.dart';
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
        ],
      ),
    );
  }
}
