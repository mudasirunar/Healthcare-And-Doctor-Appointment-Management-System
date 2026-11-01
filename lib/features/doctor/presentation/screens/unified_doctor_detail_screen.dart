import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/user_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../admin/presentation/screens/admin_appointment_detail_screen.dart';
import '../../../admin/presentation/screens/admin_edit_doctor_screen.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../consultation/presentation/screens/prescription_viewer_screen.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import '../../../patient/presentation/screens/booking_screen.dart';
import '../../../patient/presentation/screens/patient_appointment_detail_screen.dart';

/// Unified Doctor Detail Screen reusable across Patient, Admin, and Doctor portals.
class UnifiedDoctorDetailScreen extends ConsumerWidget {
  final String doctorId;
  final UserRole? role;

  const UnifiedDoctorDetailScreen({
    super.key,
    required this.doctorId,
    this.role,
  });

  // --- Admin Actions ---
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
    ref.invalidate(allDoctorsAdminProvider);
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
    final effectiveRole =
        role ?? ref.watch(currentUserProvider)?.role ?? UserRole.patient;
    final isAdmin = effectiveRole == UserRole.admin;
    final isPatient = effectiveRole == UserRole.patient;

    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    // Fetch doctor record
    final doctorRepo = ref.watch(doctorRepositoryProvider);
    final adminDoctorsList = isAdmin
        ? (ref.watch(allDoctorsAdminProvider).valueOrNull ?? [])
        : <DoctorModel>[];
    final DoctorModel? preloadedAdminDoctor =
        adminDoctorsList.where((d) => d.id == doctorId).firstOrNull;

