import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare_app/core/providers/app_providers.dart';
import 'package:healthcare_app/core/theme/app_colors.dart';
import 'package:healthcare_app/core/theme/app_typography.dart';
import 'package:healthcare_app/core/utils/date_time_utils.dart';
import 'package:healthcare_app/core/widgets/state_views.dart';
import 'package:healthcare_app/features/consultation/domain/entities/chat_message_model.dart';

class AppointmentChatScreen extends ConsumerStatefulWidget {
  final String appointmentId;

  const AppointmentChatScreen({super.key, required this.appointmentId});

  @override
  ConsumerState<AppointmentChatScreen> createState() => _AppointmentChatScreenState();
}

class _AppointmentChatScreenState extends ConsumerState<AppointmentChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final aptRepo = ref.read(appointmentRepositoryProvider);
    final msgs = await aptRepo.getMessages(widget.appointmentId);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      _scrollToBottom();
    }
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

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    _messageController.clear();
    final aptRepo = ref.read(appointmentRepositoryProvider);

    final sentMsg = await aptRepo.sendMessage(
      appointmentId: widget.appointmentId,
      senderId: user.id,
      senderName: user.displayName,
      senderRole: user.role.name,
      content: text,
    );

    setState(() {
      _messages.add(sentMsg);
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Consultation Chat', style: TextStyle(fontSize: 16)),
            Text(
              'Encrypted • Scoped to #${widget.appointmentId}',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No Messages Yet',
                        description: 'Send a message to your healthcare provider or patient regarding this appointment.',
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = user?.id == msg.senderId;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? AppColors.primary : AppColors.surface,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: isMe ? const Radius.circular(14) : Radius.zero,
                                  bottomRight: isMe ? Radius.zero : const Radius.circular(14),
                                ),
                                border: isMe ? null : Border.all(color: AppColors.border),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x05000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.senderName,
                                    style: AppTypography.caption.copyWith(
                                      color: isMe ? Colors.white70 : AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg.content,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: isMe ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateTimeUtils.formatLocalTime(msg.sentAtUtc),
                                    style: AppTypography.caption.copyWith(
                                      color: isMe ? Colors.white60 : AppColors.textMuted,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _handleSendMessage,
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary),
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
