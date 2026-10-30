import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import '../../../doctor/domain/entities/specialty_model.dart';
import 'admin_analytics_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_specialties_screen.dart';
import 'admin_verifications_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _tabIndex = 0;
  late final List<ScrollController> _scrollControllers = List.generate(
    4,
    (_) => ScrollController(),
  );

  @override
  void dispose() {
    for (final ctrl in _scrollControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _handleApproveDoctor(DoctorModel doc) async {
    final docRepo = ref.read(doctorRepositoryProvider);
    await docRepo.updateVerificationStatus(doc.id, VerificationStatus.approved);
    ref.invalidate(filteredDoctorsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${doc.doctorName} approved and published to directory.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleRejectDoctor(DoctorModel doc) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Decline Credentials',
          style: AppTypography.headline.copyWith(color: AppColors.textPrimaryOf(ctx)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provide a reason for declining ${doc.doctorName} (e.g. unverified medical board license):',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryOf(ctx)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'Enter verification notes...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              final docRepo = ref.read(doctorRepositoryProvider);
              await docRepo.updateVerificationStatus(
                doc.id,
                VerificationStatus.rejected,
                reason,
              );
              ref.invalidate(filteredDoctorsProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(120, 42),
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  void _showAddSpecialtyDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'New Medical Specialty',
          style: AppTypography.headline.copyWith(color: AppColors.textPrimaryOf(ctx)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Department Name',
                hintText: 'e.g. Ophthalmology',
                prefixIcon: Icon(Icons.medical_information_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Clinical Scope & Description',
                hintText: 'e.g. Eye care, vision correction & retinal surgery',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final newSpec = SpecialtyModel(
                id: 'spec_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
                name: name,
                description: descCtrl.text.trim().isEmpty
                    ? 'Specialized clinical care and consultations'
                    : descCtrl.text.trim(),
                iconName: name.toLowerCase(),
                activeDoctorCount: 0,
              );
              await ref.read(doctorRepositoryProvider).saveSpecialty(newSpec);
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(110, 42)),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Sign Out of Admin Desk?',
          style: AppTypography.headline.copyWith(color: AppColors.textPrimaryOf(ctx)),
        ),
        content: Text(
          'You will be returned to the login screen. Active platform locks and security rules remain enforced.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryOf(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay Signed In'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(120, 42),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authRepositoryProvider).signOut();
      ref.read(currentUserProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingDoctorsProvider);
    final analyticsAsync = ref.watch(adminAnalyticsProvider);
    final specialtiesAsync = ref.watch(specialtiesProvider);

    final pendingCount = pendingAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      extendBody: true,
      appBar: _buildContextualAppBar(
        context,
        pendingCount: pendingCount,
        specialtyCount: specialtiesAsync.valueOrNull?.length ?? 0,
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tabIndex,
          children: [
            // Tab 0: Verification Desk
            AdminVerificationsScreen(
              pendingAsync: pendingAsync,
              analyticsAsync: analyticsAsync,
              onApprove: _handleApproveDoctor,
              onReject: _handleRejectDoctor,
              scrollController: _scrollControllers[0],
            ),

            // Tab 1: Live Cloud Analytics
            AdminAnalyticsScreen(
              analyticsAsync: analyticsAsync,
              specialtiesAsync: specialtiesAsync,
              scrollController: _scrollControllers[1],
            ),

            // Tab 2: Medical Specialties Catalog
            AdminSpecialtiesScreen(
              specialtiesAsync: specialtiesAsync,
              analyticsAsync: analyticsAsync,
              onAddSpecialty: _showAddSpecialtyDialog,
              scrollController: _scrollControllers[2],
            ),

            // Tab 3: Admin Profile & Settings
            AdminSettingsScreen(
              analyticsAsync: analyticsAsync,
              onSignOut: _confirmSignOut,
              scrollController: _scrollControllers[3],
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _tabIndex,
        scrollControllers: _scrollControllers,
        onTap: (idx) => setState(() => _tabIndex = idx),
        items: [
          AppNavItem(
            label: 'Verifications',
            icon: Icons.verified_user_outlined,
            activeIcon: Icons.verified_user_rounded,
            badgeCount: pendingCount,
          ),
          const AppNavItem(
            label: 'Analytics',
            icon: Icons.insights_outlined,
            activeIcon: Icons.insights_rounded,
          ),
          const AppNavItem(
            label: 'Specialties',
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view_rounded,
          ),
          const AppNavItem(
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
    required int pendingCount,
    required int specialtyCount,
  }) {
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    final (String title, String subtitle, Widget? trailing) = switch (_tabIndex) {
      0 => (
          'Doctor Verifications',
          'Credential & Medical Board Review Queue',
          _HeaderBadge(
            icon: pendingCount > 0 ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded,
            label: pendingCount > 0 ? '$pendingCount Pending' : 'Queue Clear',
            color: pendingCount > 0 ? AppColors.warning : AppColors.success,
            bgColor: pendingCount > 0
                ? AppColors.warningLightOf(context)
                : AppColors.successLightOf(context),
          ),
        ),
      1 => (
          'Platform Analytics',
          'Appointments, Specialists & Patient Insights',
          null,
        ),
      2 => (
          'Medical Specialties',
          '$specialtyCount Active Clinical Departments',
          GestureDetector(
            onTap: _showAddSpecialtyDialog,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'Add',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      _ => (
          'Profile & Settings',
          'Account Details & App Preferences',
          null,
        ),
    };

    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
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
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  const _HeaderBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
