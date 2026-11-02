import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../doctor/domain/entities/doctor_model.dart';

/// Professional profile editor for Doctors to manage fees, clinical bio, experience, and slot timings.
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
  late final TextEditingController _avatarCtrl;

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
    _avatarCtrl = TextEditingController(text: d.avatarUrl ?? user?.avatarUrl ?? '');
    _slotDurationMinutes = d.slotDurationMinutes;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _feeCtrl.dispose();
    _expCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    _avatarCtrl.dispose();
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
    final avatar = _avatarCtrl.text.trim().isNotEmpty ? _avatarCtrl.text.trim() : null;

    final updatedDoctor = d.copyWith(
      doctorName: name,
      consultationFee: fee,
      experienceYears: exp,
      slotDurationMinutes: _slotDurationMinutes,
      bio: bio,
      avatarUrl: avatar,
    );

    try {
      // 1. Update doctor entity in Firestore
      await ref.read(doctorRepositoryProvider).updateDoctorProfile(updatedDoctor);

      // 2. Update user profile record if name or phone changed
      if (user != null) {
        final updatedUser = user.copyWith(
          displayName: name,
          phoneNumber: phone,
          avatarUrl: avatar,
        );
        await ref.read(authRepositoryProvider).updateProfile(updatedUser);
      }

      ref.invalidate(allDoctorsAdminProvider);
      ref.invalidate(filteredDoctorsProvider);
      ref.invalidate(verifiedDoctorsStreamProvider);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Professional profile updated successfully!',
        );
        Navigator.pop(context);
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

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Edit Professional Profile'),
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            // Live Avatar Preview
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _avatarCtrl,
                    builder: (context, val, _) {
                      final url = val.text.trim();
                      final hasUrl = url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'));

                      return CircleAvatar(
                        radius: 46,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        backgroundImage: hasUrl ? NetworkImage(url) : null,
                        child: !hasUrl
                            ? Text(
                                _nameCtrl.text.isNotEmpty
                                    ? _nameCtrl.text
                                        .replaceFirst(RegExp(r'^Dr\.\s*'), '')
                                        .characters
                                        .first
                                        .toUpperCase()
                                    : 'D',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Verified Credentials Section (Read-Only)
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Medical License', style: TextStyle(color: textSecondary, fontSize: 13)),
                      Row(
                        children: [
                          const Icon(Icons.verified, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            widget.doctor.licenseNumber,
                            style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Divider(height: 18, color: borderColor),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Department', style: TextStyle(color: textSecondary, fontSize: 13)),
                      Text(
                        widget.doctor.specialtyName,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Editable Profile Fields
            Text(
              'Public Practice Profile',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            // Doctor Name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Professional Name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter your professional name' : null,
            ),
            const SizedBox(height: 16),

            // Fee & Experience Row
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
                const SizedBox(width: 14),
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
            const SizedBox(height: 16),

            // Slot Duration Selector
            Text(
              'Consultation Slot Duration',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
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
                    label: Text('$mins mins'),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _slotDurationMinutes = mins);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Phone Number
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Avatar URL
            TextFormField(
              controller: _avatarCtrl,
              decoration: const InputDecoration(
                labelText: 'Avatar Image URL',
                prefixIcon: Icon(Icons.image_outlined),
                hintText: 'https://example.com/photo.jpg',
              ),
            ),
            const SizedBox(height: 16),

            // Professional Bio
            TextFormField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Professional Bio & Clinical Philosophy',
                hintText: 'Describe your clinical training, areas of medical focus, and patient philosophy...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),

            // Save Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Save Professional Profile',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

