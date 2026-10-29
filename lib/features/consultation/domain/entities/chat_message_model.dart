class ChatMessageModel {
  final String id;
  final String appointmentId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'patient' | 'doctor'
  final String content;
  final String sentAtUtc;

  const ChatMessageModel({
    required this.id,
    required this.appointmentId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.sentAtUtc,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'content': content,
      'sentAtUtc': sentAtUtc,
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
    );
  }
}
