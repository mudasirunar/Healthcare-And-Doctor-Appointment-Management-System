import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/user_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../auth/domain/entities/user_model.dart';

class AdminEditPatientScreen extends ConsumerStatefulWidget {
  final UserModel patient;

  const AdminEditPatientScreen({super.key, required this.patient});

  @override
  ConsumerState<AdminEditPatientScreen> createState() =>
      _AdminEditPatientScreenState();
}

class _AdminEditPatientScreenState
    extends ConsumerState<AdminEditPatientScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _allergiesCtrl;
  late final TextEditingController _emergencyCtrl;

  late String _gender;
  late String _bloodGroup;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _nameCtrl = TextEditingController(text: p.displayName);
    _phoneCtrl = TextEditingController(text: p.phoneNumber ?? '');
    _dobCtrl = TextEditingController(text: p.dateOfBirth ?? '');
    _allergiesCtrl = TextEditingController(text: p.medicalAllergies ?? '');
    _emergencyCtrl = TextEditingController(text: p.emergencyContact ?? '');

    _gender = (p.gender != null && p.gender!.isNotEmpty) ? p.gender! : 'Male';
    _bloodGroup = (p.bloodGroup != null && p.bloodGroup!.isNotEmpty)
        ? p.bloodGroup!
        : 'A+';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _allergiesCtrl.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final p = widget.patient;
    final updated = p.copyWith(
      displayName: _nameCtrl.text.trim(),
      phoneNumber:
          _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      dateOfBirth: _dobCtrl.text.trim().isEmpty ? null : _dobCtrl.text.trim(),
      gender: _gender,
      bloodGroup: _bloodGroup,
      medicalAllergies: _allergiesCtrl.text.trim().isEmpty
          ? null
          : _allergiesCtrl.text.trim(),
      emergencyContact: _emergencyCtrl.text.trim().isEmpty
          ? null
          : _emergencyCtrl.text.trim(),
    );

    try {
      await ref.read(authRepositoryProvider).updateProfile(updated);
      ref.invalidate(allPatientsAdminProvider);

      // Notify the patient
      UserNotificationService.instance.sendPatientNotification(
        patientUserId: p.id,
        title: 'Clinical Records Updated',
        body:
            'Hospital administration updated your medical and demographic profile.',
        type: 'patient_profile_updated',
      );

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Patient ${updated.displayName} profile updated.',
        );
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Edit Patient Records'),
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
            // Section 1: Demographics
            Text(
              'Patient Identity',
              style: AppTypography.headline.copyWith(
                fontSize: 15,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Legal Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _dobCtrl,
                    readOnly: true,
                    onTap: _selectDateOfBirth,
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                prefixIcon: Icon(Icons.wc_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
                DropdownMenuItem(
                  value: 'Prefer not to say',
                  child: Text('Prefer not to say'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _gender = val);
              },
            ),
            const SizedBox(height: 24),

            // Section 2: Clinical Details
            Text(
              'Clinical & Emergency Profile',
              style: AppTypography.headline.copyWith(
                fontSize: 15,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _bloodGroup,
              decoration: const InputDecoration(
                labelText: 'Blood Group',
                prefixIcon: Icon(Icons.bloodtype_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'A+', child: Text('A+ (Positive)')),
                DropdownMenuItem(value: 'A-', child: Text('A- (Negative)')),
                DropdownMenuItem(value: 'B+', child: Text('B+ (Positive)')),
                DropdownMenuItem(value: 'B-', child: Text('B- (Negative)')),
                DropdownMenuItem(value: 'AB+', child: Text('AB+ (Positive)')),
                DropdownMenuItem(value: 'AB-', child: Text('AB- (Negative)')),
                DropdownMenuItem(value: 'O+', child: Text('O+ (Positive)')),
                DropdownMenuItem(value: 'O-', child: Text('O- (Negative)')),
                DropdownMenuItem(
                  value: 'Unknown',
                  child: Text('Unknown / Pending Lab'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _bloodGroup = val);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _allergiesCtrl,
              decoration: const InputDecoration(
                labelText: 'Known Allergies',
                hintText: 'e.g. Penicillin, Pollen, Peanuts',
                prefixIcon: Icon(Icons.healing_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emergencyCtrl,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact',
                hintText: 'e.g. Sarah Doe (+1-555-0199)',
                prefixIcon: Icon(Icons.contact_phone_outlined),
              ),
            ),
            const SizedBox(height: 28),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
