import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/user_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../auth/domain/entities/user_model.dart';

class AdminRegisterPatientScreen extends ConsumerStatefulWidget {
  const AdminRegisterPatientScreen({super.key});

  @override
  ConsumerState<AdminRegisterPatientScreen> createState() =>
      _AdminRegisterPatientScreenState();
}

class _AdminRegisterPatientScreenState
    extends ConsumerState<AdminRegisterPatientScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();

  String _gender = 'Male';
  String _bloodGroup = 'A+';
  bool _obscurePassword = true;
  bool _isRegistering = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
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

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isRegistering = true);

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final patientDraft = UserModel(
      id: '', // Will be replaced by Firebase Auth UID
      email: _emailCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
      role: UserRole.patient,
      phoneNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      dateOfBirth: _dobCtrl.text.trim().isEmpty ? null : _dobCtrl.text.trim(),
      gender: _gender,
      bloodGroup: _bloodGroup,
      medicalAllergies: _allergiesCtrl.text.trim().isEmpty ? null : _allergiesCtrl.text.trim(),
      emergencyContact: _emergencyCtrl.text.trim().isEmpty ? null : _emergencyCtrl.text.trim(),
      createdAt: nowIso,
      updatedAt: nowIso,
    );

    try {
      final created = await ref.read(authRepositoryProvider).registerPatientByAdmin(
            patient: patientDraft,
            password: _passwordCtrl.text.trim(),
          );

      ref.invalidate(allPatientsAdminProvider);

      // Welcome notification to the new patient
      UserNotificationService.instance.sendPatientNotification(
        patientUserId: created.id,
        title: 'Welcome to MediCare Hospital',
        body: 'Your patient account has been registered by Hospital Administration.',
        type: 'patient_registered',
      );

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Patient ${created.displayName} registered successfully.',
        );
        Navigator.pop(context, created);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Register New Patient'),
        actions: [
          TextButton(
            onPressed: _isRegistering ? null : _handleRegister,
            child: _isRegistering
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Register',
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
            // Section 1: Account & Credentials
            Text(
              'Account Credentials',
              style: AppTypography.headline.copyWith(fontSize: 15, color: textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Assign the patient an email and temporary password to sign into the mobile app.',
              style: AppTypography.caption.copyWith(color: textSecondary),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Patient Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required.';
                if (!v.contains('@') || !v.contains('.')) return 'Invalid email format.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Temporary Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Password is required.';
                if (v.trim().length < 6) return 'Password must be at least 6 characters.';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Section 2: Personal Identity
            Text(
              'Personal Identity',
              style: AppTypography.headline.copyWith(fontSize: 15, color: textPrimary),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Legal Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Full name is required.' : null,
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
                DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _gender = val);
              },
            ),
            const SizedBox(height: 24),

            // Section 3: Clinical & Emergency Data
            Text(
              'Clinical & Emergency Information',
              style: AppTypography.headline.copyWith(fontSize: 15, color: textPrimary),
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
                DropdownMenuItem(value: 'Unknown', child: Text('Unknown / Pending Lab')),
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
                hintText: 'e.g. Penicillin, Peanuts, Pollen',
                prefixIcon: Icon(Icons.healing_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emergencyCtrl,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact (Name & Phone)',
                hintText: 'e.g. Sarah Doe (+1-555-0199)',
                prefixIcon: Icon(Icons.contact_phone_outlined),
              ),
            ),
            const SizedBox(height: 28),

            // Submit Button
            ElevatedButton(
              onPressed: _isRegistering ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isRegistering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Complete Hospital Registration', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

