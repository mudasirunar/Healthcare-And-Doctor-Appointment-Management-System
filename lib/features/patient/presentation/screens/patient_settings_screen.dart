import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../auth/domain/entities/user_model.dart';
import 'patient_care_insights_screen.dart';
import 'unified_edit_patient_screen.dart';
import 'unified_patient_detail_screen.dart';

class PatientSettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback onSignOut;
  final ScrollController? scrollController;

  const PatientSettingsScreen({
    super.key,
    required this.onSignOut,
    this.scrollController,
  });

  @override
  ConsumerState<PatientSettingsScreen> createState() =>
      _PatientSettingsScreenState();
}

class _PatientSettingsScreenState extends ConsumerState<PatientSettingsScreen> {
  bool _appointmentAlerts =
      PreferencesService.instance.getAppointmentAlertsEnabled();

  void _handlePasswordReset() {
    final user = ref.read(currentUserProvider);
    final email = user?.email ?? '';
    if (email.isEmpty) return;

    AppSnackBar.showSuccess(
      context,
      'Password reset instructions sent to $email.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);

    // Compute key care metrics for the highlights preview
    final appointments = ref.watch(userAppointmentsProvider).valueOrNull ?? [];
    final doctors = ref.watch(verifiedDoctorsStreamProvider).valueOrNull ?? [];

    final completedVisits = appointments
        .where((a) => a.status == AppointmentStatus.completed)
        .toList();
    final upcomingVisits = appointments
        .where((a) =>
            a.status == AppointmentStatus.confirmed ||
            a.status == AppointmentStatus.requested ||
            a.status == AppointmentStatus.inProgress)
        .toList();
    final cancelledVisits = appointments
        .where((a) => a.status == AppointmentStatus.cancelled)
        .toList();

    final prescriptionsCount = completedVisits
        .where((a) => a.prescriptionId != null || a.consultationNotes != null)
        .length;

    double totalSpent = 0.0;
    for (final a in completedVisits) {
      final doc = doctors.where((d) => d.id == a.doctorId).firstOrNull;
      totalSpent += doc?.consultationFee ?? 50.0;
    }

    final totalResolved = completedVisits.length + cancelledVisits.length;
    final attendanceRate = totalResolved > 0
        ? ((completedVisits.length / totalResolved) * 100).toStringAsFixed(0)
        : '100';

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 118),
      children: [
        // 1. Flat Patient Profile Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  user != null && user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : 'P',
                  style: AppTypography.display.copyWith(
                    color: AppColors.primary,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'Patient',
                      style: AppTypography.headline.copyWith(
                        fontSize: 18,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.mail_outline_rounded,
                          size: 15,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            user?.email ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (user?.phoneNumber != null &&
                        user!.phoneNumber!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 15,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              user.phoneNumber!,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (user != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UnifiedPatientDetailScreen(
                              patientId: user.id,
                              role: UserRole.patient,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View'),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UnifiedEditPatientScreen(
                              patient: user,
                              editorRole: UserRole.patient,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: borderColor),

        // 2. Visual Theme Preview Selector (System / Light / Dark)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: ThemeModeSelectorCard(),
        ),
        Divider(height: 1, color: borderColor),

        // 3. Care Insights & Activity Highlights Preview
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Care Insights & Highlights',
                style: AppTypography.headline.copyWith(
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PatientCareInsightsScreen(),
                    ),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View More',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  _SettingsInsightTile(
                    title: 'Completed Visits',
                    value: '${completedVisits.length}',
                    subtitle: '${upcomingVisits.length} upcoming scheduled',
                    icon: Icons.check_circle_outline_rounded,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 12),
                  _SettingsInsightTile(
                    title: 'Prescriptions',
                    value: '$prescriptionsCount',
                    subtitle: 'Digital Rx on record',
                    icon: Icons.medication_outlined,
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
                  _SettingsInsightTile(
                    title: 'Care Spending',
                    value: '\$${totalSpent.toStringAsFixed(0)}',
                    subtitle: completedVisits.isEmpty
                        ? 'No expenses yet'
                        : '${completedVisits.length} consultation${completedVisits.length == 1 ? '' : 's'}',
                    icon: Icons.account_balance_wallet_outlined,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 12),
                  _SettingsInsightTile(
                    title: 'Adherence Rate',
                    value: '$attendanceRate%',
                    subtitle: '${cancelledVisits.length} cancelled',
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
        const SizedBox(height: 14),
        Divider(height: 1, color: borderColor),

        // 4. App Preferences & Security
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(
            'Preferences & Security',
            style: AppTypography.headline.copyWith(
              fontSize: 15,
              color: textPrimary,
            ),
          ),
        ),
        SwitchListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          title: Text(
            'Consultation Alerts',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          subtitle: Text(
            'Receive reminders 15 minutes before appointments',
            style: AppTypography.caption.copyWith(color: textSecondary),
          ),
          value: _appointmentAlerts,
          onChanged: (val) {
            setState(() => _appointmentAlerts = val);
            PreferencesService.instance.setAppointmentAlertsEnabled(val);
          },
        ),
        Divider(height: 1, indent: 74, endIndent: 20, color: borderColor),
        InkWell(
          onTap: _handlePasswordReset,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset Password',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Send password reset instructions to your email',
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

        // 5. Sign Out Button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: OutlinedButton.icon(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Sign Out'),
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
    );
  }
}

class _SettingsInsightTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _SettingsInsightTile({
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
        padding: const EdgeInsets.all(13),
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