    return FutureBuilder<DoctorModel?>(
      initialData: preloadedAdminDoctor,
      future: preloadedAdminDoctor != null
          ? Future.value(preloadedAdminDoctor)
          : doctorRepo.getDoctorById(doctorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return Scaffold(
            backgroundColor: AppColors.backgroundOf(context),
            appBar: AppBar(
              title: const Text('Specialist Profile'),
              backgroundColor: surfaceColor,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            body: const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        }

        final doctor = snapshot.data;
        if (doctor == null) {
          return Scaffold(
            backgroundColor: AppColors.backgroundOf(context),
            appBar: AppBar(
              title: const Text('Specialist Profile'),
              backgroundColor: surfaceColor,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            body: const ErrorStateView(message: 'Specialist record not found.'),
          );
        }

        // Appointments and Prescriptions resolution
        final List<AppointmentModel> doctorAppointments;
        final List<dynamic> doctorPrescriptions;

        if (isAdmin) {
          final allApts =
              ref.watch(allAppointmentsAdminProvider).valueOrNull ?? [];
          final allRx =
              ref.watch(allPrescriptionsAdminProvider).valueOrNull ?? [];
          doctorAppointments =
              allApts.where((a) => a.doctorId == doctor.id).toList();
          doctorPrescriptions =
              allRx.where((r) => r.doctorId == doctor.id).toList();
        } else {
          final appointmentsAsync = ref.watch(userAppointmentsProvider);
          final appointments = appointmentsAsync.valueOrNull ?? [];
          doctorAppointments = appointments
              .where((a) => a.doctorId == doctorId)
              .toList()
            ..sort((a, b) => b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc));
          doctorPrescriptions = [];
        }

        final completedVisits = doctorAppointments
            .where((a) => a.status == AppointmentStatus.completed)
            .toList();
        final rxCount = doctorAppointments
            .where((a) => a.prescriptionId != null)
            .length;

        final statusColor = switch (doctor.verificationStatus) {
          VerificationStatus.approved => AppColors.success,
          VerificationStatus.pending => AppColors.warning,
          VerificationStatus.rejected => AppColors.error,
        };

        return Scaffold(
          backgroundColor: AppColors.backgroundOf(context),
          appBar: AppBar(
            title: const Text('Specialist Profile'),
            backgroundColor: surfaceColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: isPatient
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child:
                        Divider(height: 1, thickness: 1, color: borderColor),
                  )
                : null,
            actions: isAdmin
                ? [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit Specialist',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminEditDoctorScreen(doctor: doctor),
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
                              builder: (_) =>
                                  AdminEditDoctorScreen(doctor: doctor),
                            ),
                          );
                        } else if (action == 'reassign') {
                          _showQuickReassignSpecialtyDialog(
                              context, ref, doctor);
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
                  ]
                : null,
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(bottom: isAdmin ? 40 : 24),
                  children: [
                    // 1. Flat Header Section (Avatar, Name, Specialty, Status Badge)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isAdmin)
                            Container(
                              width: 64,
                              height: 64,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.medical_services_rounded,
                                color: AppColors.primary,
                                size: 30,
                              ),
                            )
                          else
                            CircleAvatar(
                              radius: 32,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.12),
                              backgroundImage: doctor.avatarUrl != null
                                  ? NetworkImage(doctor.avatarUrl!)
                                  : null,
                              child: doctor.avatarUrl == null
                                  ? Text(
                                      doctor.doctorName.isNotEmpty
                                          ? doctor.doctorName
                                              .replaceFirst(
                                                  RegExp(r'^Dr\.\s*'), '')
                                              .characters
                                              .first
                                              .toUpperCase()
                                          : 'D',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : null,
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctor.doctorName,
                                  style: AppTypography.display.copyWith(
                                    fontSize: isAdmin ? 21 : 20,
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
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isAdmin
                                            ? statusColor
                                            : AppColors.success)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isAdmin
                                        ? doctor
                                            .verificationStatus.displayName
                                        : 'Verified',
                                    style: AppTypography.caption.copyWith(
                                      color: isAdmin
                                          ? statusColor
                                          : AppColors.success,
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

                    // Admin Verification Action Strip (if pending credentials)
                    if (isAdmin &&
                        doctor.verificationStatus == VerificationStatus.pending)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showRejectDialog(context, ref, doctor),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text('Decline'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side:
                                      const BorderSide(color: AppColors.error),
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

                    // 2. Flat Key Metrics Row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _FlatStatItem(
                            label: 'Experience',
                            value: '${doctor.experienceYears} yrs',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          _FlatStatItem(
                            label: 'Consult Fee',
                            value:
                                '\$${doctor.consultationFee.toStringAsFixed(0)}',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          _FlatStatItem(
                            label: 'Rating',
                            value: isAdmin
                                ? '${doctor.rating.toStringAsFixed(1)} ★ (${doctor.reviewCount})'
                                : '${doctor.rating.toStringAsFixed(1)} ★',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          if (isAdmin)
                            _FlatStatItem(
                              label: 'Bookings',
                              value: '${doctorAppointments.length}',
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            )
                          else
                            _FlatStatItem(
                              label: 'Reviews',
                              value: '${doctor.reviewCount}',
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: borderColor),

                    // 3. Biography & Clinical Background
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          20, 18, 20, isAdmin ? 18 : 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clinical Biography',
                            style: AppTypography.headline.copyWith(
                              fontSize: 16,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            doctor.bio.isNotEmpty
                                ? doctor.bio
                                : 'No biography provided.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: textSecondary,
                              height: 1.5,
                            ),
                          ),
                          if (isAdmin &&
                              doctor.verificationNotes != null &&
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
                    if (isPatient) const SizedBox(height: 10),
                    Divider(height: 1, color: borderColor),

                    // 4. Weekly Consultation Schedule
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Text(
                        'Weekly Consultation Schedule (${doctor.slotDurationMinutes} min slots)',
                        style: AppTypography.headline.copyWith(
                          fontSize: 16,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    if (doctor.weeklyAvailability.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Text(
                          'No recurring schedule configured.',
                          style: AppTypography.bodyMedium
                              .copyWith(color: textSecondary),
                        ),
                      )
                    else
                      ...doctor.weeklyAvailability.entries.map((entry) {
                        final windows = entry.value
                            .map((w) => '${w.start} – ${w.end}')
                            .join(', ');
                        final capitalizedDay =
                            entry.key[0].toUpperCase() + entry.key.substring(1);
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                capitalizedDay,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
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

                    // 5. Appointments Section
                    if (isAdmin) ...[
                      // Admin view: All hospital appointments for this doctor
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                        child: Text(
                          'Appointments (${doctorAppointments.length})',
                          style: AppTypography.headline
                              .copyWith(color: textPrimary),
                        ),
                      ),
                      if (doctorAppointments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Text(
                            'No appointments recorded for this specialist yet.',
                            style: AppTypography.bodyMedium
                                .copyWith(color: textSecondary),
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
                                      builder: (_) =>
                                          AdminAppointmentDetailScreen(
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
                                          color: AppColors.primary
                                              .withValues(alpha: 0.12),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              apt.patientName,
                                              style: AppTypography.bodyLarge
                                                  .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${DateTimeUtils.formatLocalDate(apt.scheduledTimeUtc)} • ${DateTimeUtils.formatLocalTime(apt.scheduledTimeUtc)} • ${apt.reasonForVisit}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.caption
                                                  .copyWith(
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

                      // 6. Admin Prescriptions Issued Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                        child: Text(
                          'Prescriptions Issued (${doctorPrescriptions.length})',
                          style: AppTypography.headline
                              .copyWith(color: textPrimary),
                        ),
                      ),
                      if (doctorPrescriptions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Text(
                            'No digital prescriptions issued yet.',
                            style: AppTypography.bodyMedium
                                .copyWith(color: textSecondary),
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
                                      builder: (_) =>
                                          PrescriptionViewerScreen(
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
                                          color: AppColors.primary
                                              .withValues(alpha: 0.12),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Patient: ${rx.patientName}',
                                              style: AppTypography.bodyLarge
                                                  .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Diagnosis: ${rx.diagnosis} • ${rx.medications.length} medication(s)',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.caption
                                                  .copyWith(
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

                      // Admin Remove Specialist Action Button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _confirmDeleteDoctor(context, ref, doctor),
                          icon:
                              const Icon(Icons.delete_outline_rounded, size: 20),
                          label: const Text('Remove Specialist from Registry'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(
                                color: AppColors.error, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Patient view: Past Consultations & Prescriptions with this Doctor
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your Consultations (${doctorAppointments.length})',
                              style: AppTypography.headline.copyWith(
                                fontSize: 16,
                                color: textPrimary,
                              ),
                            ),
                            if (doctorAppointments.isNotEmpty)
                              Text(
                                '$rxCount Prescriptions • ${completedVisits.length} Completed',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (doctorAppointments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Text(
                            'No prior consultations or prescriptions with Dr. ${doctor.doctorName}.',
                            style: AppTypography.bodyMedium
                                .copyWith(color: textSecondary),
                          ),
                        )
                      else
                        ...doctorAppointments.map((apt) {
                          final hasRx = apt.prescriptionId != null;
                          return Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PatientAppointmentDetailScreen(
                                        appointmentId: apt.id,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          hasRx
                                              ? Icons.medication_outlined
                                              : Icons.event_available_outlined,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    DateTimeUtils
                                                        .formatFullWithTimeZone(
                                                            apt.scheduledTimeUtc),
                                                    style: AppTypography
                                                        .bodyMedium
                                                        .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                StatusBadge(status: apt.status),
                                              ],
                                            ),
                                            if (apt.reasonForVisit
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Reason: ${apt.reasonForVisit}',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                  color: textSecondary,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            if (hasRx) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.secondary
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .description_outlined,
                                                      size: 14,
                                                      color:
                                                          AppColors.secondary,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Digital Prescription Available',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppColors
                                                            .secondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: textSecondary,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Divider(
                                  height: 1,
                                  indent: 74,
                                  endIndent: 20,
                                  color: borderColor),
                            ],
                          );
                        }),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),

              // Sticky Bottom Action Bar (Book Appointment for Patients)
              if (isPatient)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Consultation Fee',
                              style: AppTypography.caption
                                  .copyWith(color: textSecondary),
                            ),
                            Text(
                              '\$${doctor.consultationFee.toStringAsFixed(0)}',
                              style: AppTypography.headline.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        BookingScreen(doctorId: doctor.id),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.calendar_month_rounded,
                                  size: 18),
                              label: const Text('Book Appointment',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FlatStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;

  const _FlatStatItem({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.headline.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
