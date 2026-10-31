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
import '../../../consultation/presentation/screens/prescription_viewer_screen.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import 'admin_appointment_detail_screen.dart';
import 'admin_edit_doctor_screen.dart';

class AdminDoctorDetailScreen extends ConsumerWidget {
  final String doctorId;

  const AdminDoctorDetailScreen({
    super.key,
    required this.doctorId,
  });

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    DoctorModel doctor,
    VerificationStatus status, [
    String? notes,
  ]) async {
    if (status == VerificationStatus.approved) {
      AppSnackBar.showSuccess(
        context,
        '${doctor.doctorName} approved and published.',
      );
    } else {
      AppSnackBar.showWarning(
        context,
        '${doctor.doctorName} status updated to ${status.displayName}.',
      );
    }
    await ref
        .read(doctorRepositoryProvider)
        .updateVerificationStatus(doctor.id, status, notes);
    ref.invalidate(filteredDoctorsProvider);
  }

  void _showQuickReassignSpecialtyDialog(
    BuildContext context,
    WidgetRef ref,
    DoctorModel doctor,
  ) {
    final specialties = ref.read(specialtiesProvider).valueOrNull ?? [];
    if (specialties.isEmpty) return;
    String selectedId = doctor.specialtyId;
    String selectedName = doctor.specialtyName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AppDialog(
          icon: Icons.swap_horiz_rounded,
          tone: AppDialogTone.primary,
          title: 'Reassign Department',
          message:
              'Select a new clinical department for Dr. ${doctor.doctorName}:',
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButtonFormField<String>(
              value: specialties.any((s) => s.id == selectedId)
                  ? selectedId
                  : specialties.first.id,
              decoration: const InputDecoration(
                labelText: 'Department',
                prefixIcon: Icon(Icons.grid_view_rounded),
              ),
              items: specialties.map((s) {
                return DropdownMenuItem<String>(
                  value: s.id,
                  child: Text(s.name),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  final matched = specialties.firstWhere((s) => s.id == val);
                  setModalState(() {
                    selectedId = matched.id;
                    selectedName = matched.name;
                  });
                }
              },
            ),
          ),
          cancelLabel: 'Cancel',
          onCancel: () => Navigator.pop(ctx),
          confirmLabel: 'Reassign',
          onConfirm: () async {
            Navigator.pop(ctx);
            final updated = doctor.copyWith(
              specialtyId: selectedId,
              specialtyName: selectedName,
            );
            await ref
                .read(doctorRepositoryProvider)
                .updateDoctorProfile(updated);
            ref.invalidate(allDoctorsAdminProvider);
            ref.invalidate(filteredDoctorsProvider);

            UserNotificationService.instance.sendDoctorNotification(
              doctorUserId: doctor.userId,
              title: 'Specialty Department Reassigned',
              body:
                  'Hospital administration reassigned your specialty to $selectedName.',
              type: 'specialty_reassigned',
            );

            if (context.mounted) {
              AppSnackBar.showSuccess(
                context,
                'Dr. ${doctor.doctorName} reassigned to $selectedName.',
              );
            }
          },
        ),
      ),
    );
  }

  void _confirmDeleteDoctor(
    BuildContext context,
    WidgetRef ref,
    DoctorModel doctor,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.delete_outline_rounded,
        tone: AppDialogTone.destructive,
        title: 'Remove Doctor?',
        message:
            'Are you sure you want to remove Dr. ${doctor.doctorName} (License: ${doctor.licenseNumber}) from the hospital registry? All active slot registrations will be removed.',
        cancelLabel: 'Cancel',
        onCancel: () => Navigator.pop(ctx),
        confirmLabel: 'Remove Doctor',
        confirmIsDestructive: true,
        onConfirm: () async {
          Navigator.pop(ctx);
          await ref.read(doctorRepositoryProvider).deleteDoctor(doctor.id);
          ref.invalidate(allDoctorsAdminProvider);
          ref.invalidate(filteredDoctorsProvider);

          UserNotificationService.instance.sendDoctorNotification(
            doctorUserId: doctor.userId,
            title: 'Account Removed from Registry',
            body:
                'Your specialist profile was removed from the active directory by hospital administration.',
            type: 'doctor_removed',
          );

          if (context.mounted) {
            AppSnackBar.showSuccess(
              context,
              'Dr. ${doctor.doctorName} removed from registry.',
            );
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showRejectDialog(
    BuildContext context,
    WidgetRef ref,
    DoctorModel doctor,
  ) {
    final reasonCtrl = TextEditingController(text: doctor.verificationNotes);
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.gpp_bad_outlined,
        tone: AppDialogTone.destructive,
        title: 'Decline Credentials',
        message: 'Provide a reason for declining Dr. ${doctor.doctorName}:',
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: reasonCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText:
                  'e.g. Medical board license number could not be verified',
            ),
          ),
        ),
        cancelLabel: 'Cancel',
        onCancel: () => Navigator.pop(ctx),
        confirmLabel: 'Decline',
        confirmIsDestructive: true,
        onConfirm: () async {
          final reason = reasonCtrl.text.trim();
          if (reason.isEmpty) return;
          Navigator.pop(ctx);
          await _updateStatus(
            context,
            ref,
            doctor,
            VerificationStatus.rejected,
            reason,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allDocs = ref.watch(allDoctorsAdminProvider).valueOrNull ?? [];
    final allApts = ref.watch(allAppointmentsAdminProvider).valueOrNull ?? [];
    final allRx = ref.watch(allPrescriptionsAdminProvider).valueOrNull ?? [];

    final doctor = allDocs.where((d) => d.id == doctorId).firstOrNull;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);

    if (doctor == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundOf(context),
        appBar: AppBar(title: const Text('Specialist Details')),
        body: Center(
          child: Text(
            'Specialist record not found.',
            style: AppTypography.bodyMedium.copyWith(color: textSecondary),
          ),
        ),
      );
    }

    final doctorAppointments =
        allApts.where((a) => a.doctorId == doctor.id).toList();
    final doctorPrescriptions =
        allRx.where((r) => r.doctorId == doctor.id).toList();

    final statusColor = switch (doctor.verificationStatus) {
      VerificationStatus.approved => AppColors.success,
      VerificationStatus.pending => AppColors.warning,
      VerificationStatus.rejected => AppColors.error,
    };

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Specialist Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Specialist',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminEditDoctorScreen(doctor: doctor),
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
                    builder: (_) => AdminEditDoctorScreen(doctor: doctor),
                  ),
                );
              } else if (action == 'reassign') {
                _showQuickReassignSpecialtyDialog(context, ref, doctor);
              } else if (action == 'delete') {
                _confirmDeleteDoctor(context, ref, doctor);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Edit Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reassign',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Change Department'),
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
                      'Remove from Registry',
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
          // 1. Flat Header Section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medical_services_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.doctorName,
                        style: AppTypography.display.copyWith(
                          fontSize: 21,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${doctor.specialtyName} • License ${doctor.licenseNumber}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          doctor.verificationStatus.displayName,
                          style: AppTypography.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Verification Action Strip (if pending or needs status change)
          if (doctor.verificationStatus == VerificationStatus.pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(context, ref, doctor),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(
                        context,
                        ref,
                        doctor,
                        VerificationStatus.approved,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Divider(height: 1, color: borderColor),

          // 3. Flat Key Metrics Row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _FlatStatItem(
                  label: 'Experience',
                  value: '${doctor.experienceYears} yrs',
                ),
                _FlatStatItem(
                  label: 'Consult Fee',
                  value: '\$${doctor.consultationFee.toStringAsFixed(0)}',
                ),
                _FlatStatItem(
                  label: 'Rating',
                  value: '${doctor.rating.toStringAsFixed(1)} ★ (${doctor.reviewCount})',
                ),
                _FlatStatItem(
                  label: 'Bookings',
                  value: '${doctorAppointments.length}',
                ),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),

          // 4. Biography & Clinical Background
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clinical Biography',
                  style: AppTypography.headline.copyWith(color: textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  doctor.bio.isEmpty
                      ? 'No biography provided.'
                      : doctor.bio,
                  style: AppTypography.bodyMedium.copyWith(
                    color: textSecondary,
                    height: 1.5,
                  ),
                ),
                if (doctor.verificationNotes != null &&
                    doctor.verificationNotes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Verification Note: ${doctor.verificationNotes}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),

          // 5. Weekly Availability Schedule
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Weekly Consultation Schedule (${doctor.slotDurationMinutes} min slots)',
              style: AppTypography.headline.copyWith(color: textPrimary),
            ),
          ),
          if (doctor.weeklyAvailability.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'No recurring schedule configured.',
                style: AppTypography.bodyMedium.copyWith(color: textSecondary),
              ),
            )
          else
            ...doctor.weeklyAvailability.entries.map((entry) {
              final windows = entry.value
                  .map((w) => '${w.start} – ${w.end}')
                  .join(', ');
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key[0].toUpperCase() + entry.key.substring(1),
                      style: AppTypography.bodyMedium.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      windows.isEmpty ? 'Closed' : windows,
                      style: AppTypography.bodyMedium.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          Divider(height: 1, color: borderColor),

          // 6. Appointments With This Doctor
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Appointments (${doctorAppointments.length})',
              style: AppTypography.headline.copyWith(color: textPrimary),
            ),
          ),
          if (doctorAppointments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'No appointments recorded for this specialist yet.',
                style: AppTypography.bodyMedium.copyWith(color: textSecondary),
              ),
            )
          else
            ...doctorAppointments.map((apt) {
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
                                  apt.patientName,
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

          // 7. Prescriptions Issued By This Doctor
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Prescriptions Issued (${doctorPrescriptions.length})',
              style: AppTypography.headline.copyWith(color: textPrimary),
            ),
          ),
          if (doctorPrescriptions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'No digital prescriptions issued yet.',
                style: AppTypography.bodyMedium.copyWith(color: textSecondary),
              ),
            )
          else
            ...doctorPrescriptions.map((rx) {
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
                                  'Patient: ${rx.patientName}',
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Diagnosis: ${rx.diagnosis} • ${rx.medications.length} medication(s)',
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

          // Remove Specialist Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: OutlinedButton.icon(
              onPressed: () => _confirmDeleteDoctor(context, ref, doctor),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text('Remove Specialist from Registry'),
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

class _FlatStatItem extends StatelessWidget {
  final String label;
  final String value;

  const _FlatStatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.headline.copyWith(
            fontSize: 16,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}
