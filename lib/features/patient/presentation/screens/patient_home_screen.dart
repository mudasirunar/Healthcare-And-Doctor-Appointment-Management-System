import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import '../../../consultation/presentation/screens/appointment_chat_screen.dart';
import '../../../consultation/presentation/screens/video_consultation_screen.dart';
import 'booking_screen.dart';
import 'doctor_details_screen.dart';
import 'patient_care_insights_screen.dart';
import 'patient_doctors_screen.dart';
import 'patient_specialties_screen.dart';
import 'patient_specialty_doctors_screen.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const PatientHomeScreen({super.key, this.scrollController});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    final specialtiesAsync = ref.watch(specialtiesProvider);
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final allAppointments = appointmentsAsync.valueOrNull ?? [];

    final upcomingAppointments = allAppointments
        .where((a) =>
            a.status == AppointmentStatus.confirmed ||
            a.status == AppointmentStatus.requested ||
            a.status == AppointmentStatus.inProgress)
        .toList();

    final completedAppointments = allAppointments
        .where((a) => a.status == AppointmentStatus.completed)
        .toList();

    final visitedDoctorIds = completedAppointments
        .map((a) => a.doctorId)
        .where((id) => id.isNotEmpty)
        .toSet();

    final doctorsAsync = ref.watch(verifiedDoctorsStreamProvider);
    final allDoctors = doctorsAsync.valueOrNull ?? [];

    final visitedDoctors = allDoctors
        .where((d) => visitedDoctorIds.contains(d.id))
        .toList();

    final specialties = specialtiesAsync.valueOrNull ?? [];

    // Calculate doctor count per specialty
    final Map<String, int> doctorCountBySpecialtyId = {};
    for (final spec in specialties) {
      doctorCountBySpecialtyId[spec.id] =
          allDoctors.where((d) => d.specialtyId == spec.id).length;
    }

    // Top-rated specialists (top 4 doctors by rating & review count)
    final topRatedDoctors = List<DoctorModel>.from(allDoctors)
      ..sort((a, b) {
        final rCmp = b.rating.compareTo(a.rating);
        if (rCmp != 0) return rCmp;
        return b.reviewCount.compareTo(a.reviewCount);
      });
    final topSpecialistsPreview = topRatedDoctors.take(4).toList();

    // Calculate Personal Care Insights subtitle
    String insightSubtitle;
    if (completedAppointments.isNotEmpty) {
      final Map<String, int> docVisits = {};
      final Map<String, String> docNames = {};
      final Map<String, int> specVisits = {};

      for (final a in completedAppointments) {
        if (a.doctorId.isNotEmpty) {
          docVisits[a.doctorId] = (docVisits[a.doctorId] ?? 0) + 1;
          if (a.doctorName.isNotEmpty) {
            docNames[a.doctorId] = a.doctorName;
          }
        }
        final spec = a.doctorSpecialty.isNotEmpty
            ? a.doctorSpecialty
            : allDoctors.where((d) => d.id == a.doctorId).firstOrNull?.specialtyName;
        if (spec != null && spec.isNotEmpty) {
          specVisits[spec] = (specVisits[spec] ?? 0) + 1;
        }
      }

      String? topDocId;
      int topDocCount = 0;
      docVisits.forEach((id, count) {
        if (count > topDocCount) {
          topDocCount = count;
          topDocId = id;
        }
      });

      String? topSpec;
      int topSpecCount = 0;
      specVisits.forEach((spec, count) {
        if (count > topSpecCount) {
          topSpecCount = count;
          topSpec = spec;
        }
      });

      final topDocName = allDoctors.where((d) => d.id == topDocId).firstOrNull?.doctorName ??
          (topDocId != null ? docNames[topDocId] : null);

      if (topDocName != null) {
        final visitWord = topDocCount == 1 ? 'visit' : 'visits';
        if (topSpec != null) {
          final pct = ((topSpecCount / completedAppointments.length) * 100).round();
          insightSubtitle = 'Top Doctor: $topDocName ($topDocCount $visitWord) • Dept: $topSpec ($pct%)';
        } else {
          insightSubtitle = 'Most Visited Doctor: $topDocName ($topDocCount $visitWord)';
        }
      } else {
        insightSubtitle = '${completedAppointments.length} completed consultation${completedAppointments.length == 1 ? '' : 's'} on record';
      }
    } else if (upcomingAppointments.isNotEmpty) {
      final next = upcomingAppointments.first;
      insightSubtitle = 'Upcoming: Dr. ${next.doctorName.replaceFirst(RegExp(r'^Dr\.\s*'), '')} • ${DateTimeUtils.formatLocalDate(next.scheduledTimeUtc)}';
    } else {
      insightSubtitle = 'Tap to view health trends, visit history, and consultation stats';
    }

    void openCareInsights() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PatientCareInsightsScreen(),
        ),
      );
    }

    void openSpecialistsDirectory() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PatientDoctorsScreen(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // 1. Actionable Ongoing Consultation Ribbon (if any active appointment)
          if (upcomingAppointments.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: _buildActionableConsultationRibbon(
                  context,
                  upcomingAppointments.first,
                  isDark: isDark,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
            ),
          ],

          // 2. Personal Health Dashboard Overview (2x2 Flat Cards)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _DashboardMetricTile(
                        title: 'Upcoming',
                        value: '${upcomingAppointments.length}',
                        subtitle: 'Scheduled visits',
                        icon: Icons.calendar_month_outlined,
                        onTap: () {
                          ref.read(patientSelectedTabProvider.notifier).state = 1;
                        },
                      ),
                      const SizedBox(width: 12),
                      _DashboardMetricTile(
                        title: 'Completed',
                        value: '${completedAppointments.length}',
                        subtitle: 'Past visits',
                        icon: Icons.check_circle_outline_rounded,
                        onTap: () {
                          ref.read(patientSelectedTabProvider.notifier).state = 1;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _DashboardMetricTile(
                        title: 'Prescriptions',
                        value: '${completedAppointments.where((a) => a.consultationNotes != null || a.prescriptionId != null).length}',
                        subtitle: 'Active records',
                        icon: Icons.medication_outlined,
                        onTap: () {
                          ref.read(patientSelectedTabProvider.notifier).state = 2;
                        },
                      ),
                      const SizedBox(width: 12),
                      _DashboardMetricTile(
                        title: 'Specialists Visited',
                        value: '${visitedDoctorIds.length}',
                        subtitle: 'Care network',
                        icon: Icons.people_outline_rounded,
                        onTap: openSpecialistsDirectory,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Flat Quick Action Dock
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(
                children: [
                  _QuickActionButton(
                    icon: Icons.person_search_rounded,
                    label: 'Find Doctor',
                    onTap: openSpecialistsDirectory,
                  ),
                  const SizedBox(width: 10),
                  _QuickActionButton(
                    icon: Icons.category_outlined,
                    label: 'Specialties',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PatientSpecialtiesScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _QuickActionButton(
                    icon: Icons.calendar_today_outlined,
                    label: 'Appointments',
                    onTap: () {
                      ref.read(patientSelectedTabProvider.notifier).state = 1;
                    },
                  ),
                  const SizedBox(width: 10),
                  _QuickActionButton(
                    icon: Icons.receipt_long_outlined,
                    label: 'Prescriptions',
                    onTap: () {
                      ref.read(patientSelectedTabProvider.notifier).state = 2;
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Flat Personal Care Insights Row (Matching Admin side)
          SliverToBoxAdapter(
            child: Column(
              children: [
                Divider(height: 1, color: borderColor),
                InkWell(
                  onTap: openCareInsights,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
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
                                'Personal Care Insights',
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                insightSubtitle,
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
                const SizedBox(height: 16),
              ],
            ),
          ),

          // 5. Medical Specialties Showcase (Flat with dynamic icons)
          if (specialties.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medical Specialties',
                          style: AppTypography.headline.copyWith(
                            fontSize: 17,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Clinical departments & verified specialists',
                          style: AppTypography.caption.copyWith(color: textSecondary),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PatientSpecialtiesScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: const Text('See All'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 108,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: specialties.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (ctx, idx) {
                    final spec = specialties[idx];
                    final docCount = doctorCountBySpecialtyId[spec.id] ?? 0;

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PatientSpecialtyDoctorsScreen(specialty: spec),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                spec.iconData,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 7),
                            SizedBox(
                              width: 84,
                              child: Text(
                                spec.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$docCount Doc${docCount == 1 ? '' : 's'}',
                              textAlign: TextAlign.center,
                              style: AppTypography.caption.copyWith(
                                fontSize: 10.5,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  Divider(height: 1, color: borderColor),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],

          // 6. Top-Rated Specialists Section (Flat rows directly on screen)
          if (topSpecialistsPreview.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top-Rated Specialists',
                          style: AppTypography.headline.copyWith(
                            fontSize: 17,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Highest patient reviews & recommendations',
                          style: AppTypography.caption.copyWith(color: textSecondary),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: openSpecialistsDirectory,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) {
                  final doc = topSpecialistsPreview[idx];
                  return Column(
                    children: [
                      _FlatPatientDoctorRow(
                        doctor: doc,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DoctorDetailsScreen(doctorId: doc.id),
                            ),
                          );
                        },
                        onBook: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingScreen(doctorId: doc.id),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, indent: 76, endIndent: 20, color: borderColor),
                    ],
                  );
                },
                childCount: topSpecialistsPreview.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],

          // 7. Previously Visited Doctors Section (if any completed appointments)
          if (visitedDoctors.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Past Consultations',
                      style: AppTypography.headline.copyWith(
                        fontSize: 17,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Doctors you have consulted previously for easy follow-up',
                      style: AppTypography.caption.copyWith(color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) {
                  final doc = visitedDoctors[idx];
                  return Column(
                    children: [
                      _FlatPatientDoctorRow(
                        doctor: doc,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DoctorDetailsScreen(doctorId: doc.id),
                            ),
                          );
                        },
                        onBook: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingScreen(doctorId: doc.id),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, indent: 76, endIndent: 20, color: borderColor),
                    ],
                  );
                },
                childCount: visitedDoctors.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],

          // Bottom padding for the floating navigation bar
          const SliverToBoxAdapter(
            child: SizedBox(height: 118),
          ),
        ],
      ),
    );
  }

  Widget _buildActionableConsultationRibbon(
    BuildContext context,
    AppointmentModel appointment, {
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final bool canJoinCall = appointment.status == AppointmentStatus.inProgress ||
        appointment.status == AppointmentStatus.confirmed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Upcoming: ${appointment.doctorName}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateTimeUtils.formatRelativeTime(appointment.scheduledTimeUtc)} • ${appointment.doctorSpecialty}',
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canJoinCall) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoConsultationScreen(
                      appointmentId: appointment.id,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.videocam_rounded, size: 15),
              label: const Text('Join Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),
          ],
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentChatScreen(
                    appointmentId: appointment.id,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            color: AppColors.primary,
            tooltip: 'Chat with Doctor',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardMetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  Icon(icon, size: 18, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlatPatientDoctorRow extends StatelessWidget {
  final DoctorModel doctor;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;
  final VoidCallback onBook;

  const _FlatPatientDoctorRow({
    required this.doctor,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          doctor.doctorName,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 14, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doctor.specialtyName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${doctor.experienceYears}y exp • \$${doctor.consultationFee.toStringAsFixed(0)} fee',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text(
                        doctor.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        ' (${doctor.reviewCount})',
                        style: TextStyle(fontSize: 10.5, color: textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Book',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
