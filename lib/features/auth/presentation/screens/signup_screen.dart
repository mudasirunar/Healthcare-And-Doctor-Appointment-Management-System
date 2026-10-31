import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/user_model.dart';
import '../../../doctor/domain/entities/doctor_model.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  UserRole _selectedRole = UserRole.patient;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  // Patient fields
  final _dobController = TextEditingController(text: '1995-06-20');
  String _selectedGender = 'Female';
  String _selectedBloodGroup = 'O+';
  final _allergiesController = TextEditingController(text: 'None reported');

  // Doctor fields
  String? _selectedSpecialtyId;
  String? _selectedSpecialtyName;
  final _licenseController = TextEditingController();
  final _experienceController = TextEditingController(text: '5');
  final _feeController = TextEditingController(text: '50.0');
  final _bioController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _allergiesController.dispose();
    _licenseController.dispose();
    _experienceController.dispose();
    _feeController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = await authRepo.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
        role: _selectedRole,
        dateOfBirth: _selectedRole == UserRole.patient ? _dobController.text.trim() : null,
        gender: _selectedRole == UserRole.patient ? _selectedGender : null,
        bloodGroup: _selectedRole == UserRole.patient ? _selectedBloodGroup : null,
        medicalAllergies: _selectedRole == UserRole.patient ? _allergiesController.text.trim() : null,
      );

      // If registered as doctor, create doctor profile in pending state
      if (_selectedRole == UserRole.doctor) {
        final docRepo = ref.read(doctorRepositoryProvider);
        final doctor = DoctorModel(
          id: 'doc_${user.id}',
          userId: user.id,
          doctorName: _nameController.text.trim(),
          specialtyId: _selectedSpecialtyId ?? 'spec_general',
          specialtyName: _selectedSpecialtyName ?? 'General Medicine',
          licenseNumber: _licenseController.text.trim(),
          experienceYears: int.tryParse(_experienceController.text.trim()) ?? 3,
          consultationFee: double.tryParse(_feeController.text.trim()) ?? 50.0,
          bio: _bioController.text.trim().isNotEmpty
              ? _bioController.text.trim()
              : 'Medical professional practicing ${_selectedSpecialtyName ?? "General Medicine"}.',
          verificationStatus: VerificationStatus.pending,
        );
        await docRepo.registerDoctorProfile(doctor);
      }

      ref.read(currentUserProvider.notifier).state = user;
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final specialtiesAsync = ref.watch(specialtiesProvider);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Role Segmented Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariantOf(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _RoleTabButton(
                              label: 'Patient',
                              icon: Icons.person_rounded,
                              isSelected: _selectedRole == UserRole.patient,
                              onTap: () => setState(() => _selectedRole = UserRole.patient),
                            ),
                          ),
                          Expanded(
                            child: _RoleTabButton(
                              label: 'Doctor',
                              icon: Icons.medical_services_rounded,
                              isSelected: _selectedRole == UserRole.doctor,
                              onTap: () => setState(() => _selectedRole = UserRole.doctor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorLightOf(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: _selectedRole == UserRole.doctor ? 'Doctor Full Name (e.g. Dr. John Doe)' : 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your full name.' : null,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter email address.';
                        if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.textMutedOf(context),
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v != null && v.length >= 6) ? null : 'At least 6 characters required.',
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Patient Specific Details ---
                    if (_selectedRole == UserRole.patient) ...[
                      Text(
                        'Health Profile (Optional)',
                        style: AppTypography.headline.copyWith(color: textPrimary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedGender,
                              dropdownColor: AppColors.surfaceOf(context),
                              style: AppTypography.bodyLarge.copyWith(color: textPrimary),
                              decoration: const InputDecoration(labelText: 'Gender'),
                              items: const [
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (v) => setState(() => _selectedGender = v ?? 'Female'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedBloodGroup,
                              dropdownColor: AppColors.surfaceOf(context),
                              style: AppTypography.bodyLarge.copyWith(color: textPrimary),
                              decoration: const InputDecoration(labelText: 'Blood Group'),
                              items: const [
                                DropdownMenuItem(value: 'A+', child: Text('A+')),
                                DropdownMenuItem(value: 'A-', child: Text('A-')),
                                DropdownMenuItem(value: 'B+', child: Text('B+')),
                                DropdownMenuItem(value: 'B-', child: Text('B-')),
                                DropdownMenuItem(value: 'O+', child: Text('O+')),
                                DropdownMenuItem(value: 'O-', child: Text('O-')),
                                DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                                DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                              ],
                              onChanged: (v) => setState(() => _selectedBloodGroup = v ?? 'O+'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _allergiesController,
                        style: TextStyle(color: textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Medical Allergies / Pre-existing conditions',
                          prefixIcon: Icon(Icons.warning_amber_rounded),
                        ),
                      ),
                    ],

                    // --- Doctor Specific Details ---
                    if (_selectedRole == UserRole.doctor) ...[
                      Text(
                        'Professional Credentials',
                        style: AppTypography.headline.copyWith(color: textPrimary),
                      ),
                      const SizedBox(height: 12),
                      specialtiesAsync.when(
                        data: (specialties) {
                          if (_selectedSpecialtyId == null && specialties.isNotEmpty) {
                            _selectedSpecialtyId = specialties.first.id;
                            _selectedSpecialtyName = specialties.first.name;
                          }
                          return DropdownButtonFormField<String>(
                            value: _selectedSpecialtyId,
                            dropdownColor: AppColors.surfaceOf(context),
                            style: AppTypography.bodyLarge.copyWith(color: textPrimary),
                            decoration: const InputDecoration(labelText: 'Specialization'),
                            items: specialties.map((s) {
                              return DropdownMenuItem(value: s.id, child: Text(s.name));
                            }).toList(),
                            onChanged: (v) {
                              final item = specialties.firstWhere((s) => s.id == v);
                              setState(() {
                                _selectedSpecialtyId = item.id;
                                _selectedSpecialtyName = item.name;
                              });
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _licenseController,
                        style: TextStyle(color: textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Medical License Registration No.',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'License number required.' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _experienceController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textPrimary),
                              decoration: const InputDecoration(labelText: 'Years of Exp.'),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _feeController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: textPrimary),
                              decoration: const InputDecoration(
                                labelText: 'Fee (USD)',
                                prefixText: '\$ ',
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bioController,
                        maxLines: 3,
                        style: TextStyle(color: textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Professional Bio & Education',
                          hintText: 'Brief summary of clinical background...',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '* New doctor accounts are submitted for administrator verification before becoming searchable.',
                        style: AppTypography.caption.copyWith(color: AppColors.warning),
                      ),
                    ],

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignUp,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(_selectedRole == UserRole.doctor ? 'Submit Verification' : 'Register Account'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: AppTypography.bodyMedium.copyWith(color: textSecondary),
                        ),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Sign In'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final activeColor = isDark ? const Color(0xFF38BDF8) : AppColors.primary;
    final inactiveColor = AppColors.textSecondaryOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceOf(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.button.copyWith(
                color: isSelected ? activeColor : inactiveColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
