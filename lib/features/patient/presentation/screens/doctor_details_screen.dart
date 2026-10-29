import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';

class DoctorDetailsScreen extends ConsumerWidget {
  final String doctorId;

  const DoctorDetailsScreen({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorRepo = ref.watch(doctorRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Doctor Profile'),
      ),
      body: FutureBuilder(
        future: doctorRepo.getDoctorById(doctorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final doctor = snapshot.data;
          if (doctor == null) {
            return const ErrorStateView(message: 'Doctor not found.');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          doctor.doctorName[0],
                          style: AppTypography.display.copyWith(color: AppColors.primary),
                        ),
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
                                    style: AppTypography.headline,
                                  ),
                                ),
                                if (doctor.isVerified)
                                  const Icon(Icons.verified_rounded, size: 20, color: AppColors.secondary),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doctor.specialtyName,
                              style: AppTypography.subtitle.copyWith(color: AppColors.primary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'License: ${doctor.licenseNumber}',
                              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
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
                      value: '${doctor.experienceYears} Years',
                      icon: Icons.work_outline_rounded,
                    ),
                    const SizedBox(width: 12),
                    _InfoCard(
                      title: 'Rating',
                      value: '${doctor.rating} ★',
                      icon: Icons.star_outline_rounded,
                    ),
                    const SizedBox(width: 12),
                    _InfoCard(
                      title: 'Fee',
                      value: '\$${doctor.consultationFee.toStringAsFixed(0)}',
                      icon: Icons.payments_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // About section
                const Text('About Doctor', style: AppTypography.headline),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    doctor.bio,
                    style: AppTypography.bodyLarge.copyWith(height: 1.6),
                  ),
                ),
                const SizedBox(height: 20),

                // Weekly Availability Schedule Preview
                const Text('Consultation Hours', style: AppTypography.headline),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _ScheduleRow(day: 'Monday', windows: doctor.weeklyAvailability['monday']),
                      const Divider(height: 16, color: AppColors.border),
                      _ScheduleRow(day: 'Tuesday', windows: doctor.weeklyAvailability['tuesday']),
                      const Divider(height: 16, color: AppColors.border),
                      _ScheduleRow(day: 'Wednesday', windows: doctor.weeklyAvailability['wednesday']),
                      const Divider(height: 16, color: AppColors.border),
                      _ScheduleRow(day: 'Thursday', windows: doctor.weeklyAvailability['thursday']),
                      const Divider(height: 16, color: AppColors.border),
                      _ScheduleRow(day: 'Friday', windows: doctor.weeklyAvailability['friday']),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Bottom CTA
                ElevatedButton.icon(
                  onPressed: () => context.push('/patient/book/${doctor.id}'),
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Book Consultation'),
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

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(value, style: AppTypography.headline.copyWith(fontSize: 15)),
            const SizedBox(height: 2),
            Text(title, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final String day;
  final dynamic windows;

  const _ScheduleRow({required this.day, required this.windows});

  @override
  Widget build(BuildContext context) {
    final hasSlots = windows != null && windows.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(day, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        Text(
          hasSlots ? '09:00 AM – 05:00 PM' : 'Unavailable',
          style: AppTypography.caption.copyWith(
            color: hasSlots ? AppColors.textSecondary : AppColors.textMuted,
            fontWeight: hasSlots ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
