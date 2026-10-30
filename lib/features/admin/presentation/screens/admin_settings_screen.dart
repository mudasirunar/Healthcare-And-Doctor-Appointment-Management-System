import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../domain/entities/admin_analytics_model.dart';

class AdminSettingsScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final stats = analyticsAsync.valueOrNull;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 118),
      children: [
        // 1. Administrator Profile Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.mail_outline_rounded, size: 14, color: textSecondary),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                user?.email ?? 'admin@gmail.com',
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium.copyWith(color: textSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLightOf(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Administrator',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: AppColors.borderOf(context)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MiniStatColumn(
                    label: 'Doctors',
                    value: '${stats?.verifiedDoctors ?? 18}',
                  ),
                  _MiniStatColumn(
                    label: 'Specialties',
                    value: '${stats?.totalSpecialties ?? 6}',
                  ),
                  _MiniStatColumn(
                    label: 'Bookings',
                    value: '${stats?.totalAppointments ?? 0}',
                  ),
                  _MiniStatColumn(
                    label: 'Pending',
                    value: '${stats?.pendingVerifications ?? 0}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Persistent Theme Selector (System / Light / Dark)
        const ThemeModeSelectorCard(),
        const SizedBox(height: 20),

        // 3. Sign Out Action
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: const Text('Sign Out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}

class _MiniStatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.headline.copyWith(
            fontSize: 18,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}

