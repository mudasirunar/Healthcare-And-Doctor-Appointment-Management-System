import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/user_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import 'patient_appointment_detail_screen.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final String doctorId;

  const BookingScreen({super.key, required this.doctorId});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  late final Future<DoctorModel?> _doctorFuture;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _slotsSubscription;
  Set<String> _bookedSlotKeys = {};

  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedSlotUtc;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _conflictError;
  final List<GlobalKey> _dateKeys = List.generate(14, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    // Cache the doctor future upfront so setState never causes screen blink or reload
    _doctorFuture = ref.read(doctorRepositoryProvider).getDoctorById(widget.doctorId);

    // Stream real-time booked slots for this doctor from Firestore
    _slotsSubscription = FirebaseFirestore.instance
        .collection('slots')
        .where('doctorId', isEqualTo: widget.doctorId)
        .where('status', isEqualTo: 'booked')
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _bookedSlotKeys = snapshot.docs.map((doc) => doc.id).toSet();
        });
      },
      onError: (_) {
        // Fallback gracefully without breaking UI
      },
    );
  }

  @override
  void dispose() {
    _slotsSubscription?.cancel();
    _reasonController.dispose();
    super.dispose();
  }

  void _centerSelectedDate(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _dateKeys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Generates consultation slots for [_selectedDate]
  List<DateTime> _generateSlotsForDate(DoctorModel doctor, DateTime date) {
    final slots = <DateTime>[];
    final dayKey = DateFormat('EEEE').format(date).toLowerCase();
    final windows = doctor.weeklyAvailability[dayKey];

    if (windows == null || windows.isEmpty) {
      final morningStart = DateTime.utc(date.year, date.month, date.day, 9, 0);
      for (int i = 0; i < 8; i++) {
        slots.add(morningStart.add(Duration(minutes: i * 30)));
      }
      return slots;
    }

    for (var window in windows) {
      final startParts = window.start.split(':');
      final endParts = window.end.split(':');

      var current = DateTime.utc(
        date.year,
        date.month,
        date.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );

      final end = DateTime.utc(
        date.year,
        date.month,
        date.day,
        int.parse(endParts[0]),
        int.parse(endParts[1]),
      );

      while (current.isBefore(end)) {
        slots.add(current);
        current = current.add(Duration(minutes: doctor.slotDurationMinutes));
      }
    }

    return slots;
  }

  Future<void> _handleBookAppointment(DoctorModel doctor) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      AppSnackBar.showError(context, 'You must be signed in to book a consultation.');
      return;
    }

    if (_selectedSlotUtc == null) {
      AppSnackBar.showWarning(context, 'Please select an available consultation slot.');
      return;
    }

    // Double-check past-time restriction
    if (_selectedSlotUtc!.isBefore(DateTime.now().toUtc())) {
      AppSnackBar.showWarning(context, 'Cannot book a consultation slot in the past.');
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      AppSnackBar.showWarning(context, 'Please provide a brief reason for your visit.');
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BookingConfirmationSheet(
        doctor: doctor,
        slotUtc: _selectedSlotUtc!,
        reason: reason,
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
      _conflictError = null;
    });

    try {
      final aptRepo = ref.read(appointmentRepositoryProvider);
      final apt = await aptRepo.bookAppointment(
        patientId: user.id,
        patientName: user.displayName,
        patientEmail: user.email,
        doctorId: doctor.id,
        doctorName: doctor.doctorName,
        doctorSpecialty: doctor.specialtyName,
        scheduledTimeUtc: _selectedSlotUtc!,
        reasonForVisit: reason,
      );

      // Notify patient of booking request
      UserNotificationService.instance.sendPatientNotification(
        patientUserId: user.id,
        title: 'Booking Request Submitted',
        body: 'Your consultation with ${doctor.doctorName} was submitted for ${DateTimeUtils.formatFullWithTimeZone(_selectedSlotUtc!.toIso8601String())}.',
        type: 'appointment_requested',
        targetId: apt.id,
      );

      ref.invalidate(userAppointmentsProvider);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AppDialog(
            icon: Icons.check_circle_outline_rounded,
            tone: AppDialogTone.success,
            title: 'Consultation Confirmed',
            message:
                'Your consultation with ${doctor.doctorName} has been booked for ${DateTimeUtils.formatFullWithTimeZone(_selectedSlotUtc!.toIso8601String())}.',
            cancelLabel: 'Done',
            onCancel: () {
              Navigator.pop(ctx); // pop dialog
              Navigator.pop(context); // pop booking screen back to previous
            },
            confirmLabel: 'View',
            onConfirm: () {
              Navigator.pop(ctx); // pop dialog
              // Replace booking screen in navigation stack so pressing Back on details goes back cleanly
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientAppointmentDetailScreen(appointmentId: apt.id),
                ),
              );
            },
          ),
        );
      }
    } on SlotAlreadyBookedException catch (e) {
      setState(() {
        _conflictError = e.message;
        _selectedSlotUtc = null;
      });
      if (mounted) {
        AppSnackBar.showError(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Booking failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  'Book Appointment',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<DoctorModel?>(
        future: _doctorFuture, // Uses memoized future; no blink on slot/date selection!
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
          }
          final doctor = snapshot.data;
          if (doctor == null) {
            return const ErrorStateView(message: 'Doctor not found.');
          }

          final allSlots = _generateSlotsForDate(doctor, _selectedDate);
          final nowUtc = DateTime.now().toUtc();

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Doctor Detail Area (Flat directly on screen, no card container)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                              backgroundImage: doctor.avatarUrl != null
                                  ? NetworkImage(doctor.avatarUrl!)
                                  : null,
                              child: doctor.avatarUrl == null
                                  ? Text(
                                      doctor.doctorName.isNotEmpty
                                          ? doctor.doctorName
                                              .replaceFirst(RegExp(r'^Dr\.\s*'), '')
                                              .characters
                                              .first
                                              .toUpperCase()
                                          : 'D',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          doctor.doctorName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: textPrimary,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, size: 15, color: AppColors.primary),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    doctor.specialtyName,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 2),
                                      Text(
                                        doctor.rating.toStringAsFixed(1),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      Text(
                                        ' (${doctor.reviewCount})',
                                        style: TextStyle(fontSize: 11, color: textSecondary),
                                      ),
                                      const SizedBox(width: 6),
                                      Text('•', style: TextStyle(color: textSecondary, fontSize: 11)),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${doctor.experienceYears}y exp',
                                        style: TextStyle(fontSize: 11.5, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Consultation Fee (Flat minimal display)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${doctor.consultationFee.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  'per visit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: borderColor),
                      const SizedBox(height: 16),

                      // Conflict Banner (only shown if a race condition occurred)
                      if (_conflictError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.error),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppColors.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _conflictError!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Date Picker Strip (14 days, auto-centering)
                      Text(
                        'Select Date',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 76,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: List.generate(14, (index) {
                              final day = DateTime.now().add(Duration(days: index));
                              final isSelected = day.year == _selectedDate.year &&
                                  day.month == _selectedDate.month &&
                                  day.day == _selectedDate.day;

                              String subtitle;
                              if (index == 0) {
                                subtitle = 'Today';
                              } else if (index == 1) {
                                subtitle = 'Tomorrow';
                              } else {
                                subtitle = DateFormat('EEE').format(day);
                              }

                              return Padding(
                                key: _dateKeys[index],
                                padding: EdgeInsets.only(right: index == 13 ? 0 : 8),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedDate = day;
                                      _selectedSlotUtc = null;
                                      _conflictError = null;
                                    });
                                    _centerSelectedDate(index);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 68,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : surfaceColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : borderColor,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          subtitle,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected ? Colors.white70 : textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          DateFormat('d').format(day),
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected ? Colors.white : textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Time Slots Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Available Slots',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            '${allSlots.length} Total',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Slots Chips Grid
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: allSlots.map((slotUtc) {
                          final slotKey = DateTimeUtils.generateSlotKey(doctor.id, slotUtc);
                          final isBooked = _bookedSlotKeys.contains(slotKey);
                          final isPast = slotUtc.isBefore(nowUtc);
                          final isUnavailable = isBooked || isPast;
                          final isSelected = _selectedSlotUtc != null &&
                              _selectedSlotUtc!.isAtSameMomentAs(slotUtc);
                          final timeLabel =
                              DateTimeUtils.formatLocalTime(slotUtc.toIso8601String());

                          if (isUnavailable) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? surfaceColor.withOpacity(0.2)
                                    : const Color(0xFFF1F5F9).withOpacity(0.7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor.withOpacity(0.35)),
                              ),
                              child: Text(
                                timeLabel,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: textSecondary.withOpacity(0.35),
                                  decoration: isBooked ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            );
                          }

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedSlotUtc = slotUtc;
                                _conflictError = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : surfaceColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : borderColor,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                timeLabel,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isSelected ? Colors.white : textPrimary,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),

                      // Reason for Visit
                      Text(
                        'Reason for Visit',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        style: TextStyle(color: textPrimary, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText:
                              'Briefly describe your symptoms or reason for consulting...',
                          hintStyle:
                              TextStyle(color: textSecondary.withOpacity(0.6), fontSize: 13),
                          filled: true,
                          fillColor: surfaceColor,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Pinned Bottom Button Bar with Safe Area Spacing
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(top: BorderSide(color: borderColor, width: 1)),
                ),
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (_isSubmitting || _selectedSlotUtc == null)
                            ? null
                            : () => _handleBookAppointment(doctor),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white70,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _selectedSlotUtc == null
                                    ? 'Select a Time Slot'
                                    : 'Review & Confirm Booking',
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BookingConfirmationSheet extends StatelessWidget {
  final DoctorModel doctor;
  final DateTime slotUtc;
  final String reason;

  const _BookingConfirmationSheet({
    required this.doctor,
    required this.slotUtc,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Booking Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          _SummaryRow(label: 'Doctor', value: doctor.doctorName),
          _SummaryRow(label: 'Specialty', value: doctor.specialtyName),
          _SummaryRow(
            label: 'Scheduled Time',
            value: DateTimeUtils.formatFullWithTimeZone(slotUtc.toIso8601String()),
          ),
          _SummaryRow(label: 'Duration', value: '${doctor.slotDurationMinutes} Minutes'),
          _SummaryRow(
              label: 'Consultation Fee',
              value: '\$${doctor.consultationFee.toStringAsFixed(0)}'),
          _SummaryRow(label: 'Reason', value: reason),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textSecondary,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
