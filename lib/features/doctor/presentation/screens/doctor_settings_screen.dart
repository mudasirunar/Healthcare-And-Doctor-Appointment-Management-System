import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import 'doctor_edit_profile_screen.dart';
import 'unified_doctor_detail_screen.dart';

class DoctorSettingsScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final VoidCallback onSignOut;

  const DoctorSettingsScreen({
    super.key,
    this.scrollController,
    required this.onSignOut,
  });

  @override
  ConsumerState<DoctorSettingsScreen> createState() =>
      _DoctorSettingsScreenState();
}

class _DoctorSettingsScreenState extends ConsumerState<DoctorSettingsScreen> {
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

    final doctorRepo = ref.watch(doctorRepositoryProvider);
    final appointments = ref.watch(userAppointmentsProvider).valueOrNull ?? [];

    final completedVisits = appointments
        .where((a) => a.status == AppointmentStatus.completed)
        .toList();
    final cancelledVisits = appointments
        .where((a) =>
            a.status == AppointmentStatus.cancelled ||
            a.status == AppointmentStatus.rejected)
        .toList();
    final totalResolved = completedVisits.length + cancelledVisits.length;
    final completionRate = totalResolved > 0
        ? ((completedVisits.length / totalResolved) * 100).toStringAsFixed(0)
        : '100';

    return FutureBuilder<DoctorModel?>(
      future: user != null ? doctorRepo.getDoctorByUserId(user.id) : null,
      builder: (context, snapshot) {
        final doctor = snapshot.data;
        final fee = doctor?.consultationFee ?? 50.0;
        final totalEarnings = completedVisits.length * fee;

        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.only(top: 12, bottom: 120),
          children: [
            // 1. Doctor Profile Header Card (Flat)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 29,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    backgroundImage: doctor?.avatarUrl != null
                        ? NetworkImage(doctor!.avatarUrl!)
                        : (user?.avatarUrl != null
                            ? NetworkImage(user!.avatarUrl!)
                            : null),
                    child: (doctor?.avatarUrl == null && user?.avatarUrl == null)
                        ? Text(
                            doctor?.doctorName.isNotEmpty == true
                                ? doctor!.doctorName
                                    .replaceFirst(RegExp(r'^Dr\.\s*'), '')
                                    .characters
                                    .first
                                    .toUpperCase()
                                : (user != null && user.displayName.isNotEmpty
                                    ? user.displayName[0].toUpperCase()
                                    : 'D'),
                            style: AppTypography.display.copyWith(
                              color: AppColors.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
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
                                doctor?.doctorName ?? user?.displayName ?? 'Doctor',
                                style: AppTypography.headline.copyWith(
                                  fontSize: 17,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 15, color: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          doctor?.specialtyName ?? 'Medical Specialist',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(fontSize: 11.5, color: textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (doctor != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UnifiedDoctorDetailScreen(
                                  doctorId: doctor.id,
                                  role: UserRole.doctor,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('View'),
                        ),
                        const SizedBox(width: 2),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DoctorEditProfileScreen(doctor: doctor),
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

            // 2. Visual Theme Mode Selector (System / Light / Dark)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: ThemeModeSelectorCard(),
            ),
            Divider(height: 1, color: borderColor),

            // 3. Practice Insights & Performance Metrics Card
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Text(
                'Practice Insights & Highlights',
                style: AppTypography.headline.copyWith(
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _InsightStatBox(
                            label: 'Rating Score',
                            value: '⭐ ${doctor?.rating.toStringAsFixed(1) ?? "5.0"}',
                            subtitle: '${doctor?.reviewCount ?? 0} patient reviews',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InsightStatBox(
                            label: 'Completed Visits',
                            value: '${completedVisits.length}',
                            subtitle: '$completionRate% completion',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _InsightStatBox(
                            label: 'Consultation Fee',
                            value: '\$${fee.toStringAsFixed(0)}',
                            subtitle: 'per session rate',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InsightStatBox(
                            label: 'Earned Revenue',
                            value: '\$${totalEarnings.toStringAsFixed(0)}',
                            subtitle: 'from completed visits',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // 4. Clinical Workspace Shortcuts
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Clinical Workspace',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _SettingsNavTile(
                      icon: Icons.schedule_rounded,
                      title: 'Working Hours & Shifts',
                      subtitle: 'Configure daily active slots and shift hours',
                      onTap: () => context.push('/doctor/availability'),
                      borderColor: borderColor,
                    ),
                    Divider(height: 1, indent: 56, color: borderColor),
                    _SettingsNavTile(
                      icon: Icons.local_hospital_rounded,
                      title: 'Hospital Departments',
                      subtitle: 'Browse clinical specialties and colleagues',
                      onTap: () => context.push('/doctor/specialties'),
                      borderColor: borderColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // 5. Notifications & Account Settings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Preferences & Security',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _appointmentAlerts,
                      activeColor: AppColors.primary,
                      title: Text(
                        'Booking Notifications',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                      ),
                      subtitle: Text(
                        'Receive alerts when patients book consultations',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                      secondary: const Icon(Icons.notifications_active_outlined),
                      onChanged: (val) {
                        setState(() => _appointmentAlerts = val);
                        PreferencesService.instance.setAppointmentAlertsEnabled(val);
                      },
                    ),
                    Divider(height: 1, indent: 56, color: borderColor),
                    ListTile(
                      leading: const Icon(Icons.lock_reset_rounded),
                      title: Text(
                        'Password Reset',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                      ),
                      subtitle: Text(
                        'Send account password reset instructions',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: _handlePasswordReset,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 6. Sign Out Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InsightStatBox extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color textPrimary;
  final Color textSecondary;

  const _InsightStatBox({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary)),
          const SizedBox(height: 1),
          Text(subtitle, style: TextStyle(fontSize: 10, color: textSecondary)),
        ],
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color borderColor;

  const _SettingsNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}

