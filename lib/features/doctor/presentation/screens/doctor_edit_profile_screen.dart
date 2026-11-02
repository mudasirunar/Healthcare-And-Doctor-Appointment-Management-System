import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../doctor/domain/entities/doctor_model.dart';

/// Professional profile editor for Doctors to manage professional name, department,
/// consultation fee, experience, slot duration, phone number, and clinical bio.
class DoctorEditProfileScreen extends ConsumerStatefulWidget {
  final DoctorModel doctor;

  const DoctorEditProfileScreen({super.key, required this.doctor});

  @override
  ConsumerState<DoctorEditProfileScreen> createState() =>
      _DoctorEditProfileScreenState();
}

class _DoctorEditProfileScreenState
    extends ConsumerState<DoctorEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _expCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _phoneCtrl;

  late String _selectedSpecialtyId;
  late String _selectedSpecialtyName;
  late int _slotDurationMinutes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    final user = ref.read(currentUserProvider);

    _nameCtrl = TextEditingController(text: d.doctorName);
    _feeCtrl = TextEditingController(text: d.consultationFee.toStringAsFixed(0));
    _expCtrl = TextEditingController(text: d.experienceYears.toString());
    _bioCtrl = TextEditingController(text: d.bio);
    _phoneCtrl = TextEditingController(text: user?.phoneNumber ?? '');

    _selectedSpecialtyId = d.specialtyId;
    _selectedSpecialtyName = d.specialtyName;
    _slotDurationMinutes = d.slotDurationMinutes;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _feeCtrl.dispose();
    _expCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final d = widget.doctor;
    final user = ref.read(currentUserProvider);

    final fee = double.tryParse(_feeCtrl.text.trim()) ?? d.consultationFee;
    final exp = int.tryParse(_expCtrl.text.trim()) ?? d.experienceYears;
    final name = _nameCtrl.text.trim();
    final bio = _bioCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    final updatedDoctor = d.copyWith(
      doctorName: name,
      specialtyId: _selectedSpecialtyId,
      specialtyName: _selectedSpecialtyName,
      consultationFee: fee,
      experienceYears: exp,
      slotDurationMinutes: _slotDurationMinutes,
      bio: bio,
    );

    try {
      // 1. Update doctor entity in Firestore live
      await ref.read(doctorRepositoryProvider).updateDoctorProfile(updatedDoctor);

      // 2. Update user profile record if name or phone changed
      if (user != null) {
        final updatedUser = user.copyWith(
          displayName: name,
          phoneNumber: phone,
        );
        await ref.read(authRepositoryProvider).updateProfile(updatedUser);
        ref.read(currentUserProvider.notifier).state = updatedUser;
      }

      ref.invalidate(allDoctorsAdminProvider);
      ref.invalidate(filteredDoctorsProvider);
      ref.invalidate(verifiedDoctorsStreamProvider);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Professional profile updated successfully!',
        );
        Navigator.pop(context, updatedDoctor);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Update failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final isDark = AppColors.isDark(context);
    final user = ref.watch(currentUserProvider);
    final specialties = ref.watch(specialtiesProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _handleSave,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            // Verified Credentials Section (Managed by Admin - Read-Only)
            Text(
              'Hospital Credentials (Managed by Admin)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Medical License',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.verified, size: 15, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            widget.doctor.licenseNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Divider(height: 20, color: borderColor),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Credential Status',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.doctor.verificationStatus.displayName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Editable Public Practice Profile
            Text(
              'Public Practice Profile',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 10),

            // 1. Doctor Full Professional Name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Professional Name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter your professional name' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 2. Department / Specialty Selector
            if (specialties.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: specialties.any((s) => s.id == _selectedSpecialtyId)
                    ? _selectedSpecialtyId
                    : (specialties.isNotEmpty ? specialties.first.id : null),
                decoration: const InputDecoration(
                  labelText: 'Medical Department / Specialty',
                  prefixIcon: Icon(Icons.medical_services_outlined),
                ),
                dropdownColor: surfaceColor,
                items: specialties.map((s) {
                  return DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      s.name,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
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
              const SizedBox(height: 16),
            ],

            // 3. Consultation Fee & Experience in Years Row
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
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = double.tryParse(v.trim());
                      if (n == null || n < 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _expCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Experience (Years)',
                      prefixIcon: Icon(Icons.history_edu_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4. Consultation Slot Duration (Modern Rounded Pill Selector - No Ticks, No Overflow)
            Text(
              'Consultation Slot Duration',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Individual appointment duration for new patient bookings',
              style: AppTypography.caption.copyWith(color: textSecondary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [15, 30, 45, 60].map((mins) {
                final isSelected = _slotDurationMinutes == mins;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() => _slotDurationMinutes = mins);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? surfaceColor : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : borderColor,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '$mins mins',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 5. Contact Phone Number
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+1 (555) 000-0000',
              ),
            ),
            const SizedBox(height: 16),

            // 6. Registered Professional Email (Read-only reference)
            if (user?.email != null && user!.email.isNotEmpty) ...[
              TextFormField(
                initialValue: user.email,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Registered Medical Email (Account)',
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: const Tooltip(
                    message: 'Managed by Hospital Authentication',
                    child: Icon(Icons.lock_outline_rounded, size: 18),
                  ),
                  filled: true,
                  fillColor: surfaceColor.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 7. Professional Bio & Clinical Philosophy
            TextFormField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Professional Bio & Clinical Philosophy',
                hintText:
                    'Describe your clinical training, areas of medical focus, and patient philosophy...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),

            // 8. Save Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
                        'Save Profile',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
