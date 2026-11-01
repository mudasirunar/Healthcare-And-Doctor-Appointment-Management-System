import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../patient/presentation/screens/doctor_details_screen.dart';
import '../../domain/entities/chat_message_model.dart';
import 'prescription_builder_dialog.dart';
import 'prescription_viewer_screen.dart';

/// Formats a medical department/specialty name into a specialist title
/// (e.g. Cardiology -> Cardiologist, Pediatrics -> Pediatrician).
String formatSpecialistTitle(String specialty) {
  final clean = specialty.trim();
  final lower = clean.toLowerCase();
  if (lower.isEmpty) return 'Specialist';
  if (lower.contains('cardio')) return 'Cardiologist';
  if (lower.contains('derm')) return 'Dermatologist';
  if (lower.contains('pediatric')) return 'Pediatrician';
  if (lower.contains('neuro')) return 'Neurologist';
  if (lower.contains('ortho')) return 'Orthopedist';
  if (lower.contains('psychiat')) return 'Psychiatrist';
  if (lower.contains('ophthalm')) return 'Ophthalmologist';
  if (lower.contains('oncol')) return 'Oncologist';
  if (lower.contains('urol')) return 'Urologist';
  if (lower.contains('pulmon')) return 'Pulmonologist';
  if (lower.contains('gastro')) return 'Gastroenterologist';
  if (lower.contains('gynec') || lower.contains('obgyn')) return 'Gynecologist';
  if (lower.contains('nephro')) return 'Nephrologist';
  if (lower.contains('endocrin')) return 'Endocrinologist';
  if (lower.contains('radiol')) return 'Radiologist';
  if (lower.contains('anesthes')) return 'Anesthesiologist';
  if (lower.contains('dent')) return 'Dentist';
  if (lower.contains('ent') || lower.contains('otolaryng')) return 'ENT Specialist';
  if (lower.contains('general') || lower.contains('internal')) return 'General Physician';
  if (lower.endsWith('ist') || lower.endsWith('ian')) return clean;
  return '$clean Specialist';
}

/// Reusable end-to-end Consultation Chat Screen for Patients and Doctors.
class UnifiedChatScreen extends ConsumerStatefulWidget {
  final String appointmentId;

  const UnifiedChatScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  ConsumerState<UnifiedChatScreen> createState() => _UnifiedChatScreenState();
}

