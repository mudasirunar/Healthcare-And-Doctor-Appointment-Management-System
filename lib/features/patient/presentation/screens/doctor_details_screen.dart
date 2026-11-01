import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import 'booking_screen.dart';
import 'patient_appointment_detail_screen.dart';

class DoctorDetailsScreen extends ConsumerWidget {
  final String doctorId;

  const DoctorDetailsScreen({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorRepo = ref.watch(doctorRepositoryProvider);
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final appointments = appointmentsAsync.valueOrNull ?? [];
    final doctorAppointments = appointments
        .where((a) => a.doctorId == doctorId)
        .toList()
      ..sort((a, b) => b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc));
    final completedVisits = doctorAppointments
        .where((a) => a.status == AppointmentStatus.completed)
        .toList();
    final rxCount = doctorAppointments
        .where((a) => a.prescriptionId != null)
        .length;

    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Specialist Profile'),
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
      ),
      body: FutureBuilder<DoctorModel?>(
        future: doctorRepo.getDoctorById(doctorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
          }
          final doctor = snapshot.data;
          if (doctor == null) {
            return const ErrorStateView(message: 'Specialist record not found.');
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    // 1. Flat Header Section (Avatar, Name, Specialty, Verified Badge)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            backgroundImage: doctor.avatarUrl != null
                                ? NetworkImage(doctor.avatarUrl!)
                                : null,
                            child: doctor.avatarUrl == null
                                ? Text(
                                    doctor.doctorName.isNotEmpty
                                        ? doctor.doctorName
                                            .replaceFirst(RegExp(r'^Dr\.\s*'), '')
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
                                    fontSize: 20,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Verified',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.success,
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
                    Divider(height: 1, color: borderColor),

                    // 2. Flat Key Metrics Row
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
                            value: '\$${doctor.consultationFee.toStringAsFixed(0)}',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          _FlatStatItem(
                            label: 'Rating',
                            value: '${doctor.rating.toStringAsFixed(1)} ★',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
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
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Text(
                        'Clinical Biography',
                        style: AppTypography.headline.copyWith(
                          fontSize: 16,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        doctor.bio.isNotEmpty
                            ? doctor.bio
                            : 'No biography provided.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Divider(height: 1, color: borderColor),

                    // 4. Weekly Availability Hours (Flat greyish style matching admin)
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

                    // 5. Patient's Past Consultations & Prescriptions with This Doctor
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Text(
                          'No prior consultations or prescriptions with Dr. ${doctor.doctorName}.',
                          style: AppTypography.bodyMedium.copyWith(color: textSecondary),
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
                                    builder: (_) => PatientAppointmentDetailScreen(
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  DateTimeUtils.formatFullWithTimeZone(apt.scheduledTimeUtc),
                                                  style: AppTypography.bodyMedium.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: textPrimary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              StatusBadge(status: apt.status),
                                            ],
                                          ),
                                          if (apt.reasonForVisit.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Reason: ${apt.reasonForVisit}',
                                              style: AppTypography.caption.copyWith(
                                                color: textSecondary,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (hasRx) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.secondary.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.description_outlined,
                                                    size: 14,
                                                    color: AppColors.secondary,
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Digital Prescription Available',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.secondary,
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
                            Divider(height: 1, indent: 74, endIndent: 20, color: borderColor),
                          ],
                        );
                      }),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // 6. Sticky Bottom Action Bar (Book Appointment)
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
                            style: AppTypography.caption.copyWith(color: textSecondary),
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
                                  builder: (_) => BookingScreen(doctorId: doctor.id),
                                ),
                              );
                            },
                            icon: const Icon(Icons.calendar_month_rounded, size: 18),
                            label: const Text('Book Appointment', style: TextStyle(fontWeight: FontWeight.w700)),
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
          );
        },
      ),
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
