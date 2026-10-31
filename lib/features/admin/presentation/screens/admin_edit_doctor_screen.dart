import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/user_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../doctor/domain/entities/doctor_model.dart';

class AdminEditDoctorScreen extends ConsumerStatefulWidget {
  final DoctorModel doctor;

  const AdminEditDoctorScreen({super.key, required this.doctor});

  @override
  ConsumerState<AdminEditDoctorScreen> createState() =>
      _AdminEditDoctorScreenState();
}

class _AdminEditDoctorScreenState extends ConsumerState<AdminEditDoctorScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _licenseCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _expCtrl;
  late final TextEditingController _bioCtrl;

  late String _selectedSpecialtyId;
  late String _selectedSpecialtyName;
  late int _slotDurationMinutes;
  late VerificationStatus _verificationStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    _nameCtrl = TextEditingController(text: d.doctorName);
    _licenseCtrl = TextEditingController(text: d.licenseNumber);
    _feeCtrl = TextEditingController(text: d.consultationFee.toStringAsFixed(0));
    _expCtrl = TextEditingController(text: d.experienceYears.toString());
    _bioCtrl = TextEditingController(text: d.bio);

    _selectedSpecialtyId = d.specialtyId;
    _selectedSpecialtyName = d.specialtyName;
    _slotDurationMinutes = d.slotDurationMinutes;
    _verificationStatus = d.verificationStatus;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _licenseCtrl.dispose();
    _feeCtrl.dispose();
    _expCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final d = widget.doctor;
    final fee = double.tryParse(_feeCtrl.text.trim()) ?? d.consultationFee;
    final exp = int.tryParse(_expCtrl.text.trim()) ?? d.experienceYears;

    final updated = d.copyWith(
      doctorName: _nameCtrl.text.trim(),
      licenseNumber: _licenseCtrl.text.trim(),
      specialtyId: _selectedSpecialtyId,
      specialtyName: _selectedSpecialtyName,
      consultationFee: fee,
      experienceYears: exp,
      slotDurationMinutes: _slotDurationMinutes,
      bio: _bioCtrl.text.trim(),
      verificationStatus: _verificationStatus,
    );

    try {
      await ref.read(doctorRepositoryProvider).updateDoctorProfile(updated);
      ref.invalidate(allDoctorsAdminProvider);
      ref.invalidate(filteredDoctorsProvider);

      // Notify the doctor about key changes
      if (_selectedSpecialtyId != d.specialtyId) {
        UserNotificationService.instance.sendDoctorNotification(
          doctorUserId: d.userId,
          title: 'Specialty Department Reassigned',
          body:
              'Hospital administration reassigned your specialty to $_selectedSpecialtyName.',
          type: 'specialty_reassigned',
        );
      } else if (fee != d.consultationFee) {
        UserNotificationService.instance.sendDoctorNotification(
          doctorUserId: d.userId,
          title: 'Consultation Fee Updated',
          body:
              'Hospital administration adjusted your fee benchmark to \$${fee.toStringAsFixed(0)}.',
          type: 'fee_updated',
        );
      } else if (_verificationStatus != d.verificationStatus) {
        UserNotificationService.instance.sendDoctorNotification(
          doctorUserId: d.userId,
          title: 'Credential Status Updated',
          body:
              'Your credential status has been updated to ${_verificationStatus.displayName}.',
          type: 'verification_updated',
        );
      }

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Dr. ${updated.doctorName} profile saved.',
        );
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to update: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final specialties = ref.watch(specialtiesProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Edit Specialist Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Section 1: Professional Identity
            Text(
              'Identity & Medical Credentials',
              style: AppTypography.headline.copyWith(fontSize: 15, color: textPrimary),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Doctor Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Doctor name is required.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _licenseCtrl,
              decoration: const InputDecoration(
                labelText: 'Medical License Number',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'License number is required.' : null,
            ),
            const SizedBox(height: 20),

            // Section 2: Department Reassignment
            Text(
              'Specialty Department Assignment',
              style: AppTypography.headline.copyWith(fontSize: 15, color: textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Reassigning will update booking taxonomy and department directory.',
              style: AppTypography.caption.copyWith(color: textSecondary),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: specialties.any((s) => s.id == _selectedSpecialtyId)
                  ? _selectedSpecialtyId
                  : (specialties.isNotEmpty ? specialties.first.id : null),
              decoration: const InputDecoration(
                labelText: 'Specialty Department',
                prefixIcon: Icon(Icons.grid_view_rounded),
              ),
              items: specialties.map((s) {
                return DropdownMenuItem<String>(
                  value: s.id,
                  child: Text(s.name),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  final matched = specialties.firstWhere((s) => s.id == val);
                  setState(() {
                    _selectedSpecialtyId = matched.id;
                    _selectedSpecialtyName = matched.name;
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            // Section 3: Clinical Benchmarks & Slot Duration
            Text(
              'Fees, Experience & Slot Duration',
              style: AppTypography.headline.copyWith(fontSize: 15, color: textPrimary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _feeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Consultation Fee (\$)',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                    validator: (v) =>
                        v == null || double.tryParse(v) == null ? 'Valid fee required' : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _expCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Experience (Years)',
                      prefixIcon: Icon(Icons.work_outline_rounded),
                    ),
                    validator: (v) =>
                        v == null || int.tryParse(v) == null ? 'Valid years required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: _slotDurationMinutes,
              decoration: const InputDecoration(
                labelText: 'Consultation Slot Duration',
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                DropdownMenuItem(value: 45, child: Text('45 Minutes')),
                DropdownMenuItem(value: 60, child: Text('60 Minutes')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _slotDurationMinutes = val);
              },
            ),
            const SizedBox(height: 20),

            // Section 4: Verification Status
            Text(
              'Verification Status',
              style: AppTypography.headline.copyWith(fontSize: 15, color: textPrimary),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<VerificationStatus>(
              value: _verificationStatus,
              decoration: const InputDecoration(
                labelText: 'Account Status',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
              items: VerificationStatus.values.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(s.displayName),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _verificationStatus = val);
              },
            ),
            const SizedBox(height: 20),

            // Section 5: Biography & Clinical Summary
            Text(
              'Clinical Bio & Profile Summary',
              style: AppTypography.headline.copyWith(fontSize: 15, color: textPrimary),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Doctor Biography',
                hintText: 'Enter doctor background, subspecialties, and clinical expertise...',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Doctor biography is required.' : null,
            ),
            const SizedBox(height: 28),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Specialist Details', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
