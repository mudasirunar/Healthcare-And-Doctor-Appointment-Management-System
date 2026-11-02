import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../domain/entities/doctor_model.dart';
import 'doctor_dashboard_screen.dart';
import 'doctor_agenda_screen.dart';
import 'doctor_requests_screen.dart';
import 'doctor_settings_screen.dart';
import 'doctor_notifications_screen.dart';

class DoctorMainScreen extends ConsumerStatefulWidget {
  const DoctorMainScreen({super.key});

  @override
  ConsumerState<DoctorMainScreen> createState() => _DoctorMainScreenState();
}

class _DoctorMainScreenState extends ConsumerState<DoctorMainScreen> {
  final ScrollController _dashboardScrollController = ScrollController();
  final ScrollController _agendaScrollController = ScrollController();
  final ScrollController _requestsScrollController = ScrollController();
  final ScrollController _settingsScrollController = ScrollController();

  late final List<ScrollController> _scrollControllers;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _scrollControllers = [
      _dashboardScrollController,
      _agendaScrollController,
      _requestsScrollController,
      _settingsScrollController,
    ];
    _pages = [
      DoctorDashboardScreen(scrollController: _dashboardScrollController),
      DoctorAgendaScreen(scrollController: _agendaScrollController),
      DoctorRequestsScreen(scrollController: _requestsScrollController),
      DoctorSettingsScreen(
        scrollController: _settingsScrollController,
        onSignOut: _handleSignOut,
      ),
    ];
  }

  @override
  void dispose() {
    _dashboardScrollController.dispose();
    _agendaScrollController.dispose();
    _requestsScrollController.dispose();
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
        message: 'Are you sure you want to sign out of your physician workspace?',
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
    final user = ref.watch(currentUserProvider);
    final doctorRepo = ref.watch(doctorRepositoryProvider);
    final currentIndex = ref.watch(doctorSelectedTabProvider);
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final unreadNotifs = ref.watch(unreadPatientNotificationsCountProvider);
    final unreadChats = ref.watch(unreadConversationsCountProvider);

    final pendingRequestsCount = appointmentsAsync.value
            ?.where((a) => a.status == AppointmentStatus.requested)
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      extendBody: true,
      appBar: _buildContextualAppBar(
        context,
        tabIndex: currentIndex,
        unreadNotificationsCount: unreadNotifs,
        unreadChatsCount: unreadChats,
      ),
      body: Column(
        children: [
          // Verification Warning Banner if Doctor is pending or rejected
          FutureBuilder<DoctorModel?>(
            future: user != null ? doctorRepo.getDoctorByUserId(user.id) : null,
            builder: (context, snapshot) {
              final doc = snapshot.data;
              if (doc == null) return const SizedBox.shrink();

              if (doc.verificationStatus == VerificationStatus.pending) {
                return Container(
                  width: double.infinity,
                  color: AppColors.warningLight.withValues(alpha: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        const Icon(Icons.pending_actions_rounded, size: 18, color: AppColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your profile is pending administrator verification. Patients cannot discover your slots until approved.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (doc.verificationStatus == VerificationStatus.rejected) {
                return Container(
                  width: double.infinity,
                  color: AppColors.errorLight.withValues(alpha: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Verification declined: ${doc.verificationNotes ?? "Credentials could not be verified."}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: currentIndex,
        onTap: (idx) => ref.read(doctorSelectedTabProvider.notifier).state = idx,
        scrollControllers: _scrollControllers,
        items: [
          const AppNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: 'Dashboard',
          ),
          const AppNavItem(
            icon: Icons.event_note_outlined,
            activeIcon: Icons.event_note_rounded,
            label: 'Agenda',
          ),
          AppNavItem(
            icon: Icons.mark_email_unread_outlined,
            activeIcon: Icons.mark_email_unread_rounded,
            label: 'Requests',
            badgeCount: pendingRequestsCount,
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

  PreferredSizeWidget _buildContextualAppBar(
    BuildContext context, {
    required int tabIndex,
    required int unreadNotificationsCount,
    required int unreadChatsCount,
  }) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final currentUser = ref.watch(currentUserProvider);

    final chatButton = _ChatIconButtonWithBadge(
      unreadCount: unreadChatsCount,
      onTap: () => context.push('/doctor/chats'),
    );

    final notificationBell = _NotificationBellButton(
      unreadCount: unreadNotificationsCount,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DoctorNotificationsScreen(),
          ),
        );
      },
    );

    final (Widget leadingContent, Widget? trailingContent) = switch (tabIndex) {
      0 => (
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: currentUser?.avatarUrl != null
                    ? NetworkImage(currentUser!.avatarUrl!)
                    : null,
                child: currentUser?.avatarUrl == null
                    ? Text(
                        currentUser != null && currentUser.displayName.isNotEmpty
                            ? currentUser.displayName[0].toUpperCase()
                            : 'D',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Physician Workspace',
                      style: AppTypography.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentUser?.displayName ?? 'Doctor',
                      style: AppTypography.headline.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: 0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              chatButton,
              const SizedBox(width: 8),
              notificationBell,
            ],
          ),
        ),
      1 => (
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Consultation Agenda',
                style: AppTypography.headline.copyWith(
                  fontSize: 18,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Scheduled sessions, timeline & clinical queue',
                style: AppTypography.caption.copyWith(
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              chatButton,
              const SizedBox(width: 8),
              notificationBell,
            ],
          ),
        ),
      2 => (
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Booking Requests',
                style: AppTypography.headline.copyWith(
                  fontSize: 18,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Patient consult requests awaiting review',
                style: AppTypography.caption.copyWith(
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              chatButton,
              const SizedBox(width: 8),
              notificationBell,
            ],
          ),
        ),
      _ => (
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Doctor Settings',
                style: AppTypography.headline.copyWith(
                  fontSize: 18,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Workspace preferences, security & profile',
                style: AppTypography.caption.copyWith(
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          null,
        ),
    };

    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
      child: RepaintBoundary(
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
                  Expanded(child: leadingContent),
                  ?trailingContent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatIconButtonWithBadge extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _ChatIconButtonWithBadge({
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
                  ? Icons.chat_bubble_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 20,
              color: unreadCount > 0 ? AppColors.primary : textPrimary,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: AppColors.surfaceOf(context),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
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
