import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../doctor/domain/entities/doctor_model.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final String doctorId;

  const BookingScreen({super.key, required this.doctorId});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedSlotUtc;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _conflictError;
  final List<GlobalKey> _dateKeys = List.generate(14, (_) => GlobalKey());

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

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
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
      await aptRepo.bookAppointment(
        patientId: user.id,
        patientName: user.displayName,
        patientEmail: user.email,
        doctorId: doctor.id,
        doctorName: doctor.doctorName,
        doctorSpecialty: doctor.specialtyName,
        scheduledTimeUtc: _selectedSlotUtc!,
        reasonForVisit: reason,
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
            confirmLabel: 'View Appointments',
            onConfirm: () {
              Navigator.pop(ctx);
              context.go('/patient/appointments');
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
    final doctorRepo = ref.watch(doctorRepositoryProvider);
    final aptRepo = ref.watch(appointmentRepositoryProvider);
    final isDark = AppColors.isDark(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
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
                  'Select Appointment Slot',
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
        future: doctorRepo.getDoctorById(widget.doctorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
          }
          final doctor = snapshot.data;
          if (doctor == null) {
            return const ErrorStateView(message: 'Doctor not found.');
          }

          final slots = _generateSlotsForDate(doctor, _selectedDate);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor Summary Card (Flat)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: doctor.avatarUrl != null
                            ? NetworkImage(doctor.avatarUrl!)
                            : null,
                        child: doctor.avatarUrl == null
                            ? Text(
                                doctor.doctorName.isNotEmpty ? doctor.doctorName[0].toUpperCase() : 'D',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctor.doctorName,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              doctor.specialtyName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${doctor.consultationFee.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Conflict Banner
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
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
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
                  const SizedBox(height: 16),
                ],

                // Timezone Notice
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? surfaceColor : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.public_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Timezone: ${DateTimeUtils.getTimeZoneName()} (Slots dynamically adjusted to your local time)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Date Picker Strip (14 days, auto-centers selected date)
                Text(
                  'Select Date',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 80,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: List.generate(14, (index) {
                        final day = DateTime.now().add(Duration(days: index));
                        final isSelected = day.year == _selectedDate.year &&
                            day.month == _selectedDate.month &&
                            day.day == _selectedDate.day;

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
                              width: 66,
                              padding: const EdgeInsets.symmetric(vertical: 10),
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
                                    DateFormat('EEE').format(day),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white70 : textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('d').format(day),
                                    style: TextStyle(
                                      fontSize: 18,
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
                const SizedBox(height: 22),

                // Time Slots Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Slots',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      '${slots.length} slots',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: slots.map((slotUtc) {
                    final isBooked = aptRepo.isSlotBooked(doctor.id, slotUtc);
                    final isSelected = _selectedSlotUtc != null &&
                        _selectedSlotUtc!.isAtSameMomentAs(slotUtc);
                    final timeLabel = DateTimeUtils.formatLocalTime(slotUtc.toIso8601String());

                    if (isBooked) {
                      return Tooltip(
                        message: 'Already reserved by another patient',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? surfaceColor.withOpacity(0.4) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            '$timeLabel (Booked)',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary.withOpacity(0.6),
                              decoration: TextDecoration.lineThrough,
                            ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                const SizedBox(height: 24),

                // Reason for visit
                Text(
                  'Reason for Visit',
                  style: TextStyle(
                    fontSize: 15.5,
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
                    hintText: 'Briefly describe your symptoms or reason for consulting...',
                    hintStyle: TextStyle(color: textSecondary.withOpacity(0.7), fontSize: 13),
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
                const SizedBox(height: 28),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _handleBookAppointment(doctor),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Review & Confirm Booking',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
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
          _SummaryRow(label: 'Consultation Fee', value: '\$${doctor.consultationFee.toStringAsFixed(0)}'),
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
