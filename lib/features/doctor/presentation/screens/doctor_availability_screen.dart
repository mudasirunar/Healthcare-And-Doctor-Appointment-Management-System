import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare_app/core/providers/app_providers.dart';
import 'package:healthcare_app/core/theme/app_colors.dart';
import 'package:healthcare_app/core/theme/app_typography.dart';
import 'package:healthcare_app/core/widgets/app_snack_bar.dart';
import 'package:healthcare_app/features/doctor/domain/entities/doctor_model.dart';

class DoctorAvailabilityScreen extends ConsumerStatefulWidget {
  const DoctorAvailabilityScreen({super.key});

  @override
  ConsumerState<DoctorAvailabilityScreen> createState() => _DoctorAvailabilityScreenState();
}

class _DoctorAvailabilityScreenState extends ConsumerState<DoctorAvailabilityScreen> {
  final Map<String, bool> _activeDays = {
    'monday': true,
    'tuesday': true,
    'wednesday': true,
    'thursday': true,
    'friday': true,
    'saturday': false,
    'sunday': false,
  };

  final String _startTime = '09:00';
  final String _endTime = '17:00';
  final List<String> _blackoutDates = [];
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final doctorRepo = ref.watch(doctorRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Availability & Working Hours'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Configured hours define the slots available to patients on the booking calendar.',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Working Days
            const Text('Active Working Days', style: AppTypography.headline),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: _activeDays.keys.map((day) {
                  final isChecked = _activeDays[day] ?? false;
                  final capitalized = day[0].toUpperCase() + day.substring(1);

                  return SwitchListTile(
                    title: Text(capitalized, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    value: isChecked,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        _activeDays[day] = val;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Shift Hours
            const Text('Daily Shift Timing', style: AppTypography.headline),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Shift Start', style: AppTypography.caption),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_startTime, style: AppTypography.headline.copyWith(fontSize: 16)),
                              const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Shift End', style: AppTypography.caption),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_endTime, style: AppTypography.headline.copyWith(fontSize: 16)),
                              const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Blackout Dates
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Blackout Days (Vacation / Leave)', style: AppTypography.headline),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      final str = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
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
            const SizedBox(height: 8),
            if (_blackoutDates.isEmpty)
              Text(
                'No blackout dates scheduled. You are open for all standard working days.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _blackoutDates.map((date) {
                  return Chip(
                    label: Text(date),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    onDeleted: () {
                      setState(() => _blackoutDates.remove(date));
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 32),

            ElevatedButton(
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
                        }
                        if (context.mounted) {
                          AppSnackBar.showSuccess(
                            context,
                            'Availability schedule saved successfully!',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    },
              child: _isSaving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Availability'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
