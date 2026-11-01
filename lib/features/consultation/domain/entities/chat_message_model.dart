class ChatMessageModel {
  final String id;
  final String appointmentId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'patient' | 'doctor'
  final String content;
  final String sentAtUtc;
  final bool isDelivered;
  final bool isRead;

  const ChatMessageModel({
    required this.id,
    required this.appointmentId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.sentAtUtc,
    this.isDelivered = false,
    this.isRead = false,
  });

  ChatMessageModel copyWith({
    String? id,
    String? appointmentId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? content,
    String? sentAtUtc,
    bool? isDelivered,
    bool? isRead,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      content: content ?? this.content,
      sentAtUtc: sentAtUtc ?? this.sentAtUtc,
      isDelivered: isDelivered ?? this.isDelivered,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'content': content,
      'sentAtUtc': sentAtUtc,
      'isDelivered': isDelivered,
      'isRead': isRead,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return ChatMessageModel(
      id: id ?? map['id'] as String? ?? '',
      appointmentId: map['appointmentId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      senderRole: map['senderRole'] as String? ?? 'patient',
      content: map['content'] as String? ?? '',
      sentAtUtc: map['sentAtUtc'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      isDelivered: map['isDelivered'] as bool? ?? false,
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}
