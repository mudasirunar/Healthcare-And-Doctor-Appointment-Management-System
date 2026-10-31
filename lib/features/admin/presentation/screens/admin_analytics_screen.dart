import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import '../../../doctor/domain/entities/specialty_model.dart';
import '../../domain/entities/admin_analytics_model.dart';
import 'admin_dashboard_screen.dart';
import 'admin_directory_screen.dart';
import 'admin_doctor_detail_screen.dart';
import 'admin_specialty_doctors_screen.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  final AsyncValue<AdminAnalyticsModel>? analyticsAsync;
  final AsyncValue<List<SpecialtyModel>>? specialtiesAsync;
  final ScrollController? scrollController;
  final bool isStandalone;

  const AdminAnalyticsScreen({
    super.key,
    this.analyticsAsync,
    this.specialtiesAsync,
    this.scrollController,
    this.isStandalone = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdminAnalyticsModel> statsVal =
        analyticsAsync ?? ref.watch(adminAnalyticsProvider);
    final AsyncValue<List<SpecialtyModel>> specsVal =
        specialtiesAsync ?? ref.watch(specialtiesProvider);

    final body = statsVal.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorStateView(message: e.toString()),
      data: (stats) {
        final specialties = specsVal.valueOrNull ?? [];
        final textPrimary = AppColors.textPrimaryOf(context);
        final textSecondary = AppColors.textSecondaryOf(context);
        final borderColor = AppColors.borderOf(context);

        return ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            isStandalone ? 40 : 118,
          ),
          children: [
            Text(
              'System Overview & Activity',
              style: AppTypography.headline.copyWith(color: textPrimary),
            ),
            const SizedBox(height: 12),

            // 1. 2x2 Metric Grid
            Row(
              children: [
                _MetricCard(
                  title: 'Verified Doctors',
                  value: '${stats.verifiedDoctors}',
                  subtitle: 'Across ${stats.totalSpecialties} specialties',
                  color: AppColors.primary,
                  icon: Icons.medical_services_rounded,
                ),
                const SizedBox(width: 12),
                _MetricCard(
                  title: 'Registered Patients',
                  value: '${stats.totalPatients}',
                  subtitle: stats.totalPatients == 0
                      ? 'Awaiting new signups'
                      : 'Active patient accounts',
                  color: AppColors.primary,
                  icon: Icons.people_alt_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MetricCard(
                  title: 'Total Bookings',
                  value: '${stats.totalAppointments}',
                  subtitle:
                      '${stats.upcomingAppointments} ongoing • ${stats.completedAppointments} done',
                  color: AppColors.primary,
                  icon: Icons.event_available_rounded,
                ),
                const SizedBox(width: 12),
                _MetricCard(
                  title: 'Cancellation Rate',
                  value:
                      '${stats.cancellationRatePercentage.toStringAsFixed(1)}%',
                  subtitle: stats.totalAppointments == 0
                      ? '0 cancelled bookings'
                      : '${stats.cancelledAppointments} cancelled',
                  color: AppColors.primary,
                  icon: Icons.analytics_outlined,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 2. Doctor Experience, Ratings & Fees (Flat Rows)
            Text(
              'Doctor Experience, Ratings & Fees',
              style: AppTypography.headline.copyWith(color: textPrimary),
            ),
            const SizedBox(height: 8),
            _BenchmarkItem(
              icon: Icons.payments_outlined,
              label: 'Average Consultation Fee',
              sublabel:
                  'Fee range across specialists: \$${stats.minConsultationFee.toStringAsFixed(0)} – \$${stats.maxConsultationFee.toStringAsFixed(0)}',
              value: '\$${stats.avgConsultationFee.toStringAsFixed(0)}',
            ),
            Divider(height: 1, color: borderColor),
            _BenchmarkItem(
              icon: Icons.workspace_premium_outlined,
              label: 'Average Clinical Experience',
              sublabel:
                  'Combined tenure across ${stats.verifiedDoctors} verified specialists',
              value: '${stats.avgExperienceYears.toStringAsFixed(1)} yrs',
            ),
            Divider(height: 1, color: borderColor),
            _BenchmarkItem(
              icon: Icons.star_rounded,
              label: 'Patient Satisfaction Rating',
              sublabel:
                  'Aggregated from ${stats.totalReviewsCount} verified patient reviews',
              value: '${stats.avgDoctorRating.toStringAsFixed(2)} ★',
            ),
            const SizedBox(height: 28),

            // 3. Department Coverage & Average Fees (Flat Rows)
            if (specialties.isNotEmpty) ...[
              Text(
                'Department Coverage & Avg Fees',
                style: AppTypography.headline.copyWith(color: textPrimary),
              ),
              const SizedBox(height: 10),
              ...specialties.map((spec) {
                final count = stats.doctorCountBySpecialtyId[spec.id] ?? 0;
                final avgSpecFee = stats.avgFeeBySpecialtyId[spec.id] ?? 0.0;
                final ratio = stats.verifiedDoctors > 0
                    ? (count / stats.verifiedDoctors).clamp(0.0, 1.0)
                    : 0.0;

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminSpecialtyDoctorsScreen(
                          specialty: spec,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              spec.iconData,
                              size: 18,
                              color: spec.accentColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                spec.name,
                                style: AppTypography.bodyLarge.copyWith(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (avgSpecFee > 0) ...[
                              Text(
                                'Avg \$${avgSpecFee.toStringAsFixed(0)} • ',
                                style: AppTypography.caption.copyWith(
                                  color: textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            Text(
                              '$count ${count == 1 ? 'Doc' : 'Docs'}',
                              style: AppTypography.caption.copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            backgroundColor:
                                AppColors.surfaceVariantOf(context),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              spec.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],

            // 4. Top-Rated Specialists (Flat Rows)
            if (stats.topDoctors.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Top-Rated Specialists',
                    style: AppTypography.headline.copyWith(color: textPrimary),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(adminDirectorySegmentProvider.notifier)
                          .state = AdminDirectorySegment.doctors;
                      ref
                          .read(adminSelectedSpecialtyProvider.notifier)
                          .state = null;
                      ref
                          .read(adminDirectoryFilterTriggerProvider.notifier)
                          .state++;
                      ref.read(adminSelectedTabProvider.notifier).state = 1;
                      if (isStandalone && Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      'See All',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...List.generate(stats.topDoctors.length, (index) {
                final doc = stats.topDoctors[index];
                final isLast = index == stats.topDoctors.length - 1;
                return Column(
                  children: [
                    _TopSpecialistRow(
                      rank: index + 1,
                      doctor: doc,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminDoctorDetailScreen(doctorId: doc.id),
                          ),
                        );
                      },
                    ),
                    if (!isLast) Divider(height: 1, color: borderColor),
                  ],
                );
              }),
            ],
          ],
        );
      },
    );

    if (!isStandalone) return body;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Analytics & Fee Insights'),
      ),
      body: body,
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: textSecondary),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: AppTypography.display.copyWith(
                fontSize: 26,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenchmarkItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sublabel;

  const _BenchmarkItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: AppTypography.caption.copyWith(
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: AppTypography.headline.copyWith(
                fontSize: 15,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSpecialistRow extends StatelessWidget {
  final int rank;
  final DoctorModel doctor;
  final VoidCallback onTap;

  const _TopSpecialistRow({
    required this.rank,
    required this.doctor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '#$rank',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.doctorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${doctor.specialtyName} • ${doctor.experienceYears} yrs exp • \$${doctor.consultationFee.toStringAsFixed(0)}',
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${doctor.rating.toStringAsFixed(1)} (${doctor.reviewCount})',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
