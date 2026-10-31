import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/utils/date_time_utils.dart';
import 'appointment_model.dart';

/// Formally validated state machine for Appointment lifecycle (Challenge #3)
class AppointmentStateMachine {
  AppointmentStateMachine._();

  /// Maps each status to its allowed subsequent target statuses
  static const Map<AppointmentStatus, Set<AppointmentStatus>> _allowedTransitions = {
    AppointmentStatus.requested: {
      AppointmentStatus.confirmed,
      AppointmentStatus.rejected,
      AppointmentStatus.cancelled,
    },
    AppointmentStatus.confirmed: {
      AppointmentStatus.inProgress,
      AppointmentStatus.cancelled,
    },
    AppointmentStatus.inProgress: {
      AppointmentStatus.completed,
      AppointmentStatus.cancelled,
    },
    AppointmentStatus.completed: {},
    AppointmentStatus.cancelled: {},
    AppointmentStatus.rejected: {},
  };

  /// Returns whether a transition from [current] to [target] is structurally valid
  static bool canTransition(AppointmentStatus current, AppointmentStatus target) {
    final targets = _allowedTransitions[current];
    return targets != null && targets.contains(target);
  }

  /// Validates and applies a status transition, creating a new updated AppointmentModel
  /// with an immutable history audit entry.
  static AppointmentModel transition({
    required AppointmentModel appointment,
    required AppointmentStatus targetStatus,
    required String actorUserId,
    bool isPatientActor = false,
    String? note,
    String? cancellationReason,
  }) {
    final currentStatus = appointment.status;

    // 1. Structural transition validation
    if (!canTransition(currentStatus, targetStatus)) {
      throw InvalidStateTransitionException(
        currentStatus.name,
        targetStatus.name,
        'Cannot transition from ${currentStatus.displayName} to ${targetStatus.displayName}.',
      );
    }

    // 2. Cancellation eligibility enforcement
    if (targetStatus == AppointmentStatus.cancelled && isPatientActor) {
      if (!DateTimeUtils.isEligibleForCancellation(appointment.scheduledTimeUtc)) {
        throw const CancellationNotAllowedException(
          'Patients can only cancel appointments at least 2 hours before the scheduled time.',
        );
      }
    }

    final nowUtc = DateTime.now().toUtc().toIso8601String();

    final newHistoryEntry = StatusHistoryEntry(
      status: targetStatus,
      timestampUtc: nowUtc,
      byUserId: actorUserId,
      note: note ?? (cancellationReason != null ? 'Reason: $cancellationReason' : null),
    );

    return appointment.copyWith(
      status: targetStatus,
      statusHistory: [...appointment.statusHistory, newHistoryEntry],
      cancellationReason: targetStatus == AppointmentStatus.cancelled
          ? (cancellationReason ?? note)
          : appointment.cancellationReason,
      updatedAt: nowUtc,
    );
  }
}
