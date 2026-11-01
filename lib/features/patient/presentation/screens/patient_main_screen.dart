import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import 'patient_home_screen.dart';
import 'patient_appointments_screen.dart';
import 'patient_prescriptions_screen.dart';
import 'patient_settings_screen.dart';

class PatientMainScreen extends ConsumerStatefulWidget {
  const PatientMainScreen({super.key});

  @override
  ConsumerState<PatientMainScreen> createState() => _PatientMainScreenState();
}

class _PatientMainScreenState extends ConsumerState<PatientMainScreen> {
  final ScrollController _homeScrollController = ScrollController();
  final ScrollController _appointmentsScrollController = ScrollController();
  final ScrollController _prescriptionsScrollController = ScrollController();
  final ScrollController _settingsScrollController = ScrollController();

  late final List<ScrollController> _scrollControllers;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _scrollControllers = [
      _homeScrollController,
      _appointmentsScrollController,
      _prescriptionsScrollController,
      _settingsScrollController,
    ];
    _pages = [
      PatientHomeScreen(scrollController: _homeScrollController),
      PatientAppointmentsScreen(scrollController: _appointmentsScrollController),
      PatientPrescriptionsScreen(scrollController: _prescriptionsScrollController),
      PatientSettingsScreen(
        scrollController: _settingsScrollController,
        onSignOut: _handleSignOut,
      ),
    ];
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    _appointmentsScrollController.dispose();
    _prescriptionsScrollController.dispose();
    _settingsScrollController.dispose();
    super.dispose();
  }

  void _handleSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.logout_rounded,
        tone: AppDialogTone.destructive,
        title: 'Sign Out',
        message: 'Are you sure you want to sign out of your patient account?',
        cancelLabel: 'Cancel',
        confirmLabel: 'Sign Out',
        confirmIsDestructive: true,
        onConfirm: () async {
          Navigator.pop(ctx);
          await appSignOut(ref);
          if (mounted) {
            context.go('/');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(patientSelectedTabProvider);
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final upcomingCount = appointmentsAsync.value
            ?.where((a) =>
                a.status == AppointmentStatus.confirmed ||
                a.status == AppointmentStatus.requested ||
                a.status == AppointmentStatus.inProgress)
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      extendBody: true,
      appBar: _buildContextualAppBar(context, tabIndex: currentIndex),
      body: SafeArea(
        top: currentIndex == 0, // Enforce status bar safe area protection for Discover tab
        bottom: false,
        child: IndexedStack(
          index: currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: currentIndex,
        onTap: (idx) => ref.read(patientSelectedTabProvider.notifier).state = idx,
        scrollControllers: _scrollControllers,
        items: [
          const AppNavItem(
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore_rounded,
            label: 'Discover',
          ),
          AppNavItem(
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today_rounded,
            label: 'Appointments',
            badgeCount: upcomingCount,
          ),
          const AppNavItem(
            icon: Icons.medication_outlined,
            activeIcon: Icons.medication_rounded,
            label: 'Prescriptions',
          ),
          const AppNavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget? _buildContextualAppBar(BuildContext context, {required int tabIndex}) {
    if (tabIndex == 0) {
      return null; // PatientHomeScreen renders its own top greetings header safely inside SafeArea
    }

    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);

    final (String title, String subtitle) = switch (tabIndex) {
      1 => ('My Consultations', 'Scheduled appointments & history'),
      2 => ('Medical Prescriptions', 'Prescriptions issued by your specialists'),
      3 => ('Account & Settings', 'Clinical profile, preferences & security'),
      _ => ('Patient Portal', 'Health & Appointments'),
    };

    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(bottom: BorderSide(color: borderColor, width: 1)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                          fontSize: 18,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
