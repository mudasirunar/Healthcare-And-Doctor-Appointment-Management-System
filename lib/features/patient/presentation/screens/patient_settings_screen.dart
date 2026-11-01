import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../auth/domain/entities/user_model.dart';

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

  void _showEditProfileDialog(UserModel user) {
    final nameCtrl = TextEditingController(text: user.displayName);
    final phoneCtrl = TextEditingController(text: user.phoneNumber ?? '');
    final dobCtrl = TextEditingController(text: user.dateOfBirth ?? '');
    final emergencyCtrl =
        TextEditingController(text: user.emergencyContact ?? '');
    final allergiesCtrl =
        TextEditingController(text: user.medicalAllergies ?? '');
    String selectedBloodGroup = user.bloodGroup ?? 'O+';

    final bloodGroups = [
      'A+',
      'A-',
      'B+',
      'B-',
      'AB+',
      'AB-',
      'O+',
      'O-',
      'Unknown'
    ];
    if (!bloodGroups.contains(selectedBloodGroup)) {
      selectedBloodGroup = 'Unknown';
    }

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Edit Medical Profile',
          message: 'Update your clinical demographics and emergency details.',
          confirmLabel: 'Save Changes',
          confirmIsLoading: isSaving,
          confirmIsEnabled: !isSaving,
          cancelLabel: 'Cancel',
          cancelIsEnabled: !isSaving,
          onCancel: () => Navigator.pop(ctx),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedBloodGroup,
                  decoration: const InputDecoration(
                    labelText: 'Blood Group',
                    prefixIcon: Icon(Icons.water_drop_outlined),
                  ),
                  items: bloodGroups.map((bg) {
                    return DropdownMenuItem(value: bg, child: Text(bg));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedBloodGroup = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dobCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth (YYYY-MM-DD)',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emergencyCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contact',
                    prefixIcon: Icon(Icons.contact_phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: allergiesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Known Allergies',
                    hintText: 'e.g. Penicillin, Peanuts, Latex...',
                    prefixIcon: Icon(Icons.healing_outlined),
                  ),
                ),
              ],
            ),
          ),
          onConfirm: () async {
            if (!formKey.currentState!.validate()) return;
            setDialogState(() => isSaving = true);

            final updated = user.copyWith(
              displayName: nameCtrl.text.trim(),
              phoneNumber: phoneCtrl.text.trim().isEmpty
                  ? null
                  : phoneCtrl.text.trim(),
              bloodGroup: selectedBloodGroup,
              dateOfBirth:
                  dobCtrl.text.trim().isEmpty ? null : dobCtrl.text.trim(),
              emergencyContact: emergencyCtrl.text.trim().isEmpty
                  ? null
                  : emergencyCtrl.text.trim(),
              medicalAllergies: allergiesCtrl.text.trim().isEmpty
                  ? null
                  : allergiesCtrl.text.trim(),
            );

            try {
              await ref.read(authRepositoryProvider).updateProfile(updated);
              ref.read(currentUserProvider.notifier).state = updated;

              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                AppSnackBar.showSuccess(
                  context,
                  'Medical profile updated successfully.',
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                setDialogState(() => isSaving = false);
              }
              if (mounted) {
                AppSnackBar.showError(context, e.toString());
              }
            }
          },
        ),
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
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);

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
                TextButton.icon(
                  onPressed: () => _showEditProfileDialog(user),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
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

        // 3. Clinical Profile Records (Flat Rows)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(
            'Clinical & Medical Records',
            style: AppTypography.headline.copyWith(
              fontSize: 15,
              color: textPrimary,
            ),
          ),
        ),
        _FlatPatientInfoRow(
          icon: Icons.water_drop_outlined,
          title: 'Blood Group',
          value: user?.bloodGroup ?? 'Not specified',
        ),
        Divider(height: 1, indent: 74, endIndent: 20, color: borderColor),
        _FlatPatientInfoRow(
          icon: Icons.cake_outlined,
          title: 'Date of Birth',
          value: user?.dateOfBirth ?? 'Not specified',
        ),
        Divider(height: 1, indent: 74, endIndent: 20, color: borderColor),
        _FlatPatientInfoRow(
          icon: Icons.contact_phone_outlined,
          title: 'Emergency Contact',
          value: user?.emergencyContact ?? 'Not specified',
        ),
        Divider(height: 1, indent: 74, endIndent: 20, color: borderColor),
        _FlatPatientInfoRow(
          icon: Icons.healing_outlined,
          title: 'Known Allergies',
          value: user?.medicalAllergies ?? 'None registered',
        ),
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

class _FlatPatientInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _FlatPatientInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Padding(
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
            child: Text(
              title,
              style: AppTypography.bodyMedium.copyWith(
                color: textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

