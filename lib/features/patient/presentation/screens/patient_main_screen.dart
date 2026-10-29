import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import 'patient_home_screen.dart';
import 'patient_appointments_screen.dart';
import '../../../consultation/presentation/screens/prescription_viewer_screen.dart';

class PatientMainScreen extends StatefulWidget {
  const PatientMainScreen({super.key});

  @override
  State<PatientMainScreen> createState() => _PatientMainScreenState();
}

class _PatientMainScreenState extends State<PatientMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    PatientHomeScreen(),
    PatientAppointmentsScreen(),
    _PatientPrescriptionsTab(),
    _PatientProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: AppColors.primaryLight,
        backgroundColor: AppColors.surface,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded, color: AppColors.primary),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded, color: AppColors.primary),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication_rounded, color: AppColors.primary),
            label: 'Prescriptions',
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

class _PatientPrescriptionsTab extends ConsumerWidget {
  const _PatientPrescriptionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final aptRepo = ref.watch(appointmentRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Digital Prescriptions'),
      ),
      body: FutureBuilder(
        future: user != null ? aptRepo.getPrescriptionsForPatient(user.id) : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const EmptyStateView(
              icon: Icons.receipt_long_rounded,
              title: 'No Digital Prescriptions',
              description: 'Prescriptions issued by your consulting doctor after completed sessions will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final rx = list[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Rx #${rx.id.toUpperCase()}',
                              style: AppTypography.caption.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            rx.doctorSpecialty,
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Prescribed by ${rx.doctorName}', style: AppTypography.headline.copyWith(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Diagnosis: ${rx.diagnosis}', style: AppTypography.bodyMedium),
                      const SizedBox(height: 8),
                      Text(
                        '${rx.medications.length} Medications Prescribed',
                        style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PrescriptionViewerScreen(prescriptionId: rx.id),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility_rounded, size: 16),
                          label: const Text('Open Prescription'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(140, 38),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PatientProfileTab extends ConsumerWidget {
  const _PatientProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Patient Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                user != null && user.displayName.isNotEmpty ? user.displayName[0] : 'P',
                style: AppTypography.display.copyWith(color: AppColors.primary, fontSize: 32),
              ),
            ),
            const SizedBox(height: 12),
            Text(user?.displayName ?? 'Patient', style: AppTypography.headline),
            Text(user?.email ?? '', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _ProfileItem(label: 'Phone', value: user?.phoneNumber ?? 'Not provided'),
                  const Divider(height: 16, color: AppColors.border),
                  _ProfileItem(label: 'Date of Birth', value: user?.dateOfBirth ?? '1992-04-15'),
                  const Divider(height: 16, color: AppColors.border),
                  _ProfileItem(label: 'Blood Group', value: user?.bloodGroup ?? 'O+'),
                  const Divider(height: 16, color: AppColors.border),
                  _ProfileItem(label: 'Emergency Contact', value: user?.emergencyContact ?? 'Not provided'),
                  const Divider(height: 16, color: AppColors.border),
                  _ProfileItem(label: 'Known Allergies', value: user?.medicalAllergies ?? 'None'),
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
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileItem({required this.label, required this.value});

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
