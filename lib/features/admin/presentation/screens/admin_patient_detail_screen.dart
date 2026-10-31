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
import '../../../auth/domain/entities/user_model.dart';
import '../../../consultation/presentation/screens/prescription_viewer_screen.dart';
import 'admin_appointment_detail_screen.dart';
import 'admin_doctor_detail_screen.dart';
import 'admin_edit_patient_screen.dart';

class AdminPatientDetailScreen extends ConsumerWidget {
  final String patientId;

  const AdminPatientDetailScreen({
    super.key,
    required this.patientId,
  });

  void _confirmDeletePatient(
    BuildContext context,
    WidgetRef ref,
    UserModel patient,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.delete_outline_rounded,
        tone: AppDialogTone.destructive,
        title: 'Remove Patient?',
        message:
            'Are you sure you want to remove ${patient.displayName} from hospital records? This action cannot be undone.',
        cancelLabel: 'Cancel',
        onCancel: () => Navigator.pop(ctx),
        confirmLabel: 'Remove Patient',
        confirmIsDestructive: true,
        onConfirm: () async {
          Navigator.pop(ctx);
          await ref
              .read(authRepositoryProvider)
              .deletePatientRecord(patient.id);
          ref.invalidate(allPatientsAdminProvider);

          UserNotificationService.instance.sendPatientNotification(
            patientUserId: patient.id,
            title: 'Account Record Removed',
            body:
                'Your patient profile was removed from hospital records by administration.',
            type: 'patient_removed',
          );

          if (context.mounted) {
            AppSnackBar.showSuccess(
              context,
              'Patient ${patient.displayName} removed from records.',
            );
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPatients = ref.watch(allPatientsAdminProvider).valueOrNull ?? [];
    final allDocs = ref.watch(allDoctorsAdminProvider).valueOrNull ?? [];
    final allApts = ref.watch(allAppointmentsAdminProvider).valueOrNull ?? [];
    final allRx = ref.watch(allPrescriptionsAdminProvider).valueOrNull ?? [];

    final patient = allPatients.where((p) => p.id == patientId).firstOrNull;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);

    if (patient == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundOf(context),
        appBar: AppBar(title: const Text('Patient Profile')),
        body: Center(
          child: Text(
            'Patient record not found.',
            style: AppTypography.bodyMedium.copyWith(color: textSecondary),
          ),
        ),
      );
    }

    final patientAppointments =
        allApts.where((a) => a.patientId == patient.id).toList();
    final patientPrescriptions =
        allRx.where((r) => r.patientId == patient.id).toList();

    final consultedDoctorIds =
        patientAppointments.map((a) => a.doctorId).toSet();
    final consultedDoctors =
        allDocs.where((d) => consultedDoctorIds.contains(d.id)).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Patient Profile & Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Records',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminEditPatientScreen(patient: patient),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) {
              if (action == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminEditPatientScreen(patient: patient),
                  ),
                );
              } else if (action == 'delete') {
                _confirmDeletePatient(context, ref, patient);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Edit Patient Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Remove from Records',
                      style: TextStyle(color: AppColors.error),
                    ),
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
          // 1. Flat Patient Identity Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    patient.displayName.isNotEmpty
                        ? patient.displayName[0].toUpperCase()
                        : 'P',
                    style: AppTypography.display.copyWith(
                      fontSize: 22,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.displayName,
                        style: AppTypography.display.copyWith(
                          fontSize: 21,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.mail_outline_rounded,
                            size: 15,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              patient.email,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (patient.phoneNumber != null &&
                          patient.phoneNumber!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 15,
                              color: textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                patient.phoneNumber!,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (patient.bloodGroup != null &&
                    patient.bloodGroup!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      patient.bloodGroup!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),

          // 2. Medical & Demographic Attributes (Flat Rows)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Clinical & Personal Information',
              style: AppTypography.headline.copyWith(color: textPrimary),
            ),
          ),
          _InfoRow(
            label: 'Gender',
            value: patient.gender?.isNotEmpty == true
                ? patient.gender!
                : 'Not specified',
          ),
          _InfoRow(
            label: 'Date of Birth',
            value: patient.dateOfBirth?.isNotEmpty == true
                ? patient.dateOfBirth!
                : 'Not specified',
          ),
          _InfoRow(
            label: 'Blood Group',
            value: patient.bloodGroup?.isNotEmpty == true
                ? patient.bloodGroup!
                : 'Not specified',
          ),
          _InfoRow(
            label: 'Known Allergies',
            value: patient.medicalAllergies?.isNotEmpty == true
                ? patient.medicalAllergies!
                : 'None reported',
          ),
          _InfoRow(
            label: 'Emergency Contact',
            value: patient.emergencyContact?.isNotEmpty == true
                ? patient.emergencyContact!
                : 'Not provided',
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: borderColor),

          // 3. Consulted Doctors
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Consulted Specialists (${consultedDoctors.length})',
              style: AppTypography.headline.copyWith(color: textPrimary),
            ),
          ),
          if (consultedDoctors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'No specialists consulted yet.',
                style: AppTypography.bodyMedium.copyWith(color: textSecondary),
              ),
            )
          else
            ...consultedDoctors.map((doc) {
              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminDoctorDetailScreen(
                            doctorId: doc.id,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
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
                                  doc.doctorName,
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${doc.specialtyName} • ${doc.experienceYears} yrs experience',
                                  style: AppTypography.caption.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 76,
                    endIndent: 20,
                    color: borderColor,
                  ),
                ],
              );
            }),

          // 4. Appointments & Calls History
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Appointments & Consultations (${patientAppointments.length})',
              style: AppTypography.headline.copyWith(color: textPrimary),
            ),
          ),
          if (patientAppointments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'No appointment history found for this patient.',
                style: AppTypography.bodyMedium.copyWith(color: textSecondary),
              ),
            )
          else
            ...patientAppointments.map((apt) {
              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminAppointmentDetailScreen(
                            appointmentId: apt.id,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.event_note_rounded,
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
                                  '${apt.doctorName} (${apt.doctorSpecialty})',
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${DateTimeUtils.formatLocalDate(apt.scheduledTimeUtc)} • ${DateTimeUtils.formatLocalTime(apt.scheduledTimeUtc)} • ${apt.reasonForVisit}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(status: apt.status),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 76,
                    endIndent: 20,
                    color: borderColor,
                  ),
                ],
              );
            }),

          // 5. Prescriptions & Clinical Records
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Prescriptions & Medical Records (${patientPrescriptions.length})',
              style: AppTypography.headline.copyWith(color: textPrimary),
            ),
          ),
          if (patientPrescriptions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'No prescriptions issued to this patient yet.',
                style: AppTypography.bodyMedium.copyWith(color: textSecondary),
              ),
            )
          else
            ...patientPrescriptions.map((rx) {
              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrescriptionViewerScreen(
                            prescriptionId: rx.id,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.medication_outlined,
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
                                  rx.diagnosis,
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'By ${rx.doctorName} • ${rx.medications.length} medication(s)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 76,
                    endIndent: 20,
                    color: borderColor,
                  ),
                ],
              );
            }),

          // Danger Remove Patient Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: OutlinedButton.icon(
              onPressed: () => _confirmDeletePatient(context, ref, patient),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text('Remove Patient from Hospital Records'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
