import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../doctor/domain/entities/doctor_model.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getSpecialtyIcon(String iconName) {
    switch (iconName) {
      case 'favorite_rounded':
        return Icons.favorite_rounded;
      case 'spa_rounded':
        return Icons.spa_rounded;
      case 'child_care_rounded':
        return Icons.child_care_rounded;
      case 'accessibility_new_rounded':
        return Icons.accessibility_new_rounded;
      case 'psychology_rounded':
        return Icons.psychology_rounded;
      case 'medical_services_rounded':
      default:
        return Icons.medical_services_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final specialtiesAsync = ref.watch(specialtiesProvider);
    final filterState = ref.watch(doctorFilterProvider);
    final doctorsAsync = ref.watch(filteredDoctorsProvider);
    final appointmentsAsync = ref.watch(userAppointmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                user != null && user.displayName.isNotEmpty ? user.displayName[0] : 'P',
                style: AppTypography.headline.copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${user?.displayName.split(' ').first ?? 'Patient'}',
                  style: AppTypography.headline.copyWith(fontSize: 16),
                ),
                Text(
                  'How are you feeling today?',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(filteredDoctorsProvider);
          ref.invalidate(userAppointmentsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Upcoming Appointment Banner (if any)
              appointmentsAsync.when(
                data: (appointments) {
                  final upcoming = appointments.where((a) =>
                      a.status == AppointmentStatus.confirmed ||
                      a.status == AppointmentStatus.requested).toList();
                  if (upcoming.isEmpty) return const SizedBox.shrink();
                  final next = upcoming.first;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F0A66C2),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.alarm_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    next.status.displayName,
                                    style: AppTypography.caption.copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => context.push('/consultation/room/${next.id}'),
                              icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 18),
                              label: Text(
                                'Join Room',
                                style: AppTypography.caption.copyWith(color: Colors.white),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.25),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          next.doctorName,
                          style: AppTypography.headline.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          next.doctorSpecialty,
                          style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              DateTimeUtils.formatFullWithTimeZone(next.scheduledTimeUtc),
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  ref.read(doctorFilterProvider.notifier).state =
                      filterState.copyWith(query: val.trim().isEmpty ? null : val);
                },
                decoration: InputDecoration(
                  hintText: 'Search doctors, specialties, or keywords...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(doctorFilterProvider.notifier).state =
                                filterState.copyWith(query: null);
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Rating ≥ 4.8'),
                      selected: filterState.minRating == 4.8,
                      onSelected: (selected) {
                        ref.read(doctorFilterProvider.notifier).state =
                            filterState.copyWith(minRating: selected ? 4.8 : null);
                      },
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primaryLight,
                      labelStyle: TextStyle(
                        color: filterState.minRating == 4.8 ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: filterState.minRating == 4.8 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Fee ≤ \$60'),
                      selected: filterState.maxFee == 60.0,
                      onSelected: (selected) {
                        ref.read(doctorFilterProvider.notifier).state =
                            filterState.copyWith(maxFee: selected ? 60.0 : null);
                      },
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primaryLight,
                      labelStyle: TextStyle(
                        color: filterState.maxFee == 60.0 ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: filterState.maxFee == 60.0 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (filterState.specialtyId != null ||
                        filterState.minRating != null ||
                        filterState.maxFee != null) ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.clear_all_rounded, size: 16, color: AppColors.error),
                        label: const Text('Reset Filters', style: TextStyle(color: AppColors.error)),
                        onPressed: () {
                          ref.read(doctorFilterProvider.notifier).state = const DoctorFilterState();
                          _searchController.clear();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Medical Specialties Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Specialties', style: AppTypography.headline),
                  if (filterState.specialtyId != null)
                    TextButton(
                      onPressed: () {
                        ref.read(doctorFilterProvider.notifier).state =
                            filterState.copyWith(clearSpecialty: true);
                      },
                      child: const Text('Show All'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              specialtiesAsync.when(
                data: (specialties) {
                  return SizedBox(
                    height: 104,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: specialties.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final spec = specialties[index];
                        final isSelected = filterState.specialtyId == spec.id;

                        return InkWell(
                          onTap: () {
                            ref.read(doctorFilterProvider.notifier).state = filterState.copyWith(
                              specialtyId: isSelected ? null : spec.id,
                              clearSpecialty: isSelected,
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 108,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.2)
                                        : AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getSpecialtyIcon(spec.iconName),
                                    size: 22,
                                    color: isSelected ? Colors.white : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  spec.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Row(
                  children: [
                    SkeletonPlaceholder(width: 100, height: 100),
                    SizedBox(width: 12),
                    SkeletonPlaceholder(width: 100, height: 100),
                  ],
                ),
                error: (e, _) => Text('Failed to load specialties: $e'),
              ),
              const SizedBox(height: 24),

              // Available Doctors Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Verified Specialists', style: AppTypography.headline),
                  doctorsAsync.maybeWhen(
                    data: (docs) => Text(
                      '${docs.length} found',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              doctorsAsync.when(
                data: (doctors) {
                  if (doctors.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.person_search_rounded,
                      title: 'No Doctors Found',
                      description: 'No verified specialists match your search criteria. Try adjusting your filters or search keywords.',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: doctors.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = doctors[index];
                      return _DoctorListCard(doctor: doc);
                    },
                  );
                },
                loading: () => Column(
                  children: List.generate(
                    3,
                    (index) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SkeletonPlaceholder(width: double.infinity, height: 130),
                    ),
                  ),
                ),
                error: (e, _) => ErrorStateView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(filteredDoctorsProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorListCard extends StatelessWidget {
  final DoctorModel doctor;

  const _DoctorListCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    doctor.doctorName.isNotEmpty ? doctor.doctorName[0] : 'D',
                    style: AppTypography.headline.copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              doctor.doctorName,
                              style: AppTypography.headline.copyWith(fontSize: 16),
                            ),
                          ),
                          if (doctor.isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified_rounded, size: 12, color: AppColors.secondary),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Verified',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.secondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doctor.specialtyName,
                        style: AppTypography.subtitle.copyWith(color: AppColors.primary, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFEAB308)),
                          const SizedBox(width: 4),
                          Text(
                            doctor.rating.toStringAsFixed(1),
                            style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${doctor.reviewCount} reviews)',
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.work_outline_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${doctor.experienceYears} yrs exp',
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              doctor.bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium,
            ),
            const Divider(height: 24, color: AppColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Consultation Fee', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                    Text(
                      '\$${doctor.consultationFee.toStringAsFixed(0)}',
                      style: AppTypography.headline.copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => context.push('/patient/doctor/${doctor.id}'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(80, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('Profile'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => context.push('/patient/book/${doctor.id}'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(120, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('Book Slot'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
