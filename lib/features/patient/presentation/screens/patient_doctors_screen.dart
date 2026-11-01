import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/smart_search_utils.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/auto_center_filter_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import 'booking_screen.dart';
import 'doctor_details_screen.dart';

enum PatientDoctorSortMode {
  alphabetical,
  highestRated,
  mostExperienced,
  lowestFee,
}

class PatientDoctorsScreen extends ConsumerStatefulWidget {
  final String? initialSpecialtyId;

  const PatientDoctorsScreen({
    super.key,
    this.initialSpecialtyId,
  });

  @override
  ConsumerState<PatientDoctorsScreen> createState() => _PatientDoctorsScreenState();
}

class _PatientDoctorsScreenState extends ConsumerState<PatientDoctorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late String _selectedSpecialtyId;
  PatientDoctorSortMode _sortMode = PatientDoctorSortMode.alphabetical;
  double? _selectedMinRating;
  double? _selectedMaxFee;

  @override
  void initState() {
    super.initState();
    _selectedSpecialtyId = widget.initialSpecialtyId ?? 'all';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _sortModeLabel(PatientDoctorSortMode mode) {
    return switch (mode) {
      PatientDoctorSortMode.highestRated => 'Highest Rated',
      PatientDoctorSortMode.mostExperienced => 'Most Experienced',
      PatientDoctorSortMode.lowestFee => 'Lowest Fee',
      PatientDoctorSortMode.alphabetical => 'Alphabetical (A–Z)',
    };
  }

  void _showFilterModal(BuildContext context) {
    final borderColor = AppColors.borderOf(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sort & Filter Specialists',
                      style: AppTypography.headline.copyWith(
                        fontSize: 18,
                        color: textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedMinRating = null;
                          _selectedMaxFee = null;
                          _sortMode = PatientDoctorSortMode.alphabetical;
                        });
                        setState(() {});
                      },
                      child: const Text('Reset', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  'Sort Specialists By',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PatientDoctorSortMode.values.map((mode) {
                    final isSelected = _sortMode == mode;
                    return _buildModalChip(
                      _sortModeLabel(mode),
                      isSelected,
                      () {
                        setModalState(() => _sortMode = mode);
                        setState(() {});
                      },
                      borderColor,
                      textSecondary,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                Text(
                  'Minimum Rating',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildModalChip('Any', _selectedMinRating == null, () {
                      setModalState(() => _selectedMinRating = null);
                      setState(() {});
                    }, borderColor, textSecondary),
                    const SizedBox(width: 8),
                    _buildModalChip('4.0+ ★', _selectedMinRating == 4.0, () {
                      setModalState(() => _selectedMinRating = 4.0);
                      setState(() {});
                    }, borderColor, textSecondary),
                    const SizedBox(width: 8),
                    _buildModalChip('4.5+ ★', _selectedMinRating == 4.5, () {
                      setModalState(() => _selectedMinRating = 4.5);
                      setState(() {});
                    }, borderColor, textSecondary),
                    const SizedBox(width: 8),
                    _buildModalChip('4.8+ ★', _selectedMinRating == 4.8, () {
                      setModalState(() => _selectedMinRating = 4.8);
                      setState(() {});
                    }, borderColor, textSecondary),
                  ],
                ),
                const SizedBox(height: 18),

                Text(
                  'Max Consultation Fee',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildModalChip('Any', _selectedMaxFee == null, () {
                      setModalState(() => _selectedMaxFee = null);
                      setState(() {});
                    }, borderColor, textSecondary),
                    const SizedBox(width: 8),
                    _buildModalChip('Under \$50', _selectedMaxFee == 50.0, () {
                      setModalState(() => _selectedMaxFee = 50.0);
                      setState(() {});
                    }, borderColor, textSecondary),
                    const SizedBox(width: 8),
                    _buildModalChip('Under \$100', _selectedMaxFee == 100.0, () {
                      setModalState(() => _selectedMaxFee = 100.0);
                      setState(() {});
                    }, borderColor, textSecondary),
                  ],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    Color borderColor,
    Color textSecondary,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(verifiedDoctorsStreamProvider);
    final specialties = ref.watch(specialtiesProvider).valueOrNull ?? [];

    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);

    final hasActiveFilter = _selectedMinRating != null ||
        _selectedMaxFee != null ||
        _sortMode != PatientDoctorSortMode.alphabetical;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Specialist Directory'),
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
      ),
      body: Column(
        children: [
          // 1. Search Bar + Filter Trigger Strip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchBar(
                    controller: _searchController,
                    hintText: 'Search name, specialty, clinical bio...',
                    onChanged: (val) => setState(() => _searchQuery = val),
                    onClear: () => setState(() => _searchQuery = ''),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showFilterModal(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasActiveFilter
                          ? AppColors.primary.withValues(alpha: 0.14)
                          : surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasActiveFilter ? AppColors.primary : borderColor,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: hasActiveFilter ? AppColors.primary : textPrimary,
                        ),
                        if (hasActiveFilter)
                          Positioned(
                            top: 9,
                            right: 9,
                            child: Container(
                              width: 6,
                              height: 6,
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
              ],
            ),
          ),

          // 2. Specialty Auto-centering Tabs
          if (specialties.isNotEmpty) ...[
            AutoCenterFilterBar(
              items: [
                AutoCenterFilterItem(
                  id: 'all',
                  label: 'All Departments',
                  isSelected: _selectedSpecialtyId == 'all',
                  onTap: () => setState(() => _selectedSpecialtyId = 'all'),
                ),
                ...specialties.map(
                  (spec) => AutoCenterFilterItem(
                    id: spec.id,
                    label: spec.name,
                    isSelected: _selectedSpecialtyId == spec.id,
                    onTap: () => setState(() => _selectedSpecialtyId = spec.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          Divider(height: 1, color: borderColor),

          // 3. Flat Directory List
          Expanded(
            child: doctorsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              error: (err, _) => ErrorStateView(
                message: 'Unable to load specialists: $err',
                onRetry: () => ref.invalidate(verifiedDoctorsStreamProvider),
              ),
              data: (allDoctors) {
                var filtered = allDoctors;

                // Specialty filter
                if (_selectedSpecialtyId != 'all') {
                  filtered = filtered
                      .where((d) => d.specialtyId == _selectedSpecialtyId)
                      .toList();
                }

                // Minimum Rating
                if (_selectedMinRating != null) {
                  filtered = filtered
                      .where((d) => d.rating >= _selectedMinRating!)
                      .toList();
                }

                // Maximum Fee
                if (_selectedMaxFee != null) {
                  filtered = filtered
                      .where((d) => d.consultationFee <= _selectedMaxFee!)
                      .toList();
                }

                // Search & Sort Engine
                final results = SmartSearchEngine.filterAndSort<DoctorModel>(
                  items: filtered,
                  query: _searchQuery,
                  primaryTextBuilder: (d) => d.doctorName,
                  secondaryTextsBuilder: (d) => [
                    d.specialtyName,
                    d.bio,
                    '\$${d.consultationFee.toStringAsFixed(0)}',
                    '${d.experienceYears}y exp',
                  ],
                  fallbackComparator: (a, b) {
                    switch (_sortMode) {
                      case PatientDoctorSortMode.highestRated:
                        final r = b.rating.compareTo(a.rating);
                        if (r != 0) return r;
                        return b.reviewCount.compareTo(a.reviewCount);
                      case PatientDoctorSortMode.mostExperienced:
                        return b.experienceYears.compareTo(a.experienceYears);
                      case PatientDoctorSortMode.lowestFee:
                        return a.consultationFee.compareTo(b.consultationFee);
                      case PatientDoctorSortMode.alphabetical:
                        return a.doctorName
                            .toLowerCase()
                            .replaceFirst(RegExp(r'^dr\.\s*'), '')
                            .compareTo(
                              b.doctorName
                                  .toLowerCase()
                                  .replaceFirst(RegExp(r'^dr\.\s*'), ''),
                            );
                    }
                  },
                );

                if (results.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                      child: EmptyStateView(
                        icon: Icons.search_off_rounded,
                        title: 'No Specialists Found',
                        description:
                            'No medical practitioners match your active criteria. Try broadening your search or resetting filters.',
                        actionLabel: 'Reset All Filters',
                        onAction: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _selectedSpecialtyId = 'all';
                            _selectedMinRating = null;
                            _selectedMaxFee = null;
                            _sortMode = PatientDoctorSortMode.alphabetical;
                          });
                        },
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(top: 4, bottom: 40),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 76,
                    endIndent: 20,
                    color: borderColor,
                  ),
                  itemBuilder: (ctx, idx) {
                    final doc = results[idx];
                    return _FlatDirectoryDoctorRow(
                      doctor: doc,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DoctorDetailsScreen(doctorId: doc.id),
                          ),
                        );
                      },
                      onBook: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingScreen(doctorId: doc.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FlatDirectoryDoctorRow extends StatelessWidget {
  final DoctorModel doctor;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;
  final VoidCallback onBook;

  const _FlatDirectoryDoctorRow({
    required this.doctor,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: doctor.avatarUrl != null
                  ? NetworkImage(doctor.avatarUrl!)
                  : null,
              child: doctor.avatarUrl == null
                  ? Text(
                      doctor.doctorName.isNotEmpty
                          ? doctor.doctorName
                              .replaceFirst(RegExp(r'^Dr\.\s*'), '')
                              .characters
                              .first
                              .toUpperCase()
                          : 'D',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          doctor.doctorName,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 14, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doctor.specialtyName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${doctor.experienceYears}y exp • \$${doctor.consultationFee.toStringAsFixed(0)} fee',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text(
                        doctor.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        ' (${doctor.reviewCount})',
                        style: TextStyle(fontSize: 10.5, color: textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Book',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

