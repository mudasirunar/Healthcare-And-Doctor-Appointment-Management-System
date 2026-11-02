import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../doctor/domain/entities/doctor_model.dart';

class DoctorAvailabilityScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final bool isStandalone;

  const DoctorAvailabilityScreen({
    super.key,
    this.scrollController,
    this.isStandalone = false,
  });

  @override
  ConsumerState<DoctorAvailabilityScreen> createState() =>
      _DoctorAvailabilityScreenState();
}

class _DoctorAvailabilityScreenState
    extends ConsumerState<DoctorAvailabilityScreen> {
  final Map<String, bool> _activeDays = {
    'monday': true,
    'tuesday': true,
    'wednesday': true,
    'thursday': true,
    'friday': true,
    'saturday': false,
    'sunday': false,
  };

  String _startTime = '09:00';
  String _endTime = '17:00';
  int _slotDurationMinutes = 30;
  final List<String> _blackoutDates = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final doctor =
        await ref.read(doctorRepositoryProvider).getDoctorByUserId(user.id);
    if (doctor != null && mounted) {
      setState(() {
        _slotDurationMinutes = doctor.slotDurationMinutes;
        // Parse active days
        for (final day in _activeDays.keys) {
          final windows = doctor.weeklyAvailability[day];
          if (windows != null && windows.isNotEmpty) {
            _activeDays[day] = true;
            _startTime = windows.first.start;
            _endTime = windows.first.end;
          } else {
            _activeDays[day] = false;
          }
        }
        _blackoutDates.clear();
        _blackoutDates.addAll(doctor.blackoutDates);
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final current = isStart ? _startTime : _endTime;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          _startTime = formatted;
        } else {
          _endTime = formatted;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final doctorRepo = ref.watch(doctorRepositoryProvider);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    final content = ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: [
        // Notice banner (Flat)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Configured hours define the consultation slots available for patient booking.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 1. Consultation Slot Duration
        Text(
          'Consultation Slot Duration',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [15, 30, 45, 60].map((mins) {
            final isSelected = _slotDurationMinutes == mins;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$mins min'),
                selected: isSelected,
                onSelected: (val) {
                  if (val) setState(() => _slotDurationMinutes = mins);
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),

        // 2. Active Working Days
        Text(
          'Active Working Days',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: _activeDays.keys.map((day) {
              final isChecked = _activeDays[day] ?? false;
              final capitalized = day[0].toUpperCase() + day.substring(1);

              return SwitchListTile(
                title: Text(
                  capitalized,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                value: isChecked,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _activeDays[day] = val);
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 22),

        // 3. Shift Timing
        Text(
          'Daily Shift Hours',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectTime(true),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shift Start',
                            style:
                                TextStyle(fontSize: 11, color: textSecondary)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _startTime,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const Icon(Icons.access_time_rounded,
                                size: 16, color: AppColors.primary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _selectTime(false),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shift End',
                            style:
                                TextStyle(fontSize: 11, color: textSecondary)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _endTime,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const Icon(Icons.access_time_rounded,
                                size: 16, color: AppColors.primary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // 4. Blackout Days
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Time Off & Blackout Dates',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) {
                  final str =
                      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  if (!_blackoutDates.contains(str)) {
                    setState(() => _blackoutDates.add(str));
                  }
                }
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Date'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_blackoutDates.isEmpty)
          Text(
            'No blackout dates scheduled. You are open for all active working days.',
            style: TextStyle(color: textSecondary, fontSize: 12.5),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _blackoutDates.map((date) {
              return Chip(
                label: Text(date, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () {
                  setState(() => _blackoutDates.remove(date));
                },
              );
            }).toList(),
          ),
        const SizedBox(height: 28),

        // Save Button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving
                ? null
                : () async {
                    if (user == null) return;
                    setState(() => _isSaving = true);
                    try {
                      final doc = await doctorRepo.getDoctorByUserId(user.id);
                      if (doc != null) {
                        final newAvailability = <String, List<TimeWindow>>{};
                        _activeDays.forEach((day, isActive) {
                          if (isActive) {
                            newAvailability[day] = [
                              TimeWindow(start: _startTime, end: _endTime),
                            ];
                          }
                        });

                        await doctorRepo.updateDoctorAvailability(
                          doc.id,
                          newAvailability,
                          _blackoutDates,
                        );

                        // Also update slot duration if changed
                        if (doc.slotDurationMinutes != _slotDurationMinutes) {
                          await doctorRepo.updateDoctorProfile(
                            doc.copyWith(
                                slotDurationMinutes: _slotDurationMinutes),
                          );
                        }
                      }
                      if (context.mounted) {
                        AppSnackBar.showSuccess(
                          context,
                          'Working hours and schedule saved!',
                        );
                        if (widget.isStandalone) {
                          Navigator.pop(context);
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppSnackBar.showError(context, 'Failed to save: $e');
                      }
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Save Working Schedule',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
          ),
        ),
      ],
    );

    if (widget.isStandalone) {
      return Scaffold(
        backgroundColor: AppColors.backgroundOf(context),
        appBar: AppBar(
          title: const Text('Availability & Working Hours'),
          backgroundColor: surfaceColor,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: content,
      );
    }

    return content;
  }
}
