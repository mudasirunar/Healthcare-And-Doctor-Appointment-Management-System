enum AdminNotificationType {
  doctorVerification,
  appointmentActivity,
  prescriptionIssued,
}

/// Represents an item in the Admin Notification Center.
class AdminNotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final String timestampIso;
  final AdminNotificationType type;
  final String targetId;
  final bool isActionable;
  final String statusLabel;

  const AdminNotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestampIso,
    required this.type,
    required this.targetId,
    required this.isActionable,
    required this.statusLabel,
  });
}

