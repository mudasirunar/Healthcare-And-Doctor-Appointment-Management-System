import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:healthcare_app/core/providers/app_providers.dart';
import 'package:healthcare_app/core/services/user_notification_service.dart';
import 'package:healthcare_app/core/theme/app_colors.dart';
import 'package:healthcare_app/core/theme/app_typography.dart';
import 'package:healthcare_app/core/widgets/app_snack_bar.dart';
import 'package:healthcare_app/features/appointment/domain/entities/appointment_model.dart';
import 'package:healthcare_app/features/consultation/domain/entities/prescription_model.dart';

class PrescriptionBuilderDialog extends ConsumerStatefulWidget {
  final AppointmentModel appointment;
  final VoidCallback onPrescriptionCreated;

  const PrescriptionBuilderDialog({
    super.key,
    required this.appointment,
    required this.onPrescriptionCreated,
  });

  @override
  ConsumerState<PrescriptionBuilderDialog> createState() => _PrescriptionBuilderDialogState();
}

class _PrescriptionBuilderDialogState extends ConsumerState<PrescriptionBuilderDialog> {
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  final List<MedicationItem> _medications = [];

  final _medNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController(text: 'Twice daily after meals');
  final _durationController = TextEditingController(text: '5 days');
  final _instructionsController = TextEditingController();

  bool _isSubmitting = false;

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
    if (name.isEmpty || dosage.isEmpty) {
      AppSnackBar.showWarning(
        context,
        'Please enter medication name and dosage.',
      );
      return;
    }

    setState(() {
      _medications.add(
        MedicationItem(
          name: name,
          dosage: dosage,
          frequency: _frequencyController.text.trim(),
          duration: _durationController.text.trim(),
          instructions: _instructionsController.text.trim().isNotEmpty
              ? _instructionsController.text.trim()
              : null,
        ),
      );
      _medNameController.clear();
      _dosageController.clear();
      _instructionsController.clear();
    });
  }

  Future<void> _handleIssuePrescription() async {
    final diagnosis = _diagnosisController.text.trim();
    if (diagnosis.isEmpty) {
      AppSnackBar.showWarning(
        context,
        'Please provide a medical diagnosis.',
      );
      return;
    }
    if (_medications.isEmpty) {
      AppSnackBar.showWarning(
        context,
        'Please add at least one medication to the prescription.',
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
        medications: _medications,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        issuedAtUtc: DateTime.now().toUtc().toIso8601String(),
      );

      // Save prescription
      await aptRepo.createPrescription(prescription);

      // Transition appointment to Completed
      await aptRepo.updateStatus(
        appointmentId: widget.appointment.id,
        targetStatus: AppointmentStatus.completed,
        actorUserId: user?.id ?? 'doctor',
        note: 'Doctor issued digital prescription ($rxId) and finalized consultation session.',
      );

      UserNotificationService.instance.sendPatientNotification(
        patientUserId: widget.appointment.patientId,
        title: 'Digital Prescription Issued',
        body: 'Dr. ${widget.appointment.doctorName} has issued a digital prescription for your consultation.',
        type: 'prescription_issued',
        targetId: widget.appointment.id,
      );

      widget.onPrescriptionCreated();
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showSuccess(
          context,
          'Digital prescription generated and consultation finalized!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Issue Digital Prescription', style: AppTypography.headline.copyWith(fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 16, color: AppColors.border),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient: ${widget.appointment.patientName} • #${widget.appointment.id}',
                        style: AppTypography.subtitle.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 12),

                      // Diagnosis
                      TextFormField(
                        controller: _diagnosisController,
                        decoration: const InputDecoration(
                          labelText: 'Diagnosis (Required)',
                          hintText: 'e.g. Acute Viral Bronchitis...',
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Added Medications
                      const Text('Prescribed Medications', style: AppTypography.headline),
                      const SizedBox(height: 8),

                      if (_medications.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('No medications added yet. Use the form below.', style: AppTypography.caption),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _medications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final m = _medications[index];
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${m.name} (${m.dosage})', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                                        Text('${m.frequency} • ${m.duration}', style: AppTypography.caption),
                                        if (m.instructions != null)
                                          Text('Instructions: ${m.instructions}', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                    onPressed: () => setState(() => _medications.removeAt(index)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 16),

                      // Add Medication Sub-form
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Add Medication Item', style: AppTypography.caption),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _medNameController,
                                    decoration: const InputDecoration(labelText: 'Medicine Name', isDense: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _dosageController,
                                    decoration: const InputDecoration(labelText: 'Dosage (500mg)', isDense: true),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _frequencyController,
                                    decoration: const InputDecoration(labelText: 'Frequency', isDense: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _durationController,
                                    decoration: const InputDecoration(labelText: 'Duration', isDense: true),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _instructionsController,
                              decoration: const InputDecoration(labelText: 'Special Instructions (Optional)', isDense: true),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: _addMedication,
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add Item'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(110, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Follow-up notes
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Follow-up Advice & Lifestyle Notes',
                          hintText: 'e.g. Schedule follow-up blood test in 2 weeks...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 20, color: AppColors.border),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Discard'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleIssuePrescription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      minimumSize: const Size(160, 44),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Issue & Finalize'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
