import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/user_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/state_views.dart';

class PatientNotificationsScreen extends ConsumerStatefulWidget {
  const PatientNotificationsScreen({super.key});

  @override
  ConsumerState<PatientNotificationsScreen> createState() =>
      _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState
    extends ConsumerState<PatientNotificationsScreen> {
  String _selectedFilter = 'All'; // 'All' | 'Unread'

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(patientNotificationsStreamProvider);
    final user = ref.watch(currentUserProvider);
    final isDark = AppColors.isDark(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
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
                    'Notifications',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    if (user != null) {
                      await UserNotificationService.instance
                          .markAllAsReadForUser(user.id);
                    }
                  },
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
          // Filter Tabs (Flat Bar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                _buildFilterChip('All', isDark, surfaceColor, borderColor, textPrimary, textSecondary),
                const SizedBox(width: 8),
                _buildFilterChip('Unread', isDark, surfaceColor, borderColor, textPrimary, textSecondary),
              ],
            ),
          ),

          // Notification List
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              error: (err, _) => ErrorStateView(
                message: err.toString(),
                onRetry: () => ref.refresh(patientNotificationsStreamProvider),
              ),
              data: (notifications) {
                final filtered = notifications.where((n) {
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
                        : 'Updates about your doctor consultations, appointments, and prescriptions will appear here in real time.',
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
                    return InkWell(
                      onTap: () async {
                        await UserNotificationService.instance.markAsRead(item.id);
                        if (!context.mounted) return;

                        // Deep Link Context Routing
                        if (item.type.contains('prescription')) {
                          context.push('/patient/appointments');
                        } else if (item.type.contains('chat')) {
                          context.push('/patient/appointments');
                        } else {
                          context.push('/patient/appointments');
                        }
                      },
                      child: Container(
                        color: item.isRead
                            ? Colors.transparent
                            : AppColors.primary.withOpacity(0.04),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _getIconBackgroundColor(item.type, isDark),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getNotificationIcon(item.type),
                                color: _getIconColor(item.type),
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
                                            fontWeight: item.isRead
                                                ? FontWeight.w600
                                                : FontWeight.w800,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (!item.isRead) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
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
                                  Text(
                                    DateTimeUtils.formatRelativeTime(item.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: textSecondary.withOpacity(0.7),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : textSecondary,
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    if (type.contains('appointment') || type.contains('booking')) {
      return Icons.event_note_rounded;
    }
    if (type.contains('prescription')) {
      return Icons.medication_rounded;
    }
    if (type.contains('chat') || type.contains('message')) {
      return Icons.chat_bubble_rounded;
    }
    if (type.contains('call') || type.contains('video')) {
      return Icons.videocam_rounded;
    }
    return Icons.notifications_rounded;
  }

  Color _getIconColor(String type) {
    if (type.contains('cancelled') || type.contains('rejected')) {
      return AppColors.error;
    }
    if (type.contains('prescription')) {
      return AppColors.secondary;
    }
    if (type.contains('confirmed') || type.contains('approved')) {
      return AppColors.success;
    }
    return AppColors.primary;
  }

  Color _getIconBackgroundColor(String type, bool isDark) {
    final base = _getIconColor(type);
    return base.withOpacity(isDark ? 0.2 : 0.12);
  }
}