class _UnifiedChatScreenState extends ConsumerState<UnifiedChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageModel> _optimisticPendingMessages = [];
  final Set<String> _animatingMessageIds = {};

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSendMessage(String effectiveChatId) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Deterministic unique message ID shared by both optimistic state and Firestore
    final messageId = 'msg_${const Uuid().v4().substring(0, 8)}';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final pendingMsg = ChatMessageModel(
      id: messageId,
      appointmentId: effectiveChatId,
      senderId: user.id,
      senderName: user.displayName,
      senderRole: user.role.name,
      content: text,
      sentAtUtc: nowIso,
      isPending: true, // Shows clock icon while in transit or offline
    );

    // Immediately clear input & register animation
    _messageController.clear();
    setState(() {
      _optimisticPendingMessages.insert(0, pendingMsg);
      _animatingMessageIds.add(messageId);
    });

    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }

    // Send in background: clock icon shows while sending, single/double tick when sent
    ref
        .read(appointmentRepositoryProvider)
        .sendMessage(
          appointmentId: effectiveChatId,
          senderId: user.id,
          senderName: user.displayName,
          senderRole: user.role.name,
          content: text,
          messageId: messageId,
        )
        .then((realMsg) {
      if (mounted) {
        setState(() {
          final idx =
              _optimisticPendingMessages.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            _optimisticPendingMessages[idx] =
                _optimisticPendingMessages[idx].copyWith(isPending: false);
          }
        });
      }
    }).catchError((err) {
      debugPrint('Background message send error: $err');
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final appointments = ref.watch(userAppointmentsProvider).valueOrNull ?? [];
    final doctorsList = ref.watch(verifiedDoctorsStreamProvider).valueOrNull ?? [];
    final currentApt =
        appointments.where((a) => a.id == widget.appointmentId).firstOrNull;

    final isPatient = user?.isPatient ?? true;

    // Resolve canonical appointment between this pair (1 single chat thread per pair)
    final AppointmentModel? canonicalApt;
    if (currentApt != null) {
      final pairAppointments = appointments
          .where((a) =>
              (isPatient
                  ? (a.doctorName.trim().toLowerCase() == currentApt.doctorName.trim().toLowerCase() ||
                     (a.doctorId.isNotEmpty && a.doctorId == currentApt.doctorId))
                  : (a.patientName.trim().toLowerCase() == currentApt.patientName.trim().toLowerCase() ||
                     (a.patientId.isNotEmpty && a.patientId == currentApt.patientId))) &&
              a.status != AppointmentStatus.cancelled &&
              a.status != AppointmentStatus.rejected)
          .toList();

      if (pairAppointments.isNotEmpty) {
        pairAppointments.sort((a, b) {
          final aTime = a.lastMessageSentAtUtc != null
              ? DateTime.tryParse(a.lastMessageSentAtUtc!)
              : null;
          final bTime = b.lastMessageSentAtUtc != null
              ? DateTime.tryParse(b.lastMessageSentAtUtc!)
              : null;
          if (aTime != null && bTime != null) return bTime.compareTo(aTime);
          if (aTime != null && bTime == null) return -1;
          if (aTime == null && bTime != null) return 1;
          return b.createdAt.compareTo(a.createdAt);
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

    // Automatically mark unread messages as read upon viewing
    ref.listen(appointmentMessagesStreamProvider(effectiveChatId), (_, next) {
      if (user != null) {
        ref.read(appointmentRepositoryProvider).markAppointmentMessagesAsRead(
              appointmentId: effectiveChatId,
              readerRole: user.role.name,
            );
      }
    });

    final participantName = isPatient
        ? (apt?.doctorName.isNotEmpty == true ? apt!.doctorName : 'Specialist')
        : (apt?.patientName.isNotEmpty == true ? apt!.patientName : 'Patient');

    // Resolve target presence user ID
    String targetUserId = isPatient ? (apt?.doctorId ?? '') : (apt?.patientId ?? '');
    if (isPatient && apt != null) {
      final matchedDoc =
          doctorsList.where((d) => d.id == apt.doctorId).firstOrNull;
      if (matchedDoc != null && matchedDoc.userId.isNotEmpty) {
        targetUserId = matchedDoc.userId;
      }
    }
    final isOnline = ref.watch(userPresenceStreamProvider(targetUserId)).valueOrNull ?? false;

    // Subtitle formatting
    final String subtitleText = isPatient
        ? formatSpecialistTitle(apt?.doctorSpecialty ?? '')
        : (apt?.reasonForVisit.isNotEmpty == true
            ? apt!.reasonForVisit
            : 'Patient Consultation');

    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final isDark = AppColors.isDark(context);
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    // Smooth continuous bottom padding that never snaps or flickers when keyboard opens/closes
    final double dynamicBottomPadding = math.max(0.0, safeBottom - bottomInset);

    return Scaffold(
      // Scaffold background matches surfaceColor so iOS keyboard rounded corner underlay is filled seamlessly
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        // Clickable header: Patients tap to view DoctorDetailsScreen
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (isPatient && apt != null && apt.doctorId.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorDetailsScreen(doctorId: apt.doctorId),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(width: 8),
                    // Presence status dot only
                    Container(
                      width: 8.5,
                      height: 8.5,
                      decoration: BoxDecoration(
                        color: isOnline ? AppColors.success : const Color(0xFF9E9E9E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (isPatient) ...[
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: textSecondary.withOpacity(0.6),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                // Specialist title (e.g. Cardiologist)
                Text(
                  subtitleText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPatient ? AppColors.primary : textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Prescription Button (for completed appointments)
          if (apt != null && apt.status == AppointmentStatus.completed)
            if (apt.prescriptionId != null && apt.prescriptionId!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.receipt_long_rounded,
                    color: AppColors.primary),
                tooltip: 'View Digital Prescription',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrescriptionViewerScreen(
                        prescriptionId: apt.prescriptionId!,
                      ),
                    ),
                  );
                },
              )
            else if (!isPatient)
              IconButton(
                icon: const Icon(Icons.post_add_rounded,
                    color: AppColors.primary),
                tooltip: 'Issue Prescription',
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => PrescriptionBuilderDialog(
                      appointment: apt,
                      onPrescriptionCreated: () {
                        ref.invalidate(userAppointmentsProvider);
                      },
                    ),
                  );
                },
              ),

          // Video Call Access
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: AppColors.primary),
            tooltip: 'Video Consultation',
            onPressed: () {
              context.push('/consultation/room/${apt?.id ?? widget.appointmentId}');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Chat Messages View Area
          Expanded(
            child: Container(
              color: AppColors.backgroundOf(context),
              child: messagesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (err, _) => Center(
                  child: Text('Error loading messages: $err',
                      style: TextStyle(color: textSecondary)),
                ),
                data: (streamMessages) {
                  // Clean up optimistic pending messages once present in streamMessages by ID
                  _optimisticPendingMessages.removeWhere((pending) =>
                      streamMessages.any((m) => m.id == pending.id));

                  // Merge stream messages with optimistic messages strictly by message ID.
                  final List<ChatMessageModel> allMessages =
                      List.from(streamMessages);
                  for (final pending in _optimisticPendingMessages) {
                    final alreadyInStream =
                        allMessages.any((m) => m.id == pending.id);
                    if (!alreadyInStream) {
                      allMessages.add(pending);
                    }
                  }

                  // Reverse sorting: Newest message at index 0 (bottom of screen)
                  allMessages.sort((a, b) {
                    final cmp = b.sentAtUtc.compareTo(a.sentAtUtc);
                    if (cmp != 0) return cmp;
                    return b.id.compareTo(a.id);
                  });

                  if (allMessages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 48, color: textSecondary.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isPatient
                                  ? 'Send a message to start your consultation with $participantName.'
                                  : 'Send a message to start your consultation with $participantName.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Option 1: WhatsApp / iMessage downward pull at bottom to dismiss keyboard.
                  // Scrolling UP through past messages never dismisses keyboard. Only an intentional
                  // physical downward swipe (dy > 0) at the bottom (newest messages) dismisses it.
                  return NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // Only check when at the bottom (offset <= 12.0)
                      final isAtBottom = !_scrollController.hasClients ||
                          _scrollController.offset <= 12.0;

                      if (isAtBottom) {
                        final dy = notification is ScrollUpdateNotification
                            ? notification.dragDetails?.delta.dy
                            : (notification is OverscrollNotification
                                ? notification.dragDetails?.delta.dy
                                : null);

                        // Physical screen coordinates: dy > 0 is dragging DOWN toward the keyboard
                        if (dy != null && dy > 2.5) {
                          FocusScope.of(context).unfocus();
                        } else if (notification is OverscrollNotification &&
                            notification.overscroll > 3.0) {
                          // In reverse: true lists, downward pull produces positive overscroll
                          FocusScope.of(context).unfocus();
                        }
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Index 0 is at bottom
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.manual,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: allMessages.length,
                      itemBuilder: (context, index) {
                        final msg = allMessages[index];
                        final isMe = msg.senderId == user?.id;
                        final isPending = msg.isPending ||
                            _optimisticPendingMessages
                                .any((p) => p.id == msg.id && p.isPending);
                        final isNewAnim = _animatingMessageIds.contains(msg.id);

                        final bubbleWidget = Align(
                          alignment:
                              isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? AppColors.primary
                                  : (isDark
                                      ? surfaceColor
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe
                                    ? const Radius.circular(16)
                                    : const Radius.circular(3),
                                bottomRight: isMe
                                    ? const Radius.circular(3)
                                    : const Radius.circular(16),
                              ),
                              border:
                                  isMe ? null : Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.content,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.35,
                                    color: isMe ? Colors.white : textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateTimeUtils.formatLocalTime(
                                          msg.sentAtUtc),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe
                                            ? Colors.white70
                                            : textSecondary.withOpacity(0.8),
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      if (isPending)
                                        const Icon(
                                          Icons.access_time_rounded,
                                          size: 13,
                                          color: Colors.white70,
                                        )
                                      else if (msg.isRead)
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

                        // Smooth entry animation:
                        // 1. Expanding heightFactor gently glides previous messages upward with zero jump
                        // 2. Physical rise translation (32 -> 0) moves the message up from the text field into the chat area
                        // 3. Gentle horizontal slide and scaling anchor it seamlessly into place
                        if (isNewAnim) {
                          return TweenAnimationBuilder<double>(
                            key: ValueKey(msg.id),
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                            onEnd: () {
                              _animatingMessageIds.remove(msg.id);
                            },
                            builder: (context, value, child) {
                              return ClipRect(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  heightFactor: value,
                                  child: Opacity(
                                    opacity: value.clamp(0.0, 1.0),
                                    child: Transform.translate(
                                      offset: Offset(
                                        isMe
                                            ? 26 * (1 - value)
                                            : -26 * (1 - value),
                                        32 * (1 - value),
                                      ),
                                      child: Transform.scale(
                                        scale: 0.92 + (0.08 * value),
                                        alignment: isMe
                                            ? Alignment.bottomRight
                                            : Alignment.bottomLeft,
                                        child: child,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: bubbleWidget,
                          );
                        }

                        return bubbleWidget;
                      },
                    ),
                  );
                },
              ),
            ),
          ),

          // Message Composer (flush with keyboard, fills iOS keyboard rounded corners, zero flicker)
          Container(
            color: surfaceColor,
            padding: EdgeInsets.only(bottom: dynamicBottomPadding),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (details) {
                // Swiping down on the textfield / composer area immediately closes the keyboard
                if ((details.primaryDelta ?? 0) > 2.5) {
                  FocusScope.of(context).unfocus();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(
                    top: BorderSide(
                        color: borderColor.withValues(alpha: 0.6), width: 1),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          keyboardType: TextInputType.multiline,
                          keyboardAppearance:
                              isDark ? Brightness.dark : Brightness.light,
                          textInputAction: TextInputAction.newline,
                          minLines: 1,
                          maxLines: 5,
                          style: TextStyle(color: textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: textSecondary.withOpacity(0.7),
                              fontSize: 13.5,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.backgroundOf(context)
                                : const Color(0xFFF8FAFC),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                  color: borderColor.withValues(alpha: 0.6)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Send Button centered vertically alongside the multiline field
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () =>
                              _handleSendMessage(effectiveChatId),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
