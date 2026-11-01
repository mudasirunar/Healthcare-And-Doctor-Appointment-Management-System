import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/smart_search_utils.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import '../../../../core/services/presence_service.dart';
import '../../domain/entities/chat_message_model.dart';

enum _ChatFilterTab { all, unread }

/// WhatsApp-style message delivery and read status
enum MessageTickStatus {
  sending, // WhatsApp clock icon (sending / offline queue)
  sent, // Single gray tick (sent to server, recipient offline)
  delivered, // Double gray tick (reached recipient's device / recipient is online)
  read, // Double blue tick (opened and seen by recipient)
}

class _MessageStatusTick extends StatelessWidget {
  final MessageTickStatus status;

  const _MessageStatusTick({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    const blueColor = Color(0xFF34B7F1); // WhatsApp read blue
    final grayColor =
        AppColors.textSecondaryOf(context).withValues(alpha: 0.85);

    switch (status) {
      case MessageTickStatus.sending:
        return Icon(
          Icons.access_time_rounded,
          size: 13.5,
          color: grayColor,
        );
      case MessageTickStatus.sent:
        return Icon(
          Icons.done_rounded,
          size: 15,
          color: grayColor,
        );
      case MessageTickStatus.delivered:
        return Icon(
          Icons.done_all_rounded,
          size: 15,
          color: grayColor,
        );
      case MessageTickStatus.read:
        return Icon(
          Icons.done_all_rounded,
          size: 15,
          color: blueColor,
        );
    }
  }
}

const double kChatTileHeight = 84.0;

/// Reusable conversations hub for both Patients and Doctors.
class UnifiedChatsHubScreen extends ConsumerStatefulWidget {
  final UserRole role;

  const UnifiedChatsHubScreen({
    super.key,
    required this.role,
  });

  @override
  ConsumerState<UnifiedChatsHubScreen> createState() =>
      _UnifiedChatsHubScreenState();
}

class _UnifiedChatsHubScreenState extends ConsumerState<UnifiedChatsHubScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  _ChatFilterTab _selectedTab = _ChatFilterTab.all;
  Timer? _liveTicker;
  final Map<String, List<ChatMessageModel>> _chatHistoryCache = {};
  bool _isLoadingMessages = false;

