import 'package:intl/intl.dart';

/// Utilities for timezone-safe date and time formatting and calculations (Challenge #2)
class DateTimeUtils {
  DateTimeUtils._();

  /// Converts any DateTime to an ISO-8601 UTC string for storage
  static String toUtcIsoString(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String();
  }

  /// Parses an ISO-8601 UTC string and converts it to the user's local timezone
  static DateTime parseUtcToLocal(String utcIsoString) {
    return DateTime.parse(utcIsoString).toLocal();
  }

  /// Formats UTC string to local date: e.g. "Mon, Nov 2, 2026"
  static String formatLocalDate(String utcIsoString) {
    final local = parseUtcToLocal(utcIsoString);
    return DateFormat('EEE, MMM d, yyyy').format(local);
  }

  /// Formats UTC string to local time: e.g. "09:30 AM"
  static String formatLocalTime(String utcIsoString) {
    final local = parseUtcToLocal(utcIsoString);
    return DateFormat('h:mm a').format(local);
  }

  /// Formats UTC string to full human-readable string with local timezone label:
  /// e.g. "Nov 2, 2026 • 9:30 AM (PKT)"
  static String formatFullWithTimeZone(String utcIsoString) {
    final local = parseUtcToLocal(utcIsoString);
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(local);
    final tz = getTimeZoneName(local);
    return '$dateStr ($tz)';
  }

  /// Gets local time zone abbreviation or offset label
  static String getTimeZoneName([DateTime? dateTime]) {
    final dt = dateTime ?? DateTime.now();
    final name = dt.timeZoneName;
    if (name.isNotEmpty) return name;
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  /// Generates a deterministic slot document ID from doctorId and UTC DateTime:
  /// Format: {doctorId}_{yyyyMMddTHHmm} (e.g. doc123_20261102T0900)
  static String generateSlotKey(String doctorId, DateTime slotUtc) {
    final utc = slotUtc.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final min = utc.minute.toString().padLeft(2, '0');
    return '${doctorId}_$y$m${d}T$h$min';
  }

  /// Determines if an appointment at [scheduledTimeUtcString] is eligible for patient cancellation.
  /// Rule: Can only cancel if scheduled time is at least 2 hours in the future.
  static bool isEligibleForCancellation(String scheduledTimeUtcString) {
    final scheduledUtc = DateTime.parse(scheduledTimeUtcString).toUtc();
    final nowUtc = DateTime.now().toUtc();
    return scheduledUtc.isAfter(nowUtc.add(const Duration(hours: 2)));
  }

  /// Returns remaining hours until appointment from now
  static double hoursUntil(String scheduledTimeUtcString) {
    final scheduledUtc = DateTime.parse(scheduledTimeUtcString).toUtc();
    final nowUtc = DateTime.now().toUtc();
    return scheduledUtc.difference(nowUtc).inMinutes / 60.0;
  }

  /// Formats UTC string to human-friendly relative time e.g. "Just now", "5m ago", "2h ago", "Yesterday", "Nov 2"
  static String formatRelativeTime(String utcIsoString) {
    try {
      final dt = DateTime.parse(utcIsoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) {
        return 'Just now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return DateFormat('MMM d').format(dt);
      }
    } catch (_) {
      return utcIsoString;
    }
  }
}
