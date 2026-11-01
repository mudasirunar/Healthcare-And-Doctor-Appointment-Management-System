import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';

class DoctorDetailsScreen extends ConsumerWidget {
  final String doctorId;

  const DoctorDetailsScreen({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorRepo = ref.watch(doctorRepositoryProvider);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  'Doctor Profile',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder(
        future: doctorRepo.getDoctorById(doctorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
          }
          final doctor = snapshot.data;
          if (doctor == null) {
            return const ErrorStateView(message: 'Doctor not found.');
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: doctor.avatarUrl != null
                            ? NetworkImage(doctor.avatarUrl!)
                            : null,
                        child: doctor.avatarUrl == null
                            ? Text(
                                doctor.doctorName.isNotEmpty ? doctor.doctorName[0].toUpperCase() : 'D',
                                style: const TextStyle(
                                  fontSize: 24,
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    doctor.doctorName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                if (doctor.isVerified)
                                  const Icon(Icons.verified_rounded, size: 20, color: AppColors.primary),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doctor.specialtyName,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'License: ${doctor.licenseNumber}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Stats Row
                Row(
                  children: [
                    _InfoCard(
                      title: 'Experience',
                      value: '${doctor.experienceYears}y',
                      icon: Icons.work_outline_rounded,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(width: 10),
                    _InfoCard(
                      title: 'Rating',
                      value: '${doctor.rating.toStringAsFixed(1)} ★',
                      icon: Icons.star_outline_rounded,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(width: 10),
                    _InfoCard(
                      title: 'Consultation Fee',
                      value: '\$${doctor.consultationFee.toStringAsFixed(0)}',
                      icon: Icons.payments_outlined,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // About section
                Text(
                  'About Specialist',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    doctor.bio,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.6,
                      color: textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Weekly Availability Schedule Preview
                Text(
                  'Consultation Hours',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _ScheduleRow(
                        day: 'Monday',
                        windows: doctor.weeklyAvailability['monday'],
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      Divider(height: 16, thickness: 1, color: borderColor),
                      _ScheduleRow(
                        day: 'Tuesday',
                        windows: doctor.weeklyAvailability['tuesday'],
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      Divider(height: 16, thickness: 1, color: borderColor),
                      _ScheduleRow(
                        day: 'Wednesday',
                        windows: doctor.weeklyAvailability['wednesday'],
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      Divider(height: 16, thickness: 1, color: borderColor),
                      _ScheduleRow(
                        day: 'Thursday',
                        windows: doctor.weeklyAvailability['thursday'],
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      Divider(height: 16, thickness: 1, color: borderColor),
                      _ScheduleRow(
                        day: 'Friday',
                        windows: doctor.weeklyAvailability['friday'],
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Bottom CTA
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/patient/book/${doctor.id}'),
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text(
                      'Book Consultation',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final String day;
  final dynamic windows;
  final Color textPrimary;
  final Color textSecondary;

  const _ScheduleRow({
    required this.day,
    required this.windows,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final hasSlots = windows != null && windows.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        Text(
          hasSlots ? '09:00 AM – 05:00 PM' : 'Unavailable',
          style: TextStyle(
            fontSize: 12,
            color: hasSlots ? textSecondary : textSecondary.withOpacity(0.5),
            fontWeight: hasSlots ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
