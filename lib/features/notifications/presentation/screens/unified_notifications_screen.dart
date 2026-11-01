import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/user_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../admin/domain/entities/admin_notification_model.dart';
import '../../../admin/presentation/screens/admin_appointment_detail_screen.dart';
import '../../../admin/presentation/screens/admin_doctor_detail_screen.dart';
import '../../../consultation/presentation/screens/prescription_viewer_screen.dart';
import '../../../patient/presentation/screens/patient_appointment_detail_screen.dart';

/// Role targeting for notification presentation and behavior
enum NotificationRole {
  patient,
  admin,
  doctor,
}

/// Normalized notification model across Patient, Admin, and Doctor domains
class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final String timestampIso;
  final bool isRead;
  final String type;
  final String? targetId;
  final String? statusLabel;
  final bool isActionable;
  final dynamic original;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestampIso,
    required this.isRead,
    required this.type,
    this.targetId,
    this.statusLabel,
    this.isActionable = true,
    this.original,
  });

  /// Factory converter from PatientNotificationItem
  factory AppNotificationItem.fromPatient(PatientNotificationItem item) {
    return AppNotificationItem(
      id: item.id,
      title: item.title,
      body: item.body,
      timestampIso: item.createdAt,
      isRead: item.isRead,
      type: item.type,
      targetId: item.targetId,
      statusLabel: null,
      isActionable: true,
      original: item,
    );
  }

  /// Factory converter from AdminNotificationItem
  factory AppNotificationItem.fromAdmin(
    AdminNotificationItem item, {
    required bool isRead,
  }) {
    return AppNotificationItem(
      id: item.id,
      title: item.title,
      body: item.subtitle,
      timestampIso: item.timestampIso,
      isRead: isRead,
      type: item.type.name,
      targetId: item.targetId,
      statusLabel: item.statusLabel,
      isActionable: item.isActionable,
      original: item,
    );
  }
}

/// Unified, high-performance, reusable Notifications screen for Patient, Admin, and Doctor
class UnifiedNotificationsScreen extends ConsumerStatefulWidget {
  final NotificationRole role;
  final String? title;

  const UnifiedNotificationsScreen({
    super.key,
    required this.role,
    this.title,
  });

  @override
  ConsumerState<UnifiedNotificationsScreen> createState() =>
      _UnifiedNotificationsScreenState();
}

