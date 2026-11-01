import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import 'booking_screen.dart';
import 'doctor_details_screen.dart';
import 'patient_doctors_screen.dart';
import 'patient_prescriptions_screen.dart';
import 'patient_specialties_screen.dart';
import 'patient_specialty_doctors_screen.dart';

class PatientCareInsightsScreen extends ConsumerWidget {
  const PatientCareInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final doctorsAsync = ref.watch(verifiedDoctorsStreamProvider);
    final specialtiesAsync = ref.watch(specialtiesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Care Insights & Analytics'),
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
      ),
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (err, _) => ErrorStateView(
          message: 'Unable to load care history: $err',
          onRetry: () => ref.invalidate(userAppointmentsProvider),
        ),
        data: (allAppointments) {
          final allDoctors = doctorsAsync.valueOrNull ?? [];
          final allSpecialties = specialtiesAsync.valueOrNull ?? [];

          final completed = allAppointments
              .where((a) => a.status == AppointmentStatus.completed)
              .toList();
          final upcoming = allAppointments
              .where((a) =>
                  a.status == AppointmentStatus.confirmed ||
                  a.status == AppointmentStatus.requested ||
                  a.status == AppointmentStatus.inProgress)
              .toList();
          final cancelled = allAppointments
              .where((a) => a.status == AppointmentStatus.cancelled)
              .toList();

          // Calculate doctor visit counts and spending
          final Map<String, int> doctorVisitCounts = {};
          final Map<String, String> doctorNames = {};
          final Map<String, int> specialtyVisitCounts = {};
          double totalSpent = 0.0;

          for (final a in completed) {
            final matchedDoc = allDoctors.where((d) => d.id == a.doctorId).firstOrNull;
            final fee = matchedDoc?.consultationFee ?? 50.0;
            totalSpent += fee;

            if (a.doctorId.isNotEmpty) {
              doctorVisitCounts[a.doctorId] = (doctorVisitCounts[a.doctorId] ?? 0) + 1;
              if (a.doctorName.isNotEmpty) {
                doctorNames[a.doctorId] = a.doctorName;
              }
            }
            final spec = a.doctorSpecialty.isNotEmpty
                ? a.doctorSpecialty
                : matchedDoc?.specialtyName;
            if (spec != null && spec.isNotEmpty) {
              specialtyVisitCounts[spec] = (specialtyVisitCounts[spec] ?? 0) + 1;
            }
          }

          // Top Most Visited Doctor
          String? topDoctorId;
          int topDoctorVisits = 0;
          doctorVisitCounts.forEach((id, count) {
            if (count > topDoctorVisits) {
              topDoctorVisits = count;
              topDoctorId = id;
            }
          });

          final topDoctorModel = topDoctorId != null
              ? allDoctors.where((d) => d.id == topDoctorId).firstOrNull
              : null;
          final topDoctorName = topDoctorModel?.doctorName ??
              (topDoctorId != null ? doctorNames[topDoctorId] : null);

          // Visited doctors list
          final visitedDoctorIds = doctorVisitCounts.keys.toSet();
          final visitedDoctors = allDoctors
              .where((d) => visitedDoctorIds.contains(d.id))
              .toList();

          final prescriptionsCount = completed
              .where((a) => a.prescriptionId != null || a.consultationNotes != null)
              .length;

          // Adherence Rate
          final totalResolved = completed.length + cancelled.length;
          final attendanceRate = totalResolved > 0
              ? ((completed.length / totalResolved) * 100).toStringAsFixed(0)
              : '100';

          return ListView(
            padding: const EdgeInsets.only(bottom: 60),
            children: [
              // -----------------------------------------------------------
              // 1. EXECUTIVE HEALTHCARE & SPENDING OVERVIEW (FLAT METRICS)
              // -----------------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Health Overview',
                      style: AppTypography.headline.copyWith(
                        fontSize: 18,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Consultation expenditure, care continuity, and clinical milestones',
                      style: AppTypography.caption.copyWith(color: textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2x2 Metric Tiles Grid (Flat bordered cards with theme integration)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _FlatMetricTile(
                          title: 'Total Care Spent',
                          value: '\$${totalSpent.toStringAsFixed(0)}',
                          subtitle: completed.isEmpty
                              ? 'No expenses yet'
                              : '${completed.length} consultation${completed.length == 1 ? '' : 's'}',
                          icon: Icons.account_balance_wallet_outlined,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(width: 12),
                        _FlatMetricTile(
                          title: 'Completed Visits',
                          value: '${completed.length}',
                          subtitle: '${upcoming.length} upcoming scheduled',
                          icon: Icons.check_circle_outline_rounded,
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
                        _FlatMetricTile(
                          title: 'Prescriptions',
                          value: '$prescriptionsCount',
                          subtitle: 'Digital Rx on record',
                          icon: Icons.medication_outlined,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(width: 12),
                        _FlatMetricTile(
                          title: 'Adherence Rate',
                          value: '$attendanceRate%',
                          subtitle: '${cancelled.length} cancelled',
                          icon: Icons.pie_chart_outline_rounded,
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
              const SizedBox(height: 22),
              Divider(height: 1, thickness: 1, color: borderColor),

              // -----------------------------------------------------------
              // 2. MOST VISITED SPECIALIST (FLAT ON SCREEN)
              // -----------------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'Most Visited Specialist',
                  style: AppTypography.headline.copyWith(
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
              ),
              if (topDoctorName != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              topDoctorName.isNotEmpty
                                  ? topDoctorName
                                      .replaceFirst(RegExp(r'^Dr\.\s*'), '')
                                      .characters
                                      .first
                                      .toUpperCase()
                                  : 'D',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  topDoctorName,
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  topDoctorModel?.specialtyName ?? 'Specialist',
                                  style: AppTypography.caption.copyWith(color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$topDoctorVisits visit${topDoctorVisits == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (topDoctorId != null) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DoctorDetailsScreen(doctorId: topDoctorId!),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: textPrimary,
                                  side: BorderSide(color: borderColor),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: const Text('Doctor Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BookingScreen(doctorId: topDoctorId!),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: const Text('Book Follow-up', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_search_outlined, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No primary specialist yet',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your most consulted doctors will automatically appear here.',
                              style: AppTypography.caption.copyWith(color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Divider(height: 1, thickness: 1, color: borderColor),

              // -----------------------------------------------------------
              // 3. DEPARTMENT BREAKDOWN (FLAT ROWS WITH PROGRESS BARS)
              // -----------------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Department Breakdown',
                      style: AppTypography.headline.copyWith(
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '${specialtyVisitCounts.length} Departments',
                      style: AppTypography.caption.copyWith(color: textSecondary),
                    ),
                  ],
                ),
              ),
              if (specialtyVisitCounts.isNotEmpty) ...[
                ...specialtyVisitCounts.entries.map((entry) {
                  final pct = completed.isNotEmpty
                      ? entry.value / completed.length
                      : 0.0;

                  final matchedSpec = allSpecialties.where(
                    (s) => s.name.toLowerCase() == entry.key.toLowerCase(),
                  ).firstOrNull;

                  return InkWell(
                    onTap: matchedSpec != null
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PatientSpecialtyDoctorsScreen(specialty: matchedSpec),
                              ),
                            );
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    entry.key,
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                  if (matchedSpec != null) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_outward_rounded,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${entry.value} visit${entry.value == 1 ? '' : 's'} (${(pct * 100).toStringAsFixed(0)}%)',
                                style: AppTypography.caption.copyWith(color: textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 5,
                              backgroundColor: borderColor,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Text(
                    'No department consultations recorded yet.',
                    style: AppTypography.bodyMedium.copyWith(color: textSecondary),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: borderColor),

              // -----------------------------------------------------------
              // 4. YOUR CARE NETWORK (FLAT DOCTOR ROWS)
              // -----------------------------------------------------------
              if (visitedDoctors.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Care Network',
                        style: AppTypography.headline.copyWith(
                          fontSize: 16,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '${visitedDoctors.length} Specialists',
                        style: AppTypography.caption.copyWith(color: textSecondary),
                      ),
                    ],
                  ),
                ),
                ...visitedDoctors.map((doc) {
                  final visits = doctorVisitCounts[doc.id] ?? 1;
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DoctorDetailsScreen(doctorId: doc.id),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              doc.doctorName.replaceFirst(RegExp(r'^Dr\.\s*'), '').characters.first.toUpperCase(),
                              style: const TextStyle(
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
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${doc.specialtyName} • $visits consultation${visits == 1 ? '' : 's'}',
                                  style: AppTypography.caption.copyWith(color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 14),
                Divider(height: 1, thickness: 1, color: borderColor),
              ],

              // -----------------------------------------------------------
              // 5. CLINICAL HEALTH PRECAUTIONS (FLAT ADVISORIES WITH DIVIDERS)
              // -----------------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clinical Precautions & Care Tips',
                      style: AppTypography.headline.copyWith(
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Essential wellness guidelines & post-consultation care protocols',
                      style: AppTypography.caption.copyWith(color: textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              _buildFlatPrecautionItem(
                icon: Icons.water_drop_outlined,
                title: 'Hydration & Daily Wellness',
                description:
                    'Maintain adequate fluid intake (2.0–2.5L daily) to support renal filtration and recovery.',
                badge: 'Daily Wellness',
                color: AppColors.primary,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              Divider(height: 1, indent: 70, endIndent: 20, color: borderColor),

              _buildFlatPrecautionItem(
                icon: Icons.medication_liquid_outlined,
                title: 'Medication Adherence',
                description:
                    'Strictly complete prescribed antibiotic and therapy courses. Consult your specialist before modifying dosages.',
                badge: 'Clinical Protocol',
                color: AppColors.success,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              Divider(height: 1, indent: 70, endIndent: 20, color: borderColor),

              _buildFlatPrecautionItem(
                icon: Icons.videocam_outlined,
                title: 'Telehealth Video Readiness',
                description:
                    'Ensure a quiet, well-lit room and test your camera, microphone, and internet connection 5 minutes before scheduled calls.',
                badge: 'Consultation Check',
                color: AppColors.warning,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              Divider(height: 1, indent: 70, endIndent: 20, color: borderColor),

              _buildFlatPrecautionItem(
                icon: Icons.monitor_heart_outlined,
                title: 'Symptom Tracking & Follow-up',
                description:
                    'Record any shifts in symptoms or vital metrics between appointments so your doctor can review the timeline.',
                badge: 'Continuous Care',
                color: AppColors.secondary,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: borderColor),

              // -----------------------------------------------------------
              // 6. QUICK NAVIGATION HUB (FLAT SETTINGS-STYLE ROWS)
              // -----------------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                child: Text(
                  'Quick Navigation',
                  style: AppTypography.headline.copyWith(
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
              ),

              _FlatNavigationRow(
                icon: Icons.medication_outlined,
                title: 'Digital Prescriptions',
                subtitle: 'View issued medical prescriptions & notes',
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PatientPrescriptionsScreen(isStandalone: true),
                    ),
                  );
                },
              ),
              Divider(height: 1, indent: 70, endIndent: 20, color: borderColor),

              _FlatNavigationRow(
                icon: Icons.category_outlined,
                title: 'Medical Specialties Directory',
                subtitle: 'Browse all clinical departments and specialists',
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PatientSpecialtiesScreen(),
                    ),
                  );
                },
              ),
              Divider(height: 1, indent: 70, endIndent: 20, color: borderColor),

              _FlatNavigationRow(
                icon: Icons.person_search_rounded,
                title: 'All Specialists Directory',
                subtitle: 'Search, filter, and consult verified doctors',
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PatientDoctorsScreen(),
                    ),
                  );
                },
              ),
              Divider(height: 1, thickness: 1, color: borderColor),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFlatPrecautionItem({
    required IconData icon,
    required String title,
    required String description,
    required String badge,
    required Color color,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
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
                        title,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: textSecondary,
                    height: 1.35,
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

class _FlatMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _FlatMetricTile({
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(10),
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
                  style: AppTypography.caption.copyWith(
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, size: 17, color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTypography.headline.copyWith(
                fontSize: 20,
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

class _FlatNavigationRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _FlatNavigationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(color: textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
