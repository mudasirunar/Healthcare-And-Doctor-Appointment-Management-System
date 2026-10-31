import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../doctor/domain/entities/specialty_model.dart';
import '../../domain/entities/admin_analytics_model.dart';
import 'admin_analytics_screen.dart';
import 'admin_appointments_screen.dart';
import 'admin_directory_screen.dart';
import 'admin_doctor_detail_screen.dart';
import 'admin_specialties_screen.dart';
import 'admin_specialty_doctors_screen.dart';
import 'admin_verifications_screen.dart';

class AdminOverviewScreen extends ConsumerWidget {
  final AsyncValue<AdminAnalyticsModel> analyticsAsync;
  final AsyncValue<List<SpecialtyModel>> specialtiesAsync;
  final ScrollController? scrollController;
  final ValueChanged<int> onSwitchTab;

  const AdminOverviewScreen({
    super.key,
    required this.analyticsAsync,
    required this.specialtiesAsync,
    required this.onSwitchTab,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return analyticsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorStateView(message: e.toString()),
      data: (stats) {
        final specialties = specialtiesAsync.valueOrNull ?? [];
        final textPrimary = AppColors.textPrimaryOf(context);
        final textSecondary = AppColors.textSecondaryOf(context);
        final borderColor = AppColors.borderOf(context);

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 118),
          children: [
            // 1. Actionable Pending Verifications Banner (only shown if pending > 0)
            if (stats.pendingVerifications > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminVerificationsScreen(
                          isStandalone: true,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.warning,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${stats.pendingVerifications} Specialist Application(s) Pending',
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to review medical board licenses and credentials',
                                style: AppTypography.caption.copyWith(
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 2. Interactive 2x2 Summary Grid (tapping navigates to that directory/screen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _InteractiveSummaryTile(
                        title: 'Specialists',
                        value: '${stats.verifiedDoctors}',
                        subtitle: '${stats.totalSpecialties} departments',
                        icon: Icons.medical_services_rounded,
                        onTap: () {
                          ref
                              .read(adminDirectorySegmentProvider.notifier)
                              .state = AdminDirectorySegment.doctors;
                          ref
                              .read(adminSelectedSpecialtyProvider.notifier)
                              .state = null;
                          ref
                              .read(
                                adminDirectoryFilterTriggerProvider.notifier,
                              )
                              .state++;
                          onSwitchTab(1);
                        },
                      ),
                      const SizedBox(width: 12),
                      _InteractiveSummaryTile(
                        title: 'Patients',
                        value: '${stats.totalPatients}',
                        subtitle: 'Registered accounts',
                        icon: Icons.people_alt_rounded,
                        onTap: () {
                          ref
                              .read(adminDirectorySegmentProvider.notifier)
                              .state = AdminDirectorySegment.patients;
                          ref
                              .read(
                                adminDirectoryFilterTriggerProvider.notifier,
                              )
                              .state++;
                          onSwitchTab(1);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _InteractiveSummaryTile(
                        title: 'Appointments',
                        value: '${stats.totalAppointments}',
                        subtitle: '${stats.upcomingAppointments} ongoing',
                        icon: Icons.calendar_today_rounded,
                        onTap: () {
                          ref
                              .read(adminAppointmentFilterProvider.notifier)
                              .state = AdminAppointmentFilter.all;
                          ref
                              .read(
                                adminAppointmentFilterTriggerProvider.notifier,
                              )
                              .state++;
                          onSwitchTab(2);
                        },
                      ),
                      const SizedBox(width: 12),
                      _InteractiveSummaryTile(
                        title: 'Prescriptions',
                        value: '${stats.totalPrescriptions}',
                        subtitle: 'Digital records',
                        icon: Icons.description_outlined,
                        onTap: () {
                          ref
                              .read(adminAppointmentFilterProvider.notifier)
                              .state = AdminAppointmentFilter.prescriptions;
                          ref
                              .read(
                                adminAppointmentFilterTriggerProvider.notifier,
                              )
                              .state++;
                          onSwitchTab(2);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: borderColor),

            // 3. Dedicated Analytics & Benchmarks Entry Row (Flat)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAnalyticsScreen(
                      isStandalone: true,
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
                        Icons.insights_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Analytics & Fee Insights',
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Avg \$${stats.avgConsultationFee.toStringAsFixed(0)} fee • ${stats.avgExperienceYears.toStringAsFixed(1)} yrs avg exp • ${stats.avgDoctorRating.toStringAsFixed(2)} ★ rating',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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

            // 4. Medical Specialties Preview Section (with Green "+ Add" button & "See All")
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medical Specialties (${specialties.length})',
                          style: AppTypography.headline.copyWith(
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminSpecialtiesScreen(
                                  isStandalone: true,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'View & search all departments →',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GreenAddSpecialtyButton(
                    onTap: () => showAddSpecialtyDialog(context, ref),
                  ),
                ],
              ),
            ),
            ...specialties.take(4).map((spec) {
              final count = stats.doctorCountBySpecialtyId[spec.id] ??
                  spec.activeDoctorCount;
              return Column(
                children: [
                  InkWell(
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
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: spec.accentColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              spec.iconData,
                              color: spec.accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  spec.name,
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  spec.description,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: spec.accentColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$count ${count == 1 ? 'Doc' : 'Docs'}',
                              style: AppTypography.caption.copyWith(
                                color: spec.accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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

            // 5. Top-Rated Specialists (Flat Rows -> Clickable to AdminDoctorDetailScreen)
            if (stats.topDoctors.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Top-Rated Specialists',
                      style: AppTypography.headline.copyWith(
                        color: textPrimary,
                      ),
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
                        onSwitchTab(1);
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
              ),
              ...stats.topDoctors.map((doc) {
                return Column(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminDoctorDetailScreen(doctorId: doc.id),
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
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                doc.doctorName
                                    .replaceFirst('Dr. ', '')
                                    .characters
                                    .first
                                    .toUpperCase(),
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
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
                                    '${doc.specialtyName} • ${doc.experienceYears} yrs exp • \$${doc.consultationFee.toStringAsFixed(0)}',
                                    style: AppTypography.caption.copyWith(
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.10,
                                ),
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
                                    doc.rating.toStringAsFixed(1),
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
            ],
          ],
        );
      },
    );
  }
}

class _InteractiveSummaryTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _InteractiveSummaryTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
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
                  Text(
                    title,
                    style: AppTypography.caption.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(icon, size: 18, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: AppTypography.display.copyWith(
                  fontSize: 24,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
