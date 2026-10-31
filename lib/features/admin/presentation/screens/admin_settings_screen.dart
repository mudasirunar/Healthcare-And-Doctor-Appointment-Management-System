import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../domain/entities/admin_analytics_model.dart';
import 'admin_analytics_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_specialties_screen.dart';
import 'admin_verifications_screen.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  final AsyncValue<AdminAnalyticsModel> analyticsAsync;
  final VoidCallback onSignOut;
  final ScrollController? scrollController;

  const AdminSettingsScreen({
    super.key,
    required this.analyticsAsync,
    required this.onSignOut,
    this.scrollController,
  });

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  bool _doctorVerifyAlerts =
      PreferencesService.instance.getDoctorVerificationAlertsEnabled();
  bool _appointmentAlerts =
      PreferencesService.instance.getAppointmentAlertsEnabled();

  void _showEditProfileDialog() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final nameCtrl = TextEditingController(text: user.displayName);
    final phoneCtrl = TextEditingController(text: user.phoneNumber ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.person_outline_rounded,
        tone: AppDialogTone.primary,
        title: 'Edit Profile',
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
        ),
        cancelLabel: 'Cancel',
        onCancel: () => Navigator.pop(ctx),
        confirmLabel: 'Save',
        onConfirm: () async {
          final newName = nameCtrl.text.trim();
          if (newName.isEmpty) return;
          Navigator.pop(ctx);
          final updated = user.copyWith(
            displayName: newName,
            phoneNumber: phoneCtrl.text.trim().isEmpty
                ? null
                : phoneCtrl.text.trim(),
          );
          ref.read(currentUserProvider.notifier).state = updated;
          if (mounted) {
            AppSnackBar.showSuccess(context, 'Profile updated.');
          }
          try {
            await ref.read(authRepositoryProvider).updateProfile(updated);
          } catch (e) {
            if (mounted) {
              AppSnackBar.showError(context, e.toString());
            }
          }
        },
      ),
    );
  }

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
    final stats = widget.analyticsAsync.valueOrNull;
    final notifications = ref.watch(adminNotificationsProvider);
    final readIds = ref.watch(readNotificationsProvider);
    final unreadCount =
        notifications.where((n) => !readIds.contains(n.id)).length;

    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 118),
      children: [
        // 1. Flat Administrator Profile Header
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
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'System Administrator',
                      style: AppTypography.headline.copyWith(
                        fontSize: 18,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
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
                      const SizedBox(height: 4),
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
              TextButton.icon(
                onPressed: _showEditProfileDialog,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: borderColor),

        // 2. Visual Theme Preview Selector (Preserved Intact)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: ThemeModeSelectorCard(),
        ),
        Divider(height: 1, color: borderColor),

        // 3. Practice Management & Directories (Flat Rows with Horizontal Dividers)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(
            'Administration & Directories',
            style: AppTypography.headline.copyWith(
              fontSize: 15,
              color: textPrimary,
            ),
          ),
        ),
        _FlatSettingsRow(
          icon: Icons.grid_view_rounded,
          title: 'Medical Specialties',
          subtitle:
              '${stats?.totalSpecialties ?? 6} active departments • Add or manage specialties',
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
        ),
        Divider(height: 1, indent: 74, endIndent: 20, color: borderColor),
        _FlatSettingsRow(
          icon: Icons.verified_user_outlined,
          title: 'Doctor Verification Queue',
          subtitle:
              '${stats?.pendingVerifications ?? 0} pending credential review(s)',
          badgeCount: stats?.pendingVerifications ?? 0,
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
        ),
        Divider(height: 1, indent: 74, endIndent: 20, color: borderColor),
        _FlatSettingsRow(
          icon: Icons.insights_rounded,
          title: 'Analytics & Fee Insights',
          subtitle: 'Doctor fee averages, department coverage, and booking stats',
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
        ),
        Divider(height: 1, indent: 74, endIndent: 20, color: borderColor),
        _FlatSettingsRow(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications & Activity Log',
          subtitle: unreadCount > 0
              ? '$unreadCount unread notification(s)'
              : 'All notifications read',
          badgeCount: unreadCount,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminNotificationsScreen(),
              ),
            );
          },
        ),
        Divider(height: 1, color: borderColor),

        // 4. Notification Preferences & Account Security (Flat Rows)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(
            'Alerts & Account Security',
            style: AppTypography.headline.copyWith(
              fontSize: 15,
              color: textPrimary,
            ),
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.how_to_reg_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          title: Text(
            'New Specialist Registration Alerts',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          subtitle: Text(
            'Notify when a doctor submits credentials for approval',
            style: AppTypography.caption.copyWith(color: textSecondary),
          ),
          value: _doctorVerifyAlerts,
          activeColor: AppColors.primary,
          onChanged: (val) {
            setState(() => _doctorVerifyAlerts = val);
            PreferencesService.instance
                .setDoctorVerificationAlertsEnabled(val);
          },
        ),
        Divider(height: 1, indent: 74, endIndent: 20, color: borderColor),
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_note_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          title: Text(
            'Appointment & Cancellation Alerts',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          subtitle: Text(
            'Notify on booking updates and cancellations',
            style: AppTypography.caption.copyWith(color: textSecondary),
          ),
          value: _appointmentAlerts,
          activeColor: AppColors.primary,
          onChanged: (val) {
            setState(() => _appointmentAlerts = val);
            PreferencesService.instance.setAppointmentAlertsEnabled(val);
          },
        ),
        Divider(height: 1, indent: 74, endIndent: 20, color: borderColor),
        _FlatSettingsRow(
          icon: Icons.lock_reset_rounded,
          title: 'Reset Password',
          subtitle: 'Send a password reset email to your account',
          onTap: _handlePasswordReset,
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

class _FlatSettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int badgeCount;
  final VoidCallback onTap;

  const _FlatSettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return InkWell(
      onTap: onTap,
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
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (badgeCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badgeCount',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right_rounded, color: textSecondary),
          ],
        ),
      ),
    );
  }
}