  @override
  void initState() {
    super.initState();
    // Periodically update relative timestamps live without requiring manual refresh
    _liveTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Calculates the most recent activity timestamp for a conversation.
  /// Exactly like WhatsApp:
  /// 1. If messages were sent or received, uses the latest message timestamp.
  /// 2. If no messages yet, uses the appointment booking creation timestamp (so newly booked doctors appear at the top).
  DateTime _getEffectiveActivityTime(AppointmentModel a) {
    if (a.lastMessageSentAtUtc != null &&
        a.lastMessageSentAtUtc!.trim().isNotEmpty) {
      final msgTime = DateTime.tryParse(a.lastMessageSentAtUtc!);
      if (msgTime != null) return msgTime;
    }
    final createdTime = DateTime.tryParse(a.createdAt);
    final updatedTime = DateTime.tryParse(a.updatedAt);
    if (updatedTime != null &&
        (createdTime == null || updatedTime.isAfter(createdTime))) {
      return updatedTime;
    }
    return createdTime ?? DateTime(2000);
  }

  int _compareConversationsByActivity(AppointmentModel a, AppointmentModel b) {
    final timeA = _getEffectiveActivityTime(a);
    final timeB = _getEffectiveActivityTime(b);
    return timeB.compareTo(timeA); // Most recent activity on top (#1)
  }

  void _loadChatHistories(Map<String, List<AppointmentModel>> grouped) async {
    if (_isLoadingMessages) return;
    final repo = ref.read(appointmentRepositoryProvider);
    final missingKeys =
        grouped.keys.where((k) => !_chatHistoryCache.containsKey(k)).toList();
    if (missingKeys.isEmpty) return;

    _isLoadingMessages = true;
    bool hasNew = false;
    for (final key in missingKeys) {
      final aptList = grouped[key] ?? [];
      final List<ChatMessageModel> allMsgs = [];
      for (final apt in aptList) {
        try {
          final msgs = await repo.getMessages(apt.id);
          allMsgs.addAll(msgs);
        } catch (_) {}
      }
      _chatHistoryCache[key] = allMsgs;
      hasNew = true;
    }
    _isLoadingMessages = false;
    if (hasNew && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _liveTicker?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final doctorsList = ref.watch(verifiedDoctorsStreamProvider).valueOrNull ?? [];

    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);
    final isPatient = widget.role == UserRole.patient;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: appointmentsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        error: (err, _) => ErrorStateView(
          message: err.toString(),
          onRetry: () => ref.refresh(userAppointmentsProvider),
        ),
        data: (appointments) {
          // All booked consultations (requested, confirmed, inProgress, completed)
          final activeConversations = appointments.where((a) =>
              a.status != AppointmentStatus.cancelled &&
              a.status != AppointmentStatus.rejected).toList();

          if (activeConversations.isEmpty) {
            return EmptyStateView(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No Active Messages',
              description: isPatient
                  ? 'When you book an appointment with a specialist, your direct encrypted consultation channel will appear here.'
                  : 'When patients book appointments with you, their direct consultation channels will appear here.',
            );
          }

          // Group by participant (1 single conversation per doctor or patient)
          final Map<String, List<AppointmentModel>> grouped = {};
          for (final apt in activeConversations) {
            final doctorKey = apt.doctorName.trim().isNotEmpty
                ? apt.doctorName.trim().toLowerCase()
                : apt.doctorId.trim().toLowerCase();
            final patientKey = apt.patientName.trim().isNotEmpty
                ? apt.patientName.trim().toLowerCase()
                : apt.patientId.trim().toLowerCase();
            final key = isPatient ? doctorKey : patientKey;
            grouped.putIfAbsent(key, () => []).add(apt);
          }

          // Trigger asynchronous background cache of chat histories for deep smart search
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadChatHistories(grouped);
          });

          // Create exactly ONE unified conversation representation per person
          final List<AppointmentModel> uniqueConversations = [];
          for (final group in grouped.values) {
            // Sort items in this group by latest activity so the most recent is canonical
            group.sort(_compareConversationsByActivity);

            final canonical = group.first;
            final totalUnreadPatient = group.fold<int>(
                0, (sum, a) => sum + a.unreadCountForPatient);
            final totalUnreadDoctor = group.fold<int>(
                0, (sum, a) => sum + a.unreadCountForDoctor);

            uniqueConversations.add(
              canonical.copyWith(
                unreadCountForPatient: totalUnreadPatient,
                unreadCountForDoctor: totalUnreadDoctor,
              ),
            );
          }

          // Sort conversations strictly by latest activity:
          // Newly booked appointments OR latest message (sent/received) are at the top (#1)
          uniqueConversations.sort(_compareConversationsByActivity);

          // Counts for the segmented tabs
          final int allCount = uniqueConversations.length;
          final int unreadCount = uniqueConversations.where((a) {
            final unread = isPatient
                ? a.unreadCountForPatient
                : a.unreadCountForDoctor;
            return unread > 0;
          }).length;

          // Filter by selected tab (All vs Unread)
          final tabFiltered = _selectedTab == _ChatFilterTab.unread
              ? uniqueConversations.where((a) {
                  final unread = isPatient
                      ? a.unreadCountForPatient
                      : a.unreadCountForDoctor;
                  return unread > 0;
                }).toList()
              : uniqueConversations;

          // Deep Smart Search: Searches names of both sides, specialty, visit reason,
          // and all sent/received messages across the entire chat conversation.
          final filtered =
              SmartSearchEngine.filterAndSort<AppointmentModel>(
            items: tabFiltered,
            query: _query,
            primaryTextBuilder: (a) =>
                isPatient ? a.doctorName : a.patientName,
            secondaryTextsBuilder: (a) {
              final doctorKey = a.doctorName.trim().isNotEmpty
                  ? a.doctorName.trim().toLowerCase()
                  : a.doctorId.trim().toLowerCase();
              final patientKey = a.patientName.trim().isNotEmpty
                  ? a.patientName.trim().toLowerCase()
                  : a.patientId.trim().toLowerCase();
              final pKey = isPatient ? doctorKey : patientKey;
              final history = _chatHistoryCache[pKey] ?? [];

              return [
                a.doctorName,
                a.patientName,
                a.doctorSpecialty,
                a.reasonForVisit,
                a.lastMessageContent ?? '',
                ...history.map((m) => m.content),
                ...history.map((m) => m.senderName),
              ];
            },
            fallbackComparator: _compareConversationsByActivity,
          );

          return Column(
            children: [
              // 1. Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: AppSearchBar(
                  controller: _searchCtrl,
                  hintText: isPatient
                      ? 'Search conversations by doctor or topic...'
                      : 'Search conversations by patient or condition...',
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () => setState(() => _query = ''),
                ),
              ),

              // 2. Segmented Tabs for All and Unread (no divider line above or below)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariantOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      _SegmentButton(
                        label: 'All ($allCount)',
                        isSelected: _selectedTab == _ChatFilterTab.all,
                        onTap: () => setState(
                            () => _selectedTab = _ChatFilterTab.all),
                      ),
                      _SegmentButton(
                        label: 'Unread ($unreadCount)',
                        isSelected: _selectedTab == _ChatFilterTab.unread,
                        onTap: () => setState(
                            () => _selectedTab = _ChatFilterTab.unread),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Animated Sliding Conversation List / Empty States
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: _selectedTab == _ChatFilterTab.unread &&
                                  _query.trim().isEmpty
                              ? EmptyStateView(
                                  icon: Icons.mark_chat_read_outlined,
                                  title: 'No Unread Messages',
                                  description:
                                      'You are all caught up! All consultation messages have been read.',
                                )
                              : Text(
                                  _query.trim().isEmpty
                                      ? 'No conversations found.'
                                      : 'No conversations match "$_query".',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final double listHeight =
                              filtered.length * kChatTileHeight;
                          final double scrollHeight =
                              listHeight < constraints.maxHeight
                                  ? constraints.maxHeight
                                  : listHeight + 40;

                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(top: 2, bottom: 40),
                            child: SizedBox(
                              height: scrollHeight,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  for (int index = 0;
                                      index < filtered.length;
                                      index++) ...[
                                    _buildAnimatedTile(
                                      context: context,
                                      apt: filtered[index],
                                      index: index,
                                      isPatient: isPatient,
                                      currentUser: currentUser,
                                      doctorsList: doctorsList,
                                      borderColor: borderColor,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnimatedTile({
    required BuildContext context,
    required AppointmentModel apt,
    required int index,
    required bool isPatient,
    required UserModel? currentUser,
    required List<DoctorModel> doctorsList,
    required Color borderColor,
  }) {
    final doctorKey = apt.doctorId.trim().isNotEmpty
        ? apt.doctorId.trim()
        : apt.doctorName.trim();
    final patientKey = apt.patientId.trim().isNotEmpty
        ? apt.patientId.trim()
        : apt.patientName.trim();
    final participantKey = isPatient ? doctorKey : patientKey;

    final participantName = isPatient ? apt.doctorName : apt.patientName;
    final participantSubtitle = isPatient
        ? apt.doctorSpecialty
        : (apt.reasonForVisit.isNotEmpty
            ? apt.reasonForVisit
            : 'Consultation');

    // Determine presence target user ID
    String targetUserId = isPatient ? apt.doctorId : apt.patientId;
    if (isPatient) {
      final matchedDoc =
          doctorsList.where((d) => d.id == apt.doctorId).firstOrNull;
      if (matchedDoc != null && matchedDoc.userId.isNotEmpty) {
        targetUserId = matchedDoc.userId;
      }
    }

    final itemUnreadCount = isPatient
        ? apt.unreadCountForPatient
        : apt.unreadCountForDoctor;
    final hasUnread = itemUnreadCount > 0;

    final hasLastMsg = apt.lastMessageContent != null &&
        apt.lastMessageContent!.trim().isNotEmpty;
    final isSentByMe = apt.lastMessageSenderId != null &&
        apt.lastMessageSenderId == currentUser?.id;

    // Determine WhatsApp-style message delivery and read status
    MessageTickStatus? messageTick;
    if (hasLastMsg && isSentByMe) {
      final recipientUnread = isPatient
          ? apt.unreadCountForDoctor
          : apt.unreadCountForPatient;

      final isRecipientOnline =
          PresenceService.instance.isUserOnline(targetUserId);

      if (recipientUnread == 0) {
        messageTick = MessageTickStatus.read; // Double blue tick (seen)
      } else if (isRecipientOnline) {
        messageTick = MessageTickStatus.delivered; // Double gray tick (online/reached)
      } else {
        messageTick = MessageTickStatus.sent; // Single gray tick (offline)
      }
    }

    // Display text:
    // - If sent by me: clean message text without "You: " prefix (the tick icon indicates it's yours!)
    // - If received: clean message text without sender name prefix
    // - If no messages yet: "Consultation booked • Tap to chat"
    String lastMessageDisplay = hasLastMsg
        ? apt.lastMessageContent!
        : 'Consultation booked • Tap to chat';

    // Smart snippet preview when query matches older chat history
    if (_query.trim().isNotEmpty) {
      final qLower = _query.trim().toLowerCase();
      final history = _chatHistoryCache[participantKey] ?? [];

      final lastMatches =
          apt.lastMessageContent?.toLowerCase().contains(qLower) ?? false;
      final nameMatches = (isPatient ? apt.doctorName : apt.patientName)
              .toLowerCase()
              .contains(qLower) ||
          apt.doctorSpecialty.toLowerCase().contains(qLower);

      if (!lastMatches && !nameMatches) {
        final matchedMsg = history
            .where((m) => m.content.toLowerCase().contains(qLower))
            .firstOrNull;
        if (matchedMsg != null) {
          lastMessageDisplay = 'Matched: "${matchedMsg.content}"';
          messageTick = null; // Don't show tick on historical search snippet
        }
      }
    }

    final timeStr = apt.lastMessageSentAtUtc != null
        ? DateTimeUtils.formatRelativeTime(apt.lastMessageSentAtUtc!)
        : null;

    return AnimatedPositioned(
      key: ValueKey(participantKey),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
      top: index * kChatTileHeight,
      left: 0,
      right: 0,
      height: kChatTileHeight,
      child: _ConversationListTile(
        key: ValueKey('tile_$participantKey'),
        appointment: apt,
        participantName: participantName,
        participantSubtitle: participantSubtitle,
        participantUserId: targetUserId,
        lastMessageText: lastMessageDisplay,
        timeText: timeStr,
        messageTick: messageTick,
        unreadCount: itemUnreadCount,
        hasUnread: hasUnread,
        isSystemPlaceholder: !hasLastMsg,
        borderColor: borderColor,
        onTap: () {
          context.push('/consultation/chat/${apt.id}');
        },
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceOf(context) : null,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.05,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AppColors.textPrimaryOf(context)
                  : AppColors.textSecondaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationListTile extends ConsumerWidget {
  final AppointmentModel appointment;
  final String participantName;
  final String participantSubtitle;
  final String participantUserId;
  final String lastMessageText;
  final String? timeText;
  final MessageTickStatus? messageTick;
  final int unreadCount;
  final bool hasUnread;
  final bool isSystemPlaceholder;
  final Color borderColor;
  final VoidCallback onTap;

  const _ConversationListTile({
    super.key,
    required this.appointment,
    required this.participantName,
    required this.participantSubtitle,
    required this.participantUserId,
    required this.lastMessageText,
    required this.timeText,
    this.messageTick,
    required this.unreadCount,
    required this.hasUnread,
    required this.isSystemPlaceholder,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final isDark = AppColors.isDark(context);
    final isOnline = ref
            .watch(userPresenceStreamProvider(participantUserId))
            .valueOrNull ??
        false;

    final Color unreadBgColor = isDark
        ? AppColors.primary.withValues(alpha: 0.12)
        : const Color(0xFFEFF5FF);

    final initial = participantName
            .replaceFirst('Dr. ', '')
            .trim()
            .characters
            .firstOrNull
            ?.toUpperCase() ??
        'U';

    return InkWell(
      onTap: onTap,
      child: Container(
        height: kChatTileHeight,
        decoration: BoxDecoration(
          color: hasUnread ? unreadBgColor : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: hasUnread ? AppColors.primary : Colors.transparent,
              width: 3.5,
            ),
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
            // Avatar with live presence dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: AppTypography.headline.copyWith(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? AppColors.success
                          : const Color(0xFF9E9E9E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hasUnread
                            ? unreadBgColor
                            : AppColors.backgroundOf(context),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          participantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headline.copyWith(
                            fontSize: 16,
                            fontWeight:
                                hasUnread ? FontWeight.w800 : FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      if (timeText != null && timeText!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          timeText!,
                          style: AppTypography.caption.copyWith(
                            fontSize: 11,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w500,
                            color:
                                hasUnread ? AppColors.primary : textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    participantSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (messageTick != null) ...[
                        _MessageStatusTick(status: messageTick!),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          lastMessageText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 13,
                            color: hasUnread ? textPrimary : textSecondary,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.w400,
                            fontStyle: isSystemPlaceholder
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Positioned(
        left: 84,
        right: 20,
        bottom: 0,
        child: Container(
          height: 1,
          color: borderColor.withValues(alpha: 0.35),
        ),
      ),
    ],
  ),
),
);
  }
}
