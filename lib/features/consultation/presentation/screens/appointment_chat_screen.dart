import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthcare_app/core/providers/app_providers.dart';
import 'package:healthcare_app/core/theme/app_colors.dart';
import 'package:healthcare_app/core/utils/date_time_utils.dart';
import 'package:healthcare_app/core/widgets/app_snack_bar.dart';
import 'package:healthcare_app/core/widgets/state_views.dart';
import 'package:healthcare_app/features/appointment/domain/entities/appointment_model.dart';

class AppointmentChatScreen extends ConsumerStatefulWidget {
  final String appointmentId;

  const AppointmentChatScreen({super.key, required this.appointmentId});

  @override
  ConsumerState<AppointmentChatScreen> createState() =>
      _AppointmentChatScreenState();
}

class _AppointmentChatScreenState extends ConsumerState<AppointmentChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _resolveEffectiveChatId() {
    final appointments = ref.read(userAppointmentsProvider).valueOrNull ?? [];
    final currentApt =
        appointments.where((a) => a.id == widget.appointmentId).firstOrNull;
    if (currentApt == null) return widget.appointmentId;

    final pairAppointments = appointments
        .where((a) =>
            a.patientId == currentApt.patientId &&
            a.doctorId == currentApt.doctorId &&
            a.status != AppointmentStatus.cancelled &&
            a.status != AppointmentStatus.rejected)
        .toList();
    if (pairAppointments.isEmpty) return currentApt.id;

    pairAppointments.sort((a, b) {
      final aHasMsg = a.lastMessageSentAtUtc != null &&
          a.lastMessageContent != null &&
          a.lastMessageContent!.trim().isNotEmpty;
      final bHasMsg = b.lastMessageSentAtUtc != null &&
          b.lastMessageContent != null &&
          b.lastMessageContent!.trim().isNotEmpty;
      if (aHasMsg && !bHasMsg) return -1;
      if (!aHasMsg && bHasMsg) return 1;

      final timeA = a.lastMessageSentAtUtc ?? a.createdAt;
      final timeB = b.lastMessageSentAtUtc ?? b.createdAt;
      return timeB.compareTo(timeA);
    });

