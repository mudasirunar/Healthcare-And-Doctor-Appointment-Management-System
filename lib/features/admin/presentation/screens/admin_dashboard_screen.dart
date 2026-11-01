import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import 'admin_appointments_screen.dart';
import 'admin_directory_screen.dart';
import 'admin_doctor_detail_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_settings_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  late final List<ScrollController> _scrollControllers = List.generate(
    4,
    (_) => ScrollController(),
  );

  @override
  void initState() {
    super.initState();
    NotificationService.instance.onNotificationTap = _handleOsNotificationTap;
  }

  @override
  void dispose() {
    if (NotificationService.instance.onNotificationTap ==
        _handleOsNotificationTap) {
      NotificationService.instance.onNotificationTap = null;
    }
    for (final ctrl in _scrollControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _handleOsNotificationTap(String payload) {
    if (!mounted) return;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || !currentUser.isAdmin) return;

    // Format: "doctor_verify:<doctorId>:<notifId>"
    if (payload.startsWith('doctor_verify:')) {
      final parts = payload.split(':');
      final doctorId = parts.length > 1 ? parts[1] : '';
      final notifId =
          parts.length > 2 ? parts[2] : 'doc_verify_$doctorId';

      // Mark notification as read immediately when opened from phone tray
      ref.read(readNotificationsProvider.notifier).markAsRead(notifId);

      final allDocs = ref.read(allDoctorsAdminProvider).valueOrNull ?? [];
      final doc = allDocs.where((d) => d.id == doctorId).firstOrNull;

      if (doc != null && doc.verificationStatus == VerificationStatus.pending) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDoctorDetailScreen(doctorId: doc.id),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminNotificationsScreen(),
          ),
        );
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminNotificationsScreen(),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.logout_rounded,
        tone: AppDialogTone.destructive,
        title: 'Sign Out?',
        message: 'Are you sure you want to sign out of your account?',
        cancelLabel: 'Stay Signed In',
        onCancel: () => Navigator.pop(ctx, false),
        confirmLabel: 'Sign Out',
        confirmIsDestructive: true,
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );

    if (confirmed == true && mounted) {
      await appSignOut(ref);
      if (mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch pendingDoctorsProvider so real-time doctor registration listener stays active
    ref.watch(pendingDoctorsProvider);
    final tabIndex = ref.watch(adminSelectedTabProvider);
    final analyticsAsync = ref.watch(adminAnalyticsProvider);
    final specialtiesAsync = ref.watch(specialtiesProvider);
    final notifications = ref.watch(adminNotificationsProvider);
    final readIds = ref.watch(readNotificationsProvider);

    final unreadCount =
        notifications.where((n) => !readIds.contains(n.id)).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      extendBody: true,
      appBar: _buildContextualAppBar(
        context,
        tabIndex: tabIndex,
        unreadNotificationsCount: unreadCount,
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: tabIndex,
          children: [
            // Tab 0: Overview (Executive Hub + Specialties + Top Specialists)
            Material(
              type: MaterialType.transparency,
              child: AdminOverviewScreen(
                analyticsAsync: analyticsAsync,
                specialtiesAsync: specialtiesAsync,
                scrollController: _scrollControllers[0],
                onSwitchTab: (idx) =>
                    ref.read(adminSelectedTabProvider.notifier).state = idx,
              ),
            ),

            // Tab 1: Directory (Doctors & Patients with Smart Search)
            Material(
              type: MaterialType.transparency,
              child: AdminDirectoryScreen(
                scrollController: _scrollControllers[1],
              ),
            ),

            // Tab 2: Appointments & Prescriptions
            Material(
              type: MaterialType.transparency,
              child: AdminAppointmentsScreen(
                scrollController: _scrollControllers[2],
              ),
            ),

            // Tab 3: Profile & Settings
            Material(
              type: MaterialType.transparency,
              child: AdminSettingsScreen(
                analyticsAsync: analyticsAsync,
                onSignOut: _confirmSignOut,
                scrollController: _scrollControllers[3],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: tabIndex,
        scrollControllers: _scrollControllers,
        onTap: (idx) =>
            ref.read(adminSelectedTabProvider.notifier).state = idx,
        items: const [
          AppNavItem(
            label: 'Overview',
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
          ),
          AppNavItem(
            label: 'Directory',
            icon: Icons.people_outline_rounded,
            activeIcon: Icons.people_alt_rounded,
          ),
          AppNavItem(
            label: 'Appointments',
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_month_rounded,
          ),
          AppNavItem(
            label: 'Settings',
            icon: Icons.manage_accounts_outlined,
            activeIcon: Icons.manage_accounts_rounded,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildContextualAppBar(
    BuildContext context, {
    required int tabIndex,
    required int unreadNotificationsCount,
  }) {
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    final (String title, String subtitle, Widget? trailing) =
        switch (tabIndex) {
      0 => (
          'Admin Overview',
          'Specialists, Patients & Daily Operations',
          _NotificationBellButton(
            unreadCount: unreadNotificationsCount,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminNotificationsScreen(),
                ),
              );
            },
          ),
        ),
      1 => (
          'Medical Directory',
          'Specialists & Registered Patients',
          null,
        ),
      2 => (
          'Appointments & Records',
          'Consultations, Schedules & Prescriptions',
          null,
        ),
      _ => (
          'Profile & Settings',
          'Account Details & App Preferences',
          null,
        ),
    };

    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: AppTypography.headline.copyWith(
                            fontSize: 19,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.caption.copyWith(
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationBellButton({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariantOf(context),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              unreadCount > 0
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              size: 22,
              color: unreadCount > 0 ? AppColors.primary : textPrimary,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.surfaceOf(context),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
