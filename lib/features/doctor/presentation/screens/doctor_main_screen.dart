import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare_app/core/providers/app_providers.dart';
import 'package:healthcare_app/core/theme/app_colors.dart';
import 'package:healthcare_app/core/theme/app_typography.dart';
import 'package:healthcare_app/features/doctor/domain/entities/doctor_model.dart';
import 'doctor_agenda_screen.dart';
import 'doctor_requests_screen.dart';
import 'doctor_availability_screen.dart';

class DoctorMainScreen extends ConsumerStatefulWidget {
  const DoctorMainScreen({super.key});

  @override
  ConsumerState<DoctorMainScreen> createState() => _DoctorMainScreenState();
}

class _DoctorMainScreenState extends ConsumerState<DoctorMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DoctorAgendaScreen(),
    DoctorRequestsScreen(),
    DoctorAvailabilityScreen(),
    _DoctorProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final doctorRepo = ref.watch(doctorRepositoryProvider);

    return Scaffold(
      body: Column(
        children: [
          // Verification Warning Banner if Doctor is pending or rejected
          FutureBuilder<DoctorModel?>(
            future: user != null ? doctorRepo.getDoctorByUserId(user.id) : null,
            builder: (context, snapshot) {
              final doc = snapshot.data;
              if (doc == null) return const SizedBox.shrink();

              if (doc.verificationStatus == VerificationStatus.pending) {
                return Container(
                  width: double.infinity,
                  color: AppColors.warningLight,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        const Icon(Icons.pending_actions_rounded, size: 18, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your profile is pending administrator verification. Patients cannot discover your slots until approved.',
                            style: AppTypography.caption.copyWith(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (doc.verificationStatus == VerificationStatus.rejected) {
                return Container(
                  width: double.infinity,
                  color: AppColors.errorLight,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Verification declined: ${doc.verificationNotes ?? "Credentials could not be verified."}',
                            style: AppTypography.caption.copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: AppColors.primaryLight,
        backgroundColor: AppColors.surface,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded, color: AppColors.primary),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.mark_email_unread_outlined),
            selectedIcon: Icon(Icons.mark_email_unread_rounded, color: AppColors.primary),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule_rounded, color: AppColors.primary),
            label: 'Availability',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DoctorProfileTab extends ConsumerWidget {
  const _DoctorProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final doctorRepo = ref.watch(doctorRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Doctor Workspace Profile'),
      ),
      body: FutureBuilder<DoctorModel?>(
        future: user != null ? doctorRepo.getDoctorByUserId(user.id) : null,
        builder: (context, snapshot) {
          final doc = snapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    doc?.doctorName.isNotEmpty == true ? doc!.doctorName[0] : 'D',
                    style: AppTypography.display.copyWith(color: AppColors.primary, fontSize: 32),
                  ),
                ),
                const SizedBox(height: 12),
                Text(doc?.doctorName ?? user?.displayName ?? 'Doctor', style: AppTypography.headline),
                Text(doc?.specialtyName ?? 'Specialist', style: AppTypography.subtitle.copyWith(color: AppColors.primary)),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _ProfileRow(label: 'Verification Status', value: doc?.verificationStatus.displayName ?? 'Pending'),
                      const Divider(height: 16, color: AppColors.border),
                      _ProfileRow(label: 'Medical License', value: doc?.licenseNumber ?? 'N/A'),
                      const Divider(height: 16, color: AppColors.border),
                      _ProfileRow(label: 'Clinical Experience', value: '${doc?.experienceYears ?? 0} Years'),
                      const Divider(height: 16, color: AppColors.border),
                      _ProfileRow(label: 'Consultation Fee', value: '\$${doc?.consultationFee.toStringAsFixed(0) ?? "0"}'),
                      const Divider(height: 16, color: AppColors.border),
                      _ProfileRow(label: 'Email', value: user?.email ?? ''),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    ref.read(currentUserProvider.notifier).state = null;
                  },
                  icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                  label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