    return pairAppointments.first.id;
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final effectiveChatId = _resolveEffectiveChatId();
      final aptRepo = ref.read(appointmentRepositoryProvider);
      await aptRepo.sendMessage(
        appointmentId: effectiveChatId,
        senderId: user.id,
        senderName: user.displayName,
        senderRole: user.role.name,
        content: text,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to send: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final u = ref.read(currentUserProvider);
      if (u != null) {
        final effectiveChatId = _resolveEffectiveChatId();
        ref.read(appointmentRepositoryProvider).markAppointmentMessagesAsRead(
              appointmentId: effectiveChatId,
              readerRole: u.role.name,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final appointments = ref.watch(userAppointmentsProvider).valueOrNull ?? [];
    final currentApt =
        appointments.where((a) => a.id == widget.appointmentId).firstOrNull;

    // Resolve canonical appointment between this pair (1 single conversation per doctor/patient)
    final AppointmentModel? canonicalApt;
    if (currentApt != null) {
      final pairAppointments = appointments
          .where((a) =>
              a.patientId == currentApt.patientId &&
              a.doctorId == currentApt.doctorId &&
              a.status != AppointmentStatus.cancelled &&
              a.status != AppointmentStatus.rejected)
          .toList();
      if (pairAppointments.isNotEmpty) {
        pairAppointments.sort((a, b) {
          final aHasMsg = a.lastMessageSentAtUtc != null &&
              a.lastMessageContent != null &&
              a.lastMessageContent!.trim().isNotEmpty;
          final bHasMsg = b.lastMessageSentAtUtc != null &&
              b.lastMessageContent != null &&
              b.lastMessageContent!.trim().isNotEmpty;
          if (aHasMsg && !bHasMsg) return -1;
          if (!aHasMsg && bHasMsg) return 1;

          final timeA = a.lastMessageSentAtUtc ?? a.createdAt;
          final timeB = b.lastMessageSentAtUtc ?? b.createdAt;
          return timeB.compareTo(timeA);
        });
        canonicalApt = pairAppointments.first;
      } else {
        canonicalApt = currentApt;
      }
    } else {
      canonicalApt = null;
    }

    final effectiveChatId = canonicalApt?.id ?? widget.appointmentId;
    final apt = canonicalApt ?? currentApt;

    final messagesAsync =
        ref.watch(appointmentMessagesStreamProvider(effectiveChatId));

    // Listen and mark messages read whenever new messages arrive
    ref.listen(appointmentMessagesStreamProvider(effectiveChatId),
        (prev, next) {
      if (user != null) {
        ref.read(appointmentRepositoryProvider).markAppointmentMessagesAsRead(
              appointmentId: effectiveChatId,
              readerRole: user.role.name,
            );
      }
    });
    final isPatient = user?.isPatient ?? true;
    final participantName = isPatient
        ? (apt?.doctorName.isNotEmpty == true ? apt!.doctorName : 'Specialist')
        : (apt?.patientName.isNotEmpty == true ? apt!.patientName : 'Patient');
    final targetUserId = isPatient ? (apt?.doctorId ?? '') : (apt?.patientId ?? '');
    final isOnline = ref.watch(userPresenceStreamProvider(targetUserId)).valueOrNull ?? false;

    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    participantName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isOnline ? AppColors.success : const Color(0xFF9E9E9E))
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: isOnline ? AppColors.success : const Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isOnline ? AppColors.success : const Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              'Encrypted • #${widget.appointmentId.length > 8 ? widget.appointmentId.substring(0, 8).toUpperCase() : widget.appointmentId.toUpperCase()}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: AppColors.primary),
            tooltip: 'Join Video Consultation',
            onPressed: () =>
                context.push('/consultation/room/${widget.appointmentId}'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Streamed Real-time Message List
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              error: (err, _) => ErrorStateView(
                message: err.toString(),
                onRetry: () => ref.refresh(
                    appointmentMessagesStreamProvider(widget.appointmentId)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No Messages Yet',
                    description:
                        'Send a message to your doctor regarding symptoms, questions, or visit details.',
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.separated(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = user?.id == msg.senderId;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.primary
                              : (isDark ? surfaceColor : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isMe
                                ? const Radius.circular(12)
                                : Radius.zero,
                            bottomRight: isMe
                                ? Radius.zero
                                : const Radius.circular(12),
                          ),
                          border: isMe
                              ? null
                              : Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.senderName,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isMe
                                    ? Colors.white70
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg.content,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.35,
                                color: isMe ? Colors.white : textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateTimeUtils.formatLocalTime(msg.sentAtUtc),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: isMe
                                        ? Colors.white60
                                        : textSecondary.withOpacity(0.8),
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  if (msg.isRead)
                                    const Icon(
                                      Icons.done_all_rounded,
                                      size: 14,
                                      color: Color(0xFF34B7F1),
                                    )
                                  else if (msg.isDelivered || isOnline)
                                    const Icon(
                                      Icons.done_all_rounded,
                                      size: 14,
                                      color: Colors.white70,
                                    )
                                  else
                                    const Icon(
                                      Icons.done_rounded,
                                      size: 14,
                                      color: Colors.white60,
                                    ),
                                ],
                              ],
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

          // Message Composer (Flat & Non-duplicating)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: borderColor, width: 1)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSendMessage(),
                      enabled: !_isSending,
                      style: TextStyle(color: textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Type an encrypted consultation message...',
                        hintStyle: TextStyle(
                            color: textSecondary.withOpacity(0.7),
                            fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.backgroundOf(context)
                            : const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _isSending ? borderColor : AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      onPressed: _isSending ? null : _handleSendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
