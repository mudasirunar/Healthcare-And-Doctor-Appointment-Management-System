import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/smart_search_utils.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/auto_center_filter_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import 'admin_doctor_detail_screen.dart';
import 'admin_patient_detail_screen.dart';
import 'admin_register_patient_screen.dart';

enum AdminDirectorySegment { doctors, patients }

enum DoctorSortMode {
  alphabetical,
  mostExperienced,
  highestRated,
  lowestFee,
  pendingFirst,
}

enum PatientSortMode {
  alphabetical,
  newest,
  withBookings,
}

final adminDirectorySegmentProvider =
    StateProvider<AdminDirectorySegment>((ref) => AdminDirectorySegment.doctors);

/// Selected specialty category ID in the Specialists directory (`null` means "All Specialties").
final adminSelectedSpecialtyProvider = StateProvider<String?>((ref) => null);

/// Incremented whenever an external screen explicitly triggers a directory filter tab.
final adminDirectoryFilterTriggerProvider = StateProvider<int>((ref) => 0);

class AdminDirectoryScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const AdminDirectoryScreen({
    super.key,
    this.scrollController,
  });

  @override
  ConsumerState<AdminDirectoryScreen> createState() =>
      _AdminDirectoryScreenState();
}

class _AdminDirectoryScreenState extends ConsumerState<AdminDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DoctorSortMode _doctorSort = DoctorSortMode.alphabetical;
  PatientSortMode _patientSort = PatientSortMode.alphabetical;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _doctorSortLabel(DoctorSortMode mode) {
    return switch (mode) {
      DoctorSortMode.alphabetical => 'Alphabetical (A–Z)',
      DoctorSortMode.mostExperienced => 'Most Experienced',
      DoctorSortMode.highestRated => 'Highest Rated',
      DoctorSortMode.lowestFee => 'Lowest Consultation Fee',
      DoctorSortMode.pendingFirst => 'Pending Approval Only',
    };
  }

  void _showDoctorFilterBottomSheet(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);
    final isDark = AppColors.isDark(context);
    final activeColor = isDark ? const Color(0xFF38BDF8) : AppColors.primary;

    final options = <(DoctorSortMode, IconData, String, String)>[
      (
        DoctorSortMode.alphabetical,
        Icons.sort_by_alpha_rounded,
        'Alphabetical (A–Z)',
        'Default order by specialist name',
      ),
      (
        DoctorSortMode.mostExperienced,
        Icons.workspace_premium_outlined,
        'Most Experienced',
        'Order by highest years of clinical practice',
      ),
      (
        DoctorSortMode.highestRated,
        Icons.star_outline_rounded,
        'Highest Rated',
        'Order by top patient satisfaction ratings',
      ),
      (
        DoctorSortMode.lowestFee,
        Icons.payments_outlined,
        'Lowest Consultation Fee',
        'Order from lowest to highest consultation fee',
      ),
      (
        DoctorSortMode.pendingFirst,
        Icons.verified_user_outlined,
        'Pending Approval Only',
        'Show only specialists awaiting license review',
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sort & Filter Specialists',
                        style: AppTypography.headline.copyWith(
                          color: textPrimary,
                        ),
                      ),
                      if (_doctorSort != DoctorSortMode.alphabetical)
                        TextButton(
                          onPressed: () {
                            setState(
                              () => _doctorSort = DoctorSortMode.alphabetical,
                            );
                            Navigator.pop(ctx);
                          },
                          child: const Text('Reset'),
                        ),
                    ],
                  ),
                ),
                Divider(height: 1, color: borderColor),
                ...options.map((opt) {
                  final mode = opt.$1;
                  final icon = opt.$2;
                  final title = opt.$3;
                  final subtitle = opt.$4;
                  final isSelected = _doctorSort == mode;

                  return InkWell(
                    onTap: () {
                      setState(() => _doctorSort = mode);
                      Navigator.pop(ctx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? activeColor.withValues(alpha: 0.14)
                                  : AppColors.surfaceVariantOf(context),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              size: 20,
                              color: isSelected ? activeColor : textSecondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color:
                                        isSelected ? activeColor : textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: AppTypography.caption.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: activeColor,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final segment = ref.watch(adminDirectorySegmentProvider);
    final selectedSpecialtyId = ref.watch(adminSelectedSpecialtyProvider);
    final filterTrigger = ref.watch(adminDirectoryFilterTriggerProvider);
    final doctorsAsync = ref.watch(allDoctorsAdminProvider);
    final patientsAsync = ref.watch(allPatientsAdminProvider);
    final specialties = ref.watch(specialtiesProvider).valueOrNull ?? [];
    final appointments =
        ref.watch(allAppointmentsAdminProvider).valueOrNull ?? [];

    final isDark = AppColors.isDark(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);

    return Column(
      children: [
        // 1. Top Segmented Switcher (Doctors | Patients) + Contextual Stats Strip
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            children: [
              Container(
                height: 42,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariantOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    _SegmentButton(
                      label:
                          'Specialists (${doctorsAsync.valueOrNull?.length ?? 0})',
                      isSelected: segment == AdminDirectorySegment.doctors,
                      onTap: () => ref
                          .read(adminDirectorySegmentProvider.notifier)
                          .state = AdminDirectorySegment.doctors,
                    ),
                    _SegmentButton(
                      label:
                          'Patients (${patientsAsync.valueOrNull?.length ?? 0})',
                      isSelected: segment == AdminDirectorySegment.patients,
                      onTap: () => ref
                          .read(adminDirectorySegmentProvider.notifier)
                          .state = AdminDirectorySegment.patients,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 2. Reusable Smart Search Bar + Filter Button (for Doctors)
              Row(
                children: [
                  Expanded(
                    child: AppSearchBar(
                      controller: _searchController,
                      hintText: segment == AdminDirectorySegment.doctors
                          ? 'Search name, specialty, license, bio, fee...'
                          : 'Search patient name, email, blood group, allergies...',
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  if (segment == AdminDirectorySegment.doctors) ...[
                    const SizedBox(width: 10),
                    Tooltip(
                      message: 'Sort & Filter: ${_doctorSortLabel(_doctorSort)}',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showDoctorFilterBottomSheet(context),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _doctorSort != DoctorSortMode.alphabetical
                                ? AppColors.primary.withValues(alpha: 0.14)
                                : AppColors.surfaceVariantOf(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _doctorSort != DoctorSortMode.alphabetical
                                  ? AppColors.primary
                                  : borderColor,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 21,
                                color: _doctorSort != DoctorSortMode.alphabetical
                                    ? AppColors.primary
                                    : textPrimary,
                              ),
                              if (_doctorSort != DoctorSortMode.alphabetical)
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (segment == AdminDirectorySegment.patients) ...[
                    const SizedBox(width: 10),
                    Tooltip(
                      message: 'Register New Patient',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AdminRegisterPatientScreen(),
                            ),
                          );
                        },
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(
                              alpha: isDark ? 0.20 : 0.14,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  AppColors.secondary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_add_alt_1_rounded,
                                size: 19,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Add',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // 3. Category Chips for Doctors (or Sort Chips for Patients)
        if (segment == AdminDirectorySegment.doctors) ...[
          AutoCenterFilterBar(
            focusItemId: selectedSpecialtyId ?? 'all_specialties',
            scrollTrigger: filterTrigger,
            items: [
              AutoCenterFilterItem(
                id: 'all_specialties',
                label: 'All Specialties',
                isSelected: selectedSpecialtyId == null,
                onTap: () => ref
                    .read(adminSelectedSpecialtyProvider.notifier)
                    .state = null,
              ),
              ...specialties.map((spec) {
                final selected = selectedSpecialtyId == spec.id;
                return AutoCenterFilterItem(
                  id: spec.id,
                  label: spec.name,
                  isSelected: selected,
                  onTap: () => ref
                      .read(adminSelectedSpecialtyProvider.notifier)
                      .state = selected ? null : spec.id,
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
        ] else ...[
          AutoCenterFilterBar(
            focusItemId: 'pt_sort_${_patientSort.name}',
            scrollTrigger: filterTrigger,
            items: [
              AutoCenterFilterItem(
                id: 'pt_sort_${PatientSortMode.alphabetical.name}',
                label: 'A–Z',
                isSelected: _patientSort == PatientSortMode.alphabetical,
                onTap: () => setState(
                  () => _patientSort = PatientSortMode.alphabetical,
                ),
              ),
              AutoCenterFilterItem(
                id: 'pt_sort_${PatientSortMode.newest.name}',
                label: 'Newest Registered',
                isSelected: _patientSort == PatientSortMode.newest,
                onTap: () =>
                    setState(() => _patientSort = PatientSortMode.newest),
              ),
              AutoCenterFilterItem(
                id: 'pt_sort_${PatientSortMode.withBookings.name}',
                label: 'Has Appointments',
                isSelected: _patientSort == PatientSortMode.withBookings,
                onTap: () => setState(
                  () => _patientSort = PatientSortMode.withBookings,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        Divider(height: 1, color: borderColor),

        // 4. Flat Directory List
        Expanded(
          child: segment == AdminDirectorySegment.doctors
              ? doctorsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorStateView(message: e.toString()),
                  data: (doctors) {
                    var filtered = doctors;
                    if (selectedSpecialtyId != null) {
                      filtered = filtered
                          .where((d) => d.specialtyId == selectedSpecialtyId)
                          .toList();
                    }
                    if (_doctorSort == DoctorSortMode.pendingFirst) {
                      filtered = filtered
                          .where(
                            (d) =>
                                d.verificationStatus ==
                                VerificationStatus.pending,
                          )
                          .toList();
                    }

                    final results = SmartSearchEngine.filterAndSort<DoctorModel>(
                      items: filtered,
                      query: _searchQuery,
                      primaryTextBuilder: (d) => d.doctorName,
                      secondaryTextsBuilder: (d) => [
                        d.specialtyName,
                        d.specialtyId,
                        d.licenseNumber,
                        d.bio,
                        d.id,
                        '${d.experienceYears} years',
                        '\$${d.consultationFee.toStringAsFixed(0)}',
                        d.verificationStatus.displayName,
                      ],
                      fallbackComparator: (a, b) {
                        switch (_doctorSort) {
                          case DoctorSortMode.mostExperienced:
                            return b.experienceYears.compareTo(
                              a.experienceYears,
                            );
                          case DoctorSortMode.highestRated:
                            final r = b.rating.compareTo(a.rating);
                            if (r != 0) return r;
                            return b.reviewCount.compareTo(a.reviewCount);
                          case DoctorSortMode.lowestFee:
                            return a.consultationFee.compareTo(
                              b.consultationFee,
                            );
                          case DoctorSortMode.alphabetical:
                          case DoctorSortMode.pendingFirst:
                            return a.doctorName
                                .toLowerCase()
                                .replaceFirst('dr. ', '')
                                .compareTo(
                                  b.doctorName
                                      .toLowerCase()
                                      .replaceFirst('dr. ', ''),
                                );
                        }
                      },
                    );

                    if (results.isEmpty) {
                      return Center(
                        child: Text(
                          'No matching specialists found.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.only(top: 4, bottom: 118),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 80,
                        endIndent: 20,
                        color: borderColor,
                      ),
                      itemBuilder: (context, index) {
                        final doc = results[index];
                        final isPending = doc.verificationStatus ==
                            VerificationStatus.pending;

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AdminDoctorDetailScreen(doctorId: doc.id),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    doc.doctorName
                                        .replaceFirst('Dr. ', '')
                                        .characters
                                        .first
                                        .toUpperCase(),
                                    style: AppTypography.headline.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              doc.doctorName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.bodyLarge
                                                  .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (isPending)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.warning
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Pending',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                  color: AppColors.warning,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              '${doc.rating.toStringAsFixed(1)} ★',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${doc.specialtyName} • ${doc.experienceYears} yrs exp • \$${doc.consultationFee.toStringAsFixed(0)} fee',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.caption.copyWith(
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                )
              : patientsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorStateView(message: e.toString()),
                  data: (patients) {
                    final patientBookingCounts = <String, int>{};
                    for (final a in appointments) {
                      patientBookingCounts[a.patientId] =
                          (patientBookingCounts[a.patientId] ?? 0) + 1;
                    }

                    var filtered = patients;
                    if (_patientSort == PatientSortMode.withBookings) {
                      filtered = filtered
                          .where((p) => (patientBookingCounts[p.id] ?? 0) > 0)
                          .toList();
                    }

                    final results = SmartSearchEngine.filterAndSort<UserModel>(
                      items: filtered,
                      query: _searchQuery,
                      primaryTextBuilder: (p) => p.displayName,
                      secondaryTextsBuilder: (p) => [
                        p.email,
                        p.phoneNumber,
                        p.bloodGroup,
                        p.medicalAllergies,
                        p.gender,
                        p.dateOfBirth,
                        p.id,
                      ],
                      fallbackComparator: (a, b) {
                        switch (_patientSort) {
                          case PatientSortMode.newest:
                            return b.createdAt.compareTo(a.createdAt);
                          case PatientSortMode.withBookings:
                            final countCmp = (patientBookingCounts[b.id] ?? 0)
                                .compareTo(patientBookingCounts[a.id] ?? 0);
                            if (countCmp != 0) return countCmp;
                            return a.displayName
                                .toLowerCase()
                                .compareTo(b.displayName.toLowerCase());
                          case PatientSortMode.alphabetical:
                            return a.displayName
                                .toLowerCase()
                                .compareTo(b.displayName.toLowerCase());
                        }
                      },
                    );

                    if (results.isEmpty) {
                      return Center(
                        child: Text(
                          'No matching patients found.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.only(top: 4, bottom: 118),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 80,
                        endIndent: 20,
                        color: borderColor,
                      ),
                      itemBuilder: (context, index) {
                        final patient = results[index];
                        final bookingCount =
                            patientBookingCounts[patient.id] ?? 0;

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminPatientDetailScreen(
                                  patientId: patient.id,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    patient.displayName.isNotEmpty
                                        ? patient.displayName[0].toUpperCase()
                                        : 'P',
                                    style: AppTypography.headline.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              patient.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.bodyLarge
                                                  .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary,
                                              ),
                                            ),
                                          ),
                                          if (patient.bloodGroup != null &&
                                              patient
                                                  .bloodGroup!.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.10),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                patient.bloodGroup!,
                                                style: AppTypography.caption
                                                    .copyWith(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${patient.email} • $bookingCount ${bookingCount == 1 ? 'appointment' : 'appointments'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.caption.copyWith(
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceOf(context) : null,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.05,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AppColors.textPrimaryOf(context)
                  : AppColors.textSecondaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

