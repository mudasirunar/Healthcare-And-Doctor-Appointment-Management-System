/// Base exception for Healthcare App
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Thrown when an appointment slot has already been taken (Challenge #1: Concurrency Conflict)
class SlotAlreadyBookedException extends AppException {
  const SlotAlreadyBookedException([
    super.message = 'The selected appointment slot has already been reserved. Please pick another slot.',
  ]) : super(code: 'SLOT_ALREADY_BOOKED');
}

/// Thrown when an invalid status transition is attempted (Challenge #3: State Machine)
class InvalidStateTransitionException extends AppException {
  final String fromStatus;
  final String toStatus;

  const InvalidStateTransitionException(this.fromStatus, this.toStatus, [String? detail])
      : super(
          detail ?? 'Cannot transition appointment from "$fromStatus" to "$toStatus".',
          code: 'INVALID_STATE_TRANSITION',
        );
}

/// Thrown when a cancellation violates eligibility rules (e.g. less than 2 hours before scheduled time)
class CancellationNotAllowedException extends AppException {
  const CancellationNotAllowedException([
    super.message = 'Appointments can only be cancelled at least 2 hours before the scheduled time.',
  ]) : super(code: 'CANCELLATION_NOT_ALLOWED');
}

/// Thrown for authentication & authorization failures (Challenge #5: Privacy & Permissions)
class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

/// Thrown for resource not found errors
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.code = 'NOT_FOUND'});
}
