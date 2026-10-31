import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../consultation/presentation/screens/prescription_viewer_screen.dart';
import '../../domain/entities/admin_notification_model.dart';
import 'admin_appointment_detail_screen.dart';
import 'admin_doctor_detail_screen.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  void _markAllVisibleAsRead() {
    final items = ref.read(adminNotificationsProvider);
    if (items.isNotEmpty) {
      ref
          .read(readNotificationsProvider.notifier)
          .markAllAsRead(items.map((e) => e.id));
    }
  }

  void _handleItemTap(AdminNotificationItem item) {
    // 1. Immediately mark this notification as read
    ref.read(readNotificationsProvider.notifier).markAsRead(item.id);

    // 2. Route safely based on notification type & resolution state
    switch (item.type) {
      case AdminNotificationType.doctorVerification:
        if (!item.isActionable) {
          // Already approved or declined: do not open approval flow
          AppSnackBar.showInfo(
            context,
            'This credential request is already ${item.statusLabel.toLowerCase()}.',
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDoctorDetailScreen(doctorId: item.targetId),
          ),
        );
      case AdminNotificationType.appointmentActivity:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AdminAppointmentDetailScreen(appointmentId: item.targetId),
          ),
        );
      case AdminNotificationType.prescriptionIssued:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PrescriptionViewerScreen(prescriptionId: item.targetId),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(adminNotificationsProvider);
    final readIds = ref.watch(readNotificationsProvider);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);

    final unreadCount =
        notifications.where((n) => !readIds.contains(n.id)).length;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _markAllVisibleAsRead();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundOf(context),
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            if (unreadCount > 0)
              TextButton(
                onPressed: _markAllVisibleAsRead,
                child: const Text('Mark all read'),
              ),
          ],
        ),
        body: notifications.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 48,
                        color: textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications yet',
                        style: AppTypography.headline.copyWith(
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Doctor verification requests and appointment updates will appear here.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(top: 6, bottom: 40),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 80,
                  endIndent: 20,
                  color: borderColor,
                ),
                itemBuilder: (context, index) {
                  final item = notifications[index];
                  final isUnread = !readIds.contains(item.id);

                  final IconData iconData = switch (item.type) {
                    AdminNotificationType.doctorVerification =>
                      item.isActionable
                          ? Icons.verified_user_outlined
                          : Icons.verified_rounded,
                    AdminNotificationType.appointmentActivity =>
                      Icons.calendar_today_rounded,
                    AdminNotificationType.prescriptionIssued =>
                      Icons.description_outlined,
                  };

                  final Color pillColor = !item.isActionable
                      ? textSecondary
                      : (item.type == AdminNotificationType.doctorVerification
                          ? AppColors.warning
                          : AppColors.primary);

                  return InkWell(
                    onTap: () => _handleItemTap(item),
                    child: Container(
                      color: isUnread
                          ? AppColors.primary.withValues(alpha: 0.04)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  iconData,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              if (isUnread)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 11,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.backgroundOf(context),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodyLarge.copyWith(
                                          fontWeight: isUnread
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: pillColor.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        item.statusLabel,
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 11,
                                          color: pillColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

