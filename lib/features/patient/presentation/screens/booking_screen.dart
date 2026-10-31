import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
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

  /// Generates 30-minute consultation slots for [_selectedDate]
  List<DateTime> _generateSlotsForDate(DoctorModel doctor, DateTime date) {
    final slots = <DateTime>[];
    // Weekday string
    final dayKey = DateFormat('EEEE').format(date).toLowerCase();
    final windows = doctor.weeklyAvailability[dayKey];

    if (windows == null || windows.isEmpty) {
      // Default standard hours if day not explicitly defined
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
      context.push('/login');
      return;
    }

    if (_selectedSlotUtc == null) {
      AppSnackBar.showWarning(
        context,
        'Please select an available time slot.',
      );
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      AppSnackBar.showWarning(
        context,
        'Please enter a brief reason for your consultation.',
      );
      return;
    }

    // Show Confirmation Bottom Sheet
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
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
      final appointment = await aptRepo.bookAppointment(
        patientId: user.id,
        patientName: user.displayName,
        patientEmail: user.email,
        doctorId: doctor.id,
        doctorName: doctor.doctorName,
        doctorSpecialty: doctor.specialtyName,
        scheduledTimeUtc: _selectedSlotUtc!,
        reasonForVisit: reason,
        durationMinutes: doctor.slotDurationMinutes,
      );

      ref.invalidate(userAppointmentsProvider);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                SizedBox(width: 10),
                Text('Booking Successful!'),
              ],
            ),
            content: Text(
              'Your appointment request (#${appointment.id}) has been submitted to ${doctor.doctorName}. You can track status changes in My Appointments.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/patient/appointments');
                },
                child: const Text('View Appointments'),
              ),
            ],
          ),
        );
      }
    } on SlotAlreadyBookedException catch (e) {
      // Challenge #1: Collision Handling
      setState(() {
        _conflictError = e.message;
        _selectedSlotUtc = null; // Reset selection so user can pick another
      });
    } catch (e) {
      setState(() {
        _conflictError = 'Booking failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorRepo = ref.watch(doctorRepositoryProvider);
    final aptRepo = ref.watch(appointmentRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Appointment Slot'),
      ),
      body: FutureBuilder<DoctorModel?>(
        future: doctorRepo.getDoctorById(widget.doctorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final doctor = snapshot.data;
          if (doctor == null) {
            return const ErrorStateView(message: 'Doctor not found.');
          }

          final slots = _generateSlotsForDate(doctor, _selectedDate);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          doctor.doctorName[0],
                          style: AppTypography.headline.copyWith(color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doctor.doctorName, style: AppTypography.headline.copyWith(fontSize: 16)),
                            Text(doctor.specialtyName, style: AppTypography.caption.copyWith(color: AppColors.primary)),
                          ],
                        ),
                      ),
                      Text(
                        '\$${doctor.consultationFee.toStringAsFixed(0)}',
                        style: AppTypography.headline.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Conflict Banner (Challenge #1)
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
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _conflictError!,
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Timezone Notice (Challenge #2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.public_rounded, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Timezone: ${DateTimeUtils.getTimeZoneName()} (Slots dynamically adjusted to your local time)',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Date Picker Strip (14 days, auto-centers selected date)
                const Text('Select Date', style: AppTypography.headline),
                const SizedBox(height: 12),
                SizedBox(
                  height: 84,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
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
                            child: Container(
                              width: 68,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    DateFormat('EEE').format(day),
                                    style: AppTypography.caption.copyWith(
                                      color: isSelected
                                          ? Colors.white70
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('d').format(day),
                                    style: AppTypography.headline.copyWith(
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
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
                const SizedBox(height: 24),

                // Time Slots Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available Slots', style: AppTypography.headline),
                    Text(
                      '${slots.length} slots',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
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
                            color: AppColors.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border.withOpacity(0.5)),
                          ),
                          child: Text(
                            '$timeLabel (Booked)',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          timeLabel,
                          style: AppTypography.button.copyWith(
                            fontSize: 13,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Reason for visit
                const Text('Reason for Visit', style: AppTypography.headline),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Briefly describe your symptoms or reason for consulting...',
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _handleBookAppointment(doctor),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Review & Confirm Booking'),
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Booking Summary', style: AppTypography.display),
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
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
