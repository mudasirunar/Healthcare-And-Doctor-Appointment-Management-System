import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/user_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../consultation/domain/entities/prescription_model.dart';

/// Dedicated, full-screen prescription builder for doctors.
/// Provides rich, theme-adaptive text fields, medication list management,
/// and instant clinical finalization for consultations.
class DoctorPrescriptionScreen extends ConsumerStatefulWidget {
  final AppointmentModel appointment;
  final VoidCallback? onPrescriptionCreated;

  const DoctorPrescriptionScreen({
    super.key,
    required this.appointment,
    this.onPrescriptionCreated,
  });

  @override
  ConsumerState<DoctorPrescriptionScreen> createState() =>
      _DoctorPrescriptionScreenState();
}

class _DoctorPrescriptionScreenState
    extends ConsumerState<DoctorPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();

  // Medication inputs
  final _medNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController =
      TextEditingController(text: 'Twice daily after meals');
  final _durationController = TextEditingController(text: '5 days');
  final _instructionsController = TextEditingController();

  final List<MedicationItem> _medications = [];
  bool _isSubmitting = false;

  final List<String> _quickFrequencies = [
    'Once daily (morning)',
    'Twice daily after meals',
    'Three times daily',
    'Every 8 hours',
    'At bedtime',
    'As needed (PRN)',
  ];

  final List<String> _quickDurations = [
    '3 days',
    '5 days',
    '7 days',
    '10 days',
    '14 days',
    '1 month',
  ];

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    _medNameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _addMedication() {
    final name = _medNameController.text.trim();
    final dosage = _dosageController.text.trim();

    if (name.isEmpty) {
      AppSnackBar.showWarning(
        context,
        'Please enter the medication name.',
      );
      return;
    }

    if (dosage.isEmpty) {
      AppSnackBar.showWarning(
        context,
        'Please specify the dosage (e.g. 500mg, 10ml).',
      );
      return;
    }

    setState(() {
      _medications.add(
        MedicationItem(
          name: name,
          dosage: dosage,
          frequency: _frequencyController.text.trim().isNotEmpty
              ? _frequencyController.text.trim()
              : 'Twice daily',
          duration: _durationController.text.trim().isNotEmpty
              ? _durationController.text.trim()
              : '5 days',
          instructions: _instructionsController.text.trim().isNotEmpty
              ? _instructionsController.text.trim()
              : null,
        ),
      );

      _medNameController.clear();
      _dosageController.clear();
      _instructionsController.clear();
    });

    AppSnackBar.showSuccess(
      context,
      'Added "$name" to prescription.',
    );
  }

  Future<void> _handleIssuePrescription() async {
    final diagnosis = _diagnosisController.text.trim();
    if (diagnosis.isEmpty) {
      AppSnackBar.showWarning(
        context,
        'Please provide a clinical diagnosis before issuing.',
      );
      return;
    }

    if (_medications.isEmpty) {
      AppSnackBar.showWarning(
        context,
        'Please add at least one prescribed medication.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      final aptRepo = ref.read(appointmentRepositoryProvider);
      final rxId = 'rx_${const Uuid().v4().substring(0, 8)}';

      final prescription = PrescriptionModel(
        id: rxId,
        appointmentId: widget.appointment.id,
        patientId: widget.appointment.patientId,
        patientName: widget.appointment.patientName,
        doctorId: widget.appointment.doctorId,
        doctorName: widget.appointment.doctorName,
        doctorSpecialty: widget.appointment.doctorSpecialty,
        diagnosis: diagnosis,
        medications: List.from(_medications),
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        issuedAtUtc: DateTime.now().toUtc().toIso8601String(),
      );

      // 1. Save prescription record
      await aptRepo.createPrescription(prescription);

      // 2. Mark consultation appointment completed
      await aptRepo.updateStatus(
        appointmentId: widget.appointment.id,
        targetStatus: AppointmentStatus.completed,
        actorUserId: user?.id ?? widget.appointment.doctorId,
        note:
            'Doctor issued digital prescription ($rxId) and concluded consultation.',
      );

      // 3. Dispatch patient notification
      UserNotificationService.instance.sendPatientNotification(
        patientUserId: widget.appointment.patientId,
        title: 'Digital Prescription Issued',
        body:
            'Dr. ${widget.appointment.doctorName} has issued your official digital prescription.',
        type: 'prescription_issued',
        targetId: widget.appointment.id,
      );

      widget.onPrescriptionCreated?.call();

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Digital prescription issued & consultation completed!',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Failed to finalize prescription: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final surfaceVariant = AppColors.surfaceVariantOf(context);
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Digital Prescription'),
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Patient & Session Context Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primary
                                  .withValues(alpha: 0.12),
                              child: Text(
                                widget.appointment.patientName.isNotEmpty
                                    ? widget.appointment.patientName[0]
                                        .toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.appointment.patientName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondary
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Rx Builder',
                                          style: TextStyle(
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Booking #${widget.appointment.id.length > 8 ? widget.appointment.id.substring(0, 8).toUpperCase() : widget.appointment.id.toUpperCase()} • ${DateTimeUtils.formatLocalDate(widget.appointment.scheduledTimeUtc)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Doctor: ${widget.appointment.doctorName} (${widget.appointment.doctorSpecialty})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. Clinical Diagnosis Section
                      Text(
                        'Clinical Diagnosis *',
                        style: AppTypography.headline.copyWith(
                          fontSize: 15,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _diagnosisController,
                        style: TextStyle(color: textPrimary, fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Acute Viral Bronchitis, Essential Hypertension...',
                          hintStyle:
                              TextStyle(color: textSecondary, fontSize: 13.5),
                          prefixIcon: const Icon(
                            Icons.local_hospital_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          filled: true,
                          fillColor: surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 3. Prescribed Medications Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Prescribed Medications',
                                style: AppTypography.headline.copyWith(
                                  fontSize: 15,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _medications.isNotEmpty
                                      ? AppColors.secondary
                                          .withValues(alpha: 0.15)
                                      : surfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_medications.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _medications.isNotEmpty
                                        ? AppColors.secondary
                                        : textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_medications.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.medication_outlined,
                                size: 36,
                                color: textSecondary.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No medications added yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fill out the medication form below and click "Add Medication".',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _medications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final m = _medications[index];
                            return Material(
                              color: surfaceColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: borderColor),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.medication_rounded,
                                        size: 20,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  m.name,
                                                  style: TextStyle(
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: textPrimary,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  m.dosage,
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              _buildBadge(
                                                Icons.schedule_rounded,
                                                m.frequency,
                                                surfaceVariant,
                                                textSecondary,
                                              ),
                                              _buildBadge(
                                                Icons.calendar_today_rounded,
                                                m.duration,
                                                surfaceVariant,
                                                textSecondary,
                                              ),
                                            ],
                                          ),
                                          if (m.instructions != null &&
                                              m.instructions!.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              'Instructions: ${m.instructions}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                                color: textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.error,
                                        size: 20,
                                      ),
                                      tooltip: 'Remove',
                                      onPressed: () {
                                        setState(() {
                                          _medications.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),

                      // 4. Add Medication Item Form
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : AppColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Add Medication Item',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Row: Medicine Name & Dosage
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: TextFormField(
                                    controller: _medNameController,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 13.5,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Medicine Name *',
                                      labelStyle: TextStyle(
                                        color: textSecondary,
                                        fontSize: 12.5,
                                      ),
                                      hintText: 'e.g. Amoxicillin',
                                      hintStyle: TextStyle(
                                        color: textSecondary.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                      filled: true,
                                      fillColor: surfaceVariant,
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: borderColor),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: borderColor),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 4,
                                  child: TextFormField(
                                    controller: _dosageController,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 13.5,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Dosage *',
                                      labelStyle: TextStyle(
                                        color: textSecondary,
                                        fontSize: 12.5,
                                      ),
                                      hintText: '500 mg',
                                      hintStyle: TextStyle(
                                        color: textSecondary.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                      filled: true,
                                      fillColor: surfaceVariant,
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: borderColor),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: borderColor),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Frequency Input
                            TextFormField(
                              controller: _frequencyController,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13.5,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Frequency',
                                labelStyle: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12.5,
                                ),
                                hintText: 'e.g. Twice daily after meals',
                                filled: true,
                                fillColor: surfaceVariant,
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: _quickFrequencies.map((f) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ActionChip(
                                      label: Text(
                                        f,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: textSecondary,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: surfaceVariant,
                                      side: BorderSide(color: borderColor),
                                      onPressed: () {
                                        setState(() {
                                          _frequencyController.text = f;
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Duration Input
                            TextFormField(
                              controller: _durationController,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13.5,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Duration',
                                labelStyle: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12.5,
                                ),
                                hintText: 'e.g. 5 days',
                                filled: true,
                                fillColor: surfaceVariant,
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: _quickDurations.map((d) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ActionChip(
                                      label: Text(
                                        d,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: textSecondary,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: surfaceVariant,
                                      side: BorderSide(color: borderColor),
                                      onPressed: () {
                                        setState(() {
                                          _durationController.text = d;
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Special Instructions
                            TextFormField(
                              controller: _instructionsController,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13.5,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Special Instructions (Optional)',
                                labelStyle: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12.5,
                                ),
                                hintText:
                                    'e.g. Take with a full glass of water. Avoid milk.',
                                hintStyle: TextStyle(
                                  color: textSecondary.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                                filled: true,
                                fillColor: surfaceVariant,
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Add Item Button
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _addMedication,
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add Medication'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 5. Follow-up Advice & Lifestyle Notes
                      Text(
                        'Follow-up Advice & Lifestyle Notes (Optional)',
                        style: AppTypography.headline.copyWith(
                          fontSize: 15,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Schedule follow-up blood test in 2 weeks. Stay hydrated and rest.',
                          hintStyle:
                              TextStyle(color: textSecondary, fontSize: 13),
                          filled: true,
                          fillColor: surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Sticky Actions Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Discard',
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleIssuePrescription,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        _isSubmitting
                            ? 'Issuing Prescription...'
                            : 'Issue & Finalize',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(
    IconData icon,
    String text,
    Color bgColor,
    Color fgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fgColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}