class _UnifiedNotificationsScreenState
    extends ConsumerState<UnifiedNotificationsScreen> {
  String _selectedFilter = 'All'; // 'All' | 'Unread'

  Future<void> _handleMarkAllRead() async {
    final user = ref.read(currentUserProvider);

    switch (widget.role) {
      case NotificationRole.patient:
        if (user != null) {
          await UserNotificationService.instance.markAllAsReadForUser(user.id);
        }
      case NotificationRole.admin:
        final items = ref.read(adminNotificationsProvider);
        if (items.isNotEmpty) {
          await ref
              .read(readNotificationsProvider.notifier)
              .markAllAsRead(items.map((e) => e.id));
        }
      case NotificationRole.doctor:
        if (user != null) {
          await UserNotificationService.instance.markAllAsReadForUser(user.id);
        }
    }
  }

  void _handleItemTap(AppNotificationItem item) {
    switch (widget.role) {
      case NotificationRole.patient:
        // Mark as read in background without UI delay
        UserNotificationService.instance.markAsRead(item.id);

        String? targetAppointmentId = item.targetId;

        // Smart fallback lookup for older notifications missing targetId
        if (targetAppointmentId == null || targetAppointmentId.isEmpty) {
          final userAppointments =
              ref.read(userAppointmentsProvider).valueOrNull ?? [];
          for (final apt in userAppointments) {
            if (item.body.contains(apt.doctorName) ||
                item.title.contains(apt.doctorName) ||
                item.body.contains(apt.id) ||
                item.id.contains(apt.id)) {
              targetAppointmentId = apt.id;
              break;
            }
          }
        }

        if (item.type.contains('prescription') &&
            item.targetId != null &&
            item.targetId!.startsWith('rx_')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PrescriptionViewerScreen(
                prescriptionId: item.targetId!,
              ),
            ),
          );
        } else if (targetAppointmentId != null &&
            targetAppointmentId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientAppointmentDetailScreen(
                appointmentId: targetAppointmentId!,
              ),
            ),
          );
        } else {
          if (item.type.contains('prescription')) {
            ref.read(patientSelectedTabProvider.notifier).state = 2;
          } else {
            ref.read(patientSelectedTabProvider.notifier).state = 1;
          }
          context.go('/patient');
        }

      case NotificationRole.admin:
        ref.read(readNotificationsProvider.notifier).markAsRead(item.id);

        if (item.type == AdminNotificationType.doctorVerification.name ||
            item.type.contains('doctor')) {
          if (!item.isActionable) {
            AppSnackBar.showInfo(
              context,
              'This credential request is already ${(item.statusLabel ?? 'resolved').toLowerCase()}.',
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AdminDoctorDetailScreen(doctorId: item.targetId ?? ''),
            ),
          );
        } else if (item.type ==
                AdminNotificationType.appointmentActivity.name ||
            item.type.contains('appointment')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminAppointmentDetailScreen(
                  appointmentId: item.targetId ?? ''),
            ),
          );
        } else if (item.type ==
                AdminNotificationType.prescriptionIssued.name ||
            item.type.contains('prescription')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PrescriptionViewerScreen(
                  prescriptionId: item.targetId ?? ''),
            ),
          );
        }

      case NotificationRole.doctor:
        UserNotificationService.instance.markAsRead(item.id);
        if (item.targetId != null && item.targetId!.isNotEmpty) {
          context.go('/consultation/room/${item.targetId}');
        }
    }
  }

  (Color color, IconData icon, String label) _getEventStyling(
      AppNotificationItem item) {
    final typeLower = item.type.toLowerCase();
    final titleLower = item.title.toLowerCase();
    final bodyLower = item.body.toLowerCase();
    final statusLower = (item.statusLabel ?? '').toLowerCase();

    // Cancelled / Declined / Rejected -> Error Red
    if (typeLower.contains('cancelled') ||
        titleLower.contains('cancelled') ||
        bodyLower.contains('cancelled') ||
        typeLower.contains('rejected') ||
        titleLower.contains('declined') ||
        bodyLower.contains('declined') ||
        statusLower.contains('cancelled') ||
        statusLower.contains('declined') ||
        statusLower.contains('rejected')) {
      return (
        AppColors.error,
        Icons.cancel_outlined,
        (titleLower.contains('decline') ||
                bodyLower.contains('decline') ||
                statusLower.contains('decline'))
            ? 'Declined'
            : 'Cancelled',
      );
    }

    // Confirmed / Approved / Verified -> Success Green
    if (typeLower.contains('confirmed') ||
        titleLower.contains('confirmed') ||
        typeLower.contains('approved') ||
        titleLower.contains('approved') ||
        statusLower.contains('confirmed') ||
        statusLower.contains('approved') ||
        statusLower.contains('verified')) {
      return (
        AppColors.success,
        Icons.check_circle_outline_rounded,
        statusLower.contains('verified') ? 'Verified' : 'Confirmed',
      );
    }

    // Completed -> Emerald
    if (typeLower.contains('completed') ||
        titleLower.contains('completed') ||
        statusLower.contains('completed')) {
      return (
        const Color(0xFF059669),
        Icons.task_alt_rounded,
        'Completed',
      );
    }

    // In Progress / Video / Ongoing -> Sky Blue
    if (typeLower.contains('in_progress') ||
        titleLower.contains('in progress') ||
        typeLower.contains('video') ||
        typeLower.contains('call') ||
        statusLower.contains('in progress') ||
        statusLower.contains('ongoing')) {
      return (
        const Color(0xFF0284C7),
        Icons.videocam_rounded,
        'In Progress',
      );
    }

    // Prescription -> Violet
    if (typeLower.contains('prescription') ||
        titleLower.contains('prescription') ||
        statusLower.contains('prescription')) {
      return (
        AppColors.secondary,
        Icons.medication_rounded,
        'Prescription',
      );
    }

    // Chat / Message -> Royal Blue
    if (typeLower.contains('chat') || typeLower.contains('message')) {
      return (
        AppColors.primary,
        Icons.chat_bubble_outline_rounded,
        'Message',
      );
    }

    // Requested / Pending / Credential Review -> Amber Warning
    if (typeLower.contains('requested') ||
        titleLower.contains('request') ||
        titleLower.contains('booking') ||
        statusLower.contains('requested') ||
        statusLower.contains('pending') ||
        item.type == 'doctorVerification' ||
        item.statusLabel == 'Credential Review') {
      return (
        AppColors.warning,
        Icons.pending_actions_rounded,
        (item.type == 'doctorVerification' ||
                item.statusLabel == 'Credential Review')
            ? 'Credential Review'
            : 'Requested',
      );
    }

    return (
      AppColors.primary,
      Icons.notifications_rounded,
      item.statusLabel != null && item.statusLabel!.isNotEmpty
          ? item.statusLabel!
          : 'Update',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    // Provide role-specific notification stream / list
    if (widget.role == NotificationRole.patient) {
      final notificationsAsync = ref.watch(patientNotificationsStreamProvider);

      return _buildScaffold(
        context: context,
        isDark: isDark,
        surfaceColor: surfaceColor,
        borderColor: borderColor,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        unreadCount: notificationsAsync.valueOrNull
                ?.where((n) => !n.isRead)
                .length ??
            0,
        content: notificationsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          error: (err, _) => ErrorStateView(
            message: err.toString(),
            onRetry: () => ref.refresh(patientNotificationsStreamProvider),
          ),
          data: (items) {
            final normalized =
                items.map((i) => AppNotificationItem.fromPatient(i)).toList();
            return _buildNotificationList(
              items: normalized,
              isDark: isDark,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            );
          },
        ),
      );
    } else {
      // Admin (and future Doctor)
      final adminItems = ref.watch(adminNotificationsProvider);
      final readIds = ref.watch(readNotificationsProvider);

      final normalized = adminItems
          .map((i) => AppNotificationItem.fromAdmin(
                i,
                isRead: readIds.contains(i.id),
              ))
          .toList();

      final unreadCount = normalized.where((n) => !n.isRead).length;

      return PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop && widget.role == NotificationRole.admin) {
            _handleMarkAllRead();
          }
        },
        child: _buildScaffold(
          context: context,
          isDark: isDark,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          unreadCount: unreadCount,
          content: _buildNotificationList(
            items: normalized,
            isDark: isDark,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ),
      );
    }
  }

  Widget _buildScaffold({
    required BuildContext context,
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required int unreadCount,
    required Widget content,
  }) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          // Seamless top header with NO divider line underneath
          color: surfaceColor,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    widget.title ?? 'Notifications',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  TextButton(
                    onPressed: _handleMarkAllRead,
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs (Flat Bar with All & Unread toggle)
          // Features single bottom divider line separating header from notification list
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                _buildFilterChip(
                  'All',
                  isDark,
                  surfaceColor,
                  borderColor,
                  textPrimary,
                  textSecondary,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Unread',
                  isDark,
                  surfaceColor,
                  borderColor,
                  textPrimary,
                  textSecondary,
                  badgeCount: unreadCount,
                ),
              ],
            ),
          ),

          // Notification List Area
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildNotificationList({
    required List<AppNotificationItem> items,
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final filtered = items.where((n) {
      if (_selectedFilter == 'Unread') return !n.isRead;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return EmptyStateView(
        icon: Icons.notifications_none_rounded,
        title: _selectedFilter == 'Unread'
            ? 'No Unread Notifications'
            : 'No Notifications Yet',
        description: _selectedFilter == 'Unread'
            ? 'You have caught up with all updates and messages.'
            : 'Activity updates, consultations, and digital prescriptions will appear here in real time.',
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, thickness: 1, color: borderColor),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final isUnread = !item.isRead;
        final (eventColor, iconData, chipLabel) = _getEventStyling(item);
        final Color iconBgColor =
            eventColor.withOpacity(isDark ? 0.18 : 0.10);
        final Color unreadBgColor = isDark
            ? AppColors.primary.withOpacity(0.12)
            : const Color(0xFFEFF5FF);

        return InkWell(
          onTap: () => _handleItemTap(item),
          child: Container(
            decoration: BoxDecoration(
              color: isUnread ? unreadBgColor : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: isUnread ? AppColors.primary : Colors.transparent,
                  width: 3.5,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    iconData,
                    color: eventColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.4),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.body,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            DateTimeUtils.formatRelativeTime(item.timestampIso),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: textSecondary.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: eventColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: eventColor.withOpacity(0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              chipLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: eventColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: textSecondary.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary, {
    int badgeCount = 0,
  }) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : textSecondary,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.25)
                      : AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
