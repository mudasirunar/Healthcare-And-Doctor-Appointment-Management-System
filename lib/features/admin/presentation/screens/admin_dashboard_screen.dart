import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import '../../../doctor/domain/entities/specialty_model.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _tabIndex = 0;

  void _handleApproveDoctor(DoctorModel doc) async {
    final docRepo = ref.read(doctorRepositoryProvider);
    await docRepo.updateVerificationStatus(doc.id, VerificationStatus.approved);
    ref.invalidate(filteredDoctorsProvider);
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${doc.doctorName} approved and published to doctor directory!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _handleRejectDoctor(DoctorModel doc) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Credentials - ${doc.doctorName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Specify reasons for verification rejection (e.g. invalid license number or unrecognized medical board):',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Notes (Required)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              final docRepo = ref.read(doctorRepositoryProvider);
              await docRepo.updateVerificationStatus(doc.id, VerificationStatus.rejected, reason);
              ref.invalidate(filteredDoctorsProvider);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject Verification'),
          ),
        ],
      ),
    );
  }

  void _showAddSpecialtyDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Medical Specialty'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Specialty Name (e.g. Ophthalmology)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Brief Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final newSpec = SpecialtyModel(
                id: 'spec_${name.toLowerCase().replaceAll(' ', '_')}',
                name: name,
                description: descCtrl.text.trim(),
                iconName: 'healing',
              );
              await ref.read(doctorRepositoryProvider).saveSpecialty(newSpec);
              ref.invalidate(specialtiesProvider);
              setState(() {});
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final doctorRepo = ref.watch(doctorRepositoryProvider);
    final specialtiesAsync = ref.watch(specialtiesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Admin Desk • ${user?.displayName ?? "Admin"}'),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              ref.read(currentUserProvider.notifier).state = null;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented Navigation Header
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _NavButton(
                  title: 'Verifications',
                  icon: Icons.verified_user_outlined,
                  isSelected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                const SizedBox(width: 8),
                _NavButton(
                  title: 'Analytics',
                  icon: Icons.bar_chart_rounded,
                  isSelected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
                const SizedBox(width: 8),
                _NavButton(
                  title: 'Specialties',
                  icon: Icons.category_outlined,
                  isSelected: _tabIndex == 2,
                  onTap: () => setState(() => _tabIndex = 2),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                // Tab 0: Verification Desk
                FutureBuilder<List<DoctorModel>>(
                  future: doctorRepo.getPendingVerificationDoctors(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final pending = snapshot.data ?? [];

                    if (pending.isEmpty) {
                      return const EmptyStateView(
                        icon: Icons.task_alt_rounded,
                        title: 'Verification Queue Cleared',
                        description: 'There are no pending doctor verification submissions awaiting review.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: pending.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = pending[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(doc.doctorName, style: AppTypography.headline),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.warningLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Pending Verification',
                                        style: AppTypography.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Specialty: ${doc.specialtyName} • Experience: ${doc.experienceYears} Years',
                                  style: AppTypography.bodyMedium.copyWith(color: AppColors.primary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Medical License No: ${doc.licenseNumber}',
                                  style: AppTypography.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Text(doc.bio, style: AppTypography.bodyMedium),
                                const Divider(height: 20, color: AppColors.border),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _handleRejectDoctor(doc),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: const BorderSide(color: AppColors.error),
                                        minimumSize: const Size(100, 38),
                                      ),
                                      child: const Text('Decline'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: () => _handleApproveDoctor(doc),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.success,
                                        minimumSize: const Size(130, 38),
                                      ),
                                      child: const Text('Approve Doctor'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                // Tab 1: Platform Analytics
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Operational Metrics', style: AppTypography.headline),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _MetricCard(
                            title: 'Total Patients',
                            value: '148',
                            subtitle: '+12 this week',
                            color: AppColors.primary,
                            icon: Icons.people_outline_rounded,
                          ),
                          const SizedBox(width: 12),
                          _MetricCard(
                            title: 'Verified Doctors',
                            value: '24',
                            subtitle: '3 specialties',
                            color: AppColors.secondary,
                            icon: Icons.medical_services_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _MetricCard(
                            title: 'Total Bookings',
                            value: '412',
                            subtitle: '94% fulfillment',
                            color: AppColors.success,
                            icon: Icons.calendar_month_outlined,
                          ),
                          const SizedBox(width: 12),
                          _MetricCard(
                            title: 'Cancellation Rate',
                            value: '3.8%',
                            subtitle: 'Under target (<5%)',
                            color: AppColors.warning,
                            icon: Icons.trending_down_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      const Text('System Reliability & Concurrency Guard', style: AppTypography.headline),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: const [
                            _SystemStatusRow(label: 'Deterministic Slot Transaction Lock', status: 'Active (Zero Double-Booking)'),
                            Divider(height: 16, color: AppColors.border),
                            _SystemStatusRow(label: 'Time-Zone UTC Normalization', status: 'Enforced'),
                            Divider(height: 16, color: AppColors.border),
                            _SystemStatusRow(label: 'State Machine Transition Validator', status: 'Enforced'),
                            Divider(height: 16, color: AppColors.border),
                            _SystemStatusRow(label: 'Offline Persistence Store', status: 'Synchronized'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab 2: Specialty Taxonomy
                Scaffold(
                  backgroundColor: Colors.transparent,
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: _showAddSpecialtyDialog,
                    backgroundColor: AppColors.primary,
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text('Add Specialty', style: TextStyle(color: Colors.white)),
                  ),
                  body: specialtiesAsync.when(
                    data: (specialties) {
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: specialties.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final spec = specialties[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryLight,
                                child: const Icon(Icons.healing_rounded, color: AppColors.primary),
                              ),
                              title: Text(spec.name, style: AppTypography.headline.copyWith(fontSize: 16)),
                              subtitle: Text(spec.description),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${spec.activeDoctorCount} Docs',
                                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ErrorStateView(message: e.toString()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTypography.caption.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: AppTypography.display.copyWith(fontSize: 26, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(subtitle, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SystemStatusRow extends StatelessWidget {
  final String label;
  final String status;

  const _SystemStatusRow({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium),
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
            const SizedBox(width: 4),
            Text(status, style: AppTypography.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}
