import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../doctor/domain/entities/doctor_model.dart';

/// Comprehensive practice and clinical analytics screen for Physicians.
class DoctorPracticeInsightsScreen extends ConsumerWidget {
  const DoctorPracticeInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final isDark = AppColors.isDark(context);

    final currentUser = ref.watch(currentUserProvider);
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final doctorRepo = ref.watch(doctorRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Practice Insights & Analytics'),
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
      ),
      body: FutureBuilder<DoctorModel?>(
        future: currentUser != null
            ? doctorRepo.getDoctorByUserId(currentUser.id)
            : null,
        builder: (context, docSnap) {
          final doctor = docSnap.data;
          final fee = doctor?.consultationFee ?? 85.0;

          return appointmentsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            error: (err, _) => ErrorStateView(
              message: 'Unable to load clinical practice history: $err',
              onRetry: () => ref.invalidate(userAppointmentsProvider),
            ),
            data: (allAppointments) {
              final completed = allAppointments
                  .where((a) => a.status == AppointmentStatus.completed)
                  .toList();
              final upcoming = allAppointments
                  .where((a) =>
                      a.status == AppointmentStatus.confirmed ||
                      a.status == AppointmentStatus.requested ||
                      a.status == AppointmentStatus.inProgress)
                  .toList();
              final pending = allAppointments
                  .where((a) => a.status == AppointmentStatus.requested)
                  .toList();
              final cancelled = allAppointments
                  .where((a) =>
                      a.status == AppointmentStatus.cancelled ||
                      a.status == AppointmentStatus.rejected)
                  .toList();

              final double totalRevenue = completed.length * fee;
              final int uniquePatients =
                  completed.map((a) => a.patientId).toSet().length;
              final int prescriptionsCount = completed
                  .where((a) =>
                      (a.prescriptionId != null &&
                          a.prescriptionId!.isNotEmpty) ||
                      (a.consultationNotes != null &&
                          a.consultationNotes!.isNotEmpty))
                  .length;

              final totalResolved = completed.length + cancelled.length;
              final int completionRateInt = totalResolved > 0
                  ? ((completed.length / totalResolved) * 100).round()
                  : 100;

              // Weekly activity breakdown (Mon=0 to Sun=6)
              final List<int> weekdayCounts = List.filled(7, 0);
              for (final a in completed) {
                final dt = DateTime.tryParse(a.scheduledTimeUtc);
                if (dt != null) {
                  final dayIdx = (dt.weekday - 1) % 7;
                  weekdayCounts[dayIdx]++;
                }
              }
              final int maxDayCount =
                  math.max(1, weekdayCounts.reduce(math.max));

              // Top Clinical Visit Categories
              final Map<String, int> reasonCounts = {};
              for (final a in completed) {
                final reason = a.reasonForVisit.trim().isNotEmpty
                    ? a.reasonForVisit.trim()
                    : 'Routine Consultation';
                reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
              }
              if (reasonCounts.isEmpty) {
                reasonCounts['General Wellness & Checkup'] = 1;
              }
              final sortedReasons = reasonCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final topReasons = sortedReasons.take(4).toList();
              final totalReasonVisits = math.max(
                1,
                topReasons.fold<int>(0, (sum, e) => sum + e.value),
              );

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 60),
                children: [
                  // 1. PRACTICE EXECUTIVE OVERVIEW HEADER
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Practice Performance Overview',
                          style: AppTypography.headline.copyWith(
                            fontSize: 18,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Real-time revenue, consultation milestones, and clinical velocity',
                          style: AppTypography.caption.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. 2x2 FLAT METRIC TILES
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _DoctorMetricTile(
                              title: 'Earned Revenue',
                              value: '\$${totalRevenue.toStringAsFixed(0)}',
                              subtitle: completed.isEmpty
                                  ? 'No completed sessions'
                                  : '\$${fee.toStringAsFixed(0)} per consultation',
                              icon: Icons.account_balance_wallet_outlined,
                              surfaceColor: surfaceColor,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                            const SizedBox(width: 12),
                            _DoctorMetricTile(
                              title: 'Completion Rate',
                              value: '$completionRateInt%',
                              subtitle:
                                  '${completed.length} completed • ${upcoming.length} upcoming',
                              icon: Icons.task_alt_rounded,
                              surfaceColor: surfaceColor,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _DoctorMetricTile(
                              title: 'Patient Rating',
                              value:
                                  '⭐ ${doctor?.rating.toStringAsFixed(1) ?? "5.0"}',
                              subtitle:
                                  '${doctor?.reviewCount ?? 0} verified reviews',
                              icon: Icons.star_border_rounded,
                              surfaceColor: surfaceColor,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                            const SizedBox(width: 12),
                            _DoctorMetricTile(
                              title: 'Patients Treated',
                              value: '$uniquePatients',
                              subtitle:
                                  '$prescriptionsCount digital Rx issued',
                              icon: Icons.people_outline_rounded,
                              surfaceColor: surfaceColor,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(height: 1, thickness: 1, color: borderColor),

                  // 3. WEEKLY CONSULTATIONS DISTRIBUTION (BAR VISUALIZER)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Weekly Consultation Volume',
                              style: AppTypography.headline.copyWith(
                                fontSize: 16,
                                color: textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${completed.length} visits total',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Patient volume distribution across clinic days',
                          style: AppTypography.caption.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 130,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (int i = 0; i < 7; i++) ...[
                                  Expanded(
                                    child: _WeekdayBarItem(
                                      label: _dayAbbrev(i),
                                      count: weekdayCounts[i],
                                      fraction:
                                          weekdayCounts[i] / maxDayCount,
                                      isHighest: weekdayCounts[i] ==
                                              maxDayCount &&
                                          maxDayCount > 0,
                                      isDark: isDark,
                                    ),
                                  ),
                                  if (i < 6) const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Divider(height: 1, color: borderColor),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _SummaryStatPill(
                                label: 'Pending Requests',
                                value: '${pending.length}',
                                color: AppColors.warning,
                              ),
                              _SummaryStatPill(
                                label: 'Upcoming Consults',
                                value: '${upcoming.length}',
                                color: AppColors.primary,
                              ),
                              _SummaryStatPill(
                                label: 'Slot Window',
                                value:
                                    '${doctor?.slotDurationMinutes ?? 30}m',
                                color: AppColors.success,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(height: 1, thickness: 1, color: borderColor),

                  // 4. TOP CLINICAL CATEGORIES & REASONS
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clinical Consultation Focus',
                          style: AppTypography.headline.copyWith(
                            fontSize: 16,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Most frequent clinical reasons presented by patients',
                          style: AppTypography.caption.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < topReasons.length; i++) ...[
                            _ClinicalReasonRow(
                              reason: topReasons[i].key,
                              count: topReasons[i].value,
                              fraction:
                                  topReasons[i].value / totalReasonVisits,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                            if (i < topReasons.length - 1)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(height: 1),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(height: 1, thickness: 1, color: borderColor),

                  // 5. PRACTICE RECOMMENDATIONS & OPTIMIZATION
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                    child: Text(
                      'Practice Optimization Recommendations',
                      style: AppTypography.headline.copyWith(
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _PracticeRecommendationCard(
                          icon: Icons.schedule_rounded,
                          title: 'Optimal Availability Windows',
                          description:
                              'Patient demand peaks between 10:00 AM and 1:00 PM. Maintaining active slots during these hours ensures higher booking fulfillment.',
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(height: 12),
                        _PracticeRecommendationCard(
                          icon: Icons.flash_on_rounded,
                          title: 'Rapid Request Turnaround',
                          description:
                              'Consultation requests accepted within 30 minutes maintain a 98% patient attendance and reduce last-minute cancellations.',
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(height: 12),
                        _PracticeRecommendationCard(
                          icon: Icons.medical_services_outlined,
                          title: 'Digital Prescriptions & Follow-ups',
                          description:
                              'Issuing digital prescriptions immediately after consultation concludes automatically archives records in the patient\'s health timeline.',
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String _dayAbbrev(int index) {
    switch (index) {
      case 0:
        return 'Mon';
      case 1:
        return 'Tue';
      case 2:
        return 'Wed';
      case 3:
        return 'Thu';
      case 4:
        return 'Fri';
      case 5:
        return 'Sat';
      case 6:
        return 'Sun';
      default:
        return '';
    }
  }
}

class _DoctorMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _DoctorMetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                Icon(icon, size: 16, color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTypography.headline.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayBarItem extends StatelessWidget {
  final String label;
  final int count;
  final double fraction;
  final bool isHighest;
  final bool isDark;

  const _WeekdayBarItem({
    required this.label,
    required this.count,
    required this.fraction,
    required this.isHighest,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final double barHeight = math.max(6.0, fraction * 72.0);
    final Color barColor = isHighest
        ? AppColors.primary
        : (isDark
            ? AppColors.primary.withValues(alpha: 0.35)
            : AppColors.primary.withValues(alpha: 0.22));

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isHighest ? FontWeight.w800 : FontWeight.w600,
            color: isHighest
                ? AppColors.primary
                : AppColors.textSecondaryOf(context),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: barHeight,
          width: 18,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}

class _SummaryStatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryStatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}

class _ClinicalReasonRow extends StatelessWidget {
  final String reason;
  final int count;
  final double fraction;
  final Color textPrimary;
  final Color textSecondary;

  const _ClinicalReasonRow({
    required this.reason,
    required this.count,
    required this.fraction,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (fraction * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                reason,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count visit${count == 1 ? '' : 's'} ($percent%)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.05, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.primary.withValues(alpha: 0.10),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _PracticeRecommendationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _PracticeRecommendationCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
