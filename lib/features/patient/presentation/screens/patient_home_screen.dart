import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/smart_search_utils.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/auto_center_filter_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import '../../../consultation/presentation/screens/appointment_chat_screen.dart';
import '../../../consultation/presentation/screens/video_consultation_screen.dart';
import 'booking_screen.dart';
import 'doctor_details_screen.dart';
import 'patient_care_insights_screen.dart';
import 'patient_specialties_screen.dart';
import 'patient_specialty_doctors_screen.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const PatientHomeScreen({super.key, this.scrollController});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController;
  final GlobalKey _directoryKey = GlobalKey();

  String _selectedSpecialty = 'All';
  double? _selectedMinRating; // null | 4.0 | 4.5 | 4.8
  double? _selectedMaxFee; // null | 50.0 | 80.0 | 120.0
  String _sortMode = 'rating'; // 'rating' | 'fee' | 'exp'

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final borderColor = AppColors.borderOf(ctx);
          final textPrimary = AppColors.textPrimaryOf(ctx);
          final textSecondary = AppColors.textSecondaryOf(ctx);

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
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
                      'Filter Specialists',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedMinRating = null;
                          _selectedMaxFee = null;
                          _sortMode = 'rating';
                        });
                        setState(() {});
                      },
                      child: const Text('Reset All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Minimum Rating
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
                    _buildModalChip('★ 4.0+', _selectedMinRating == 4.0, () {
                      setModalState(() => _selectedMinRating = 4.0);
                      setState(() {});
                    }, borderColor, textSecondary),
                    const SizedBox(width: 8),
                    _buildModalChip('★ 4.5+', _selectedMinRating == 4.5, () {
                      setModalState(() => _selectedMinRating = 4.5);
                      setState(() {});
                    }, borderColor, textSecondary),
                    const SizedBox(width: 8),
                    _buildModalChip('★ 4.8+', _selectedMinRating == 4.8, () {
                      setModalState(() => _selectedMinRating = 4.8);
                      setState(() {});
                    }, borderColor, textSecondary),
                  ],
                ),
                const SizedBox(height: 18),

                // Maximum Consultation Fee
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
                    _buildModalChip('≤ \$50', _selectedMaxFee == 50.0, () {
                      setModalState(() => _selectedMaxFee = 50.0);
                      setState(() {});
                    }, borderColor, textSecondary),
                    const SizedBox(width: 8),
                    _buildModalChip('≤ \$80', _selectedMaxFee == 80.0, () {
                      setModalState(() => _selectedMaxFee = 80.0);
                      setState(() {});
                    }, borderColor, textSecondary),
                    const SizedBox(width: 8),
                    _buildModalChip('≤ \$120', _selectedMaxFee == 120.0, () {
                      setModalState(() => _selectedMaxFee = 120.0);
                      setState(() {});
                    }, borderColor, textSecondary),
                  ],
                ),
                const SizedBox(height: 18),

                // Sort Order
                Text(
                  'Sort Specialists By',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildModalChip('Highest Rating', _sortMode == 'rating', () {
                      setModalState(() => _sortMode = 'rating');
                      setState(() {});
                    }, borderColor, textSecondary),
                    const SizedBox(width: 8),
                    _buildModalChip('Lowest Fee', _sortMode == 'fee', () {
                      setModalState(() => _sortMode = 'fee');
                      setState(() {});
                    }, borderColor, textSecondary),
                    const SizedBox(width: 8),
                    _buildModalChip('Experience', _sortMode == 'exp', () {
                      setModalState(() => _sortMode = 'exp');
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
                    child: const Text('Apply Filters',
                        style: TextStyle(fontWeight: FontWeight.w700)),
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
    final isDark = AppColors.isDark(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    final specialtiesAsync = ref.watch(specialtiesProvider);
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final allAppointments = appointmentsAsync.valueOrNull ?? [];

    final upcomingAppointments = allAppointments
        .where((a) =>
            a.status == AppointmentStatus.confirmed ||
            a.status == AppointmentStatus.requested ||
            a.status == AppointmentStatus.inProgress)
        .toList();

    final completedAppointments = allAppointments
        .where((a) => a.status == AppointmentStatus.completed)
        .toList();

    final visitedDoctorIds = completedAppointments
        .map((a) => a.doctorId)
        .where((id) => id.isNotEmpty)
        .toSet();

    final doctorsAsync = ref.watch(verifiedDoctorsStreamProvider);
    final allDoctors = doctorsAsync.valueOrNull ?? [];

    // Map visited doctor IDs to DoctorModel instances
    final visitedDoctors = allDoctors
        .where((d) => visitedDoctorIds.contains(d.id))
        .toList();

    // Compute specialties list
    final specialties = specialtiesAsync.valueOrNull ?? [];
    final specialtyNames = ['All', ...specialties.map((s) => s.name)];

    // Calculate doctor count per specialty
    final Map<String, int> doctorCountBySpecialtyId = {};
    for (final spec in specialties) {
      doctorCountBySpecialtyId[spec.id] =
          allDoctors.where((d) => d.specialtyId == spec.id).length;
    }

    // Top-rated specialists (rating >= 4.5, sorted by rating desc, review count desc)
    final topRatedDoctors = List<DoctorModel>.from(allDoctors)
      ..sort((a, b) {
        final rCmp = b.rating.compareTo(a.rating);
        if (rCmp != 0) return rCmp;
        return b.reviewCount.compareTo(a.reviewCount);
      });
    final topSpecialistsPreview = topRatedDoctors.take(4).toList();

    // Calculate Personal Care Insights
    String insightSubtitle;
    VoidCallback? insightOnTap;

    if (completedAppointments.isNotEmpty) {
      final Map<String, int> docVisits = {};
      final Map<String, String> docNames = {};
      final Map<String, int> specVisits = {};

      for (final a in completedAppointments) {
        if (a.doctorId.isNotEmpty) {
          docVisits[a.doctorId] = (docVisits[a.doctorId] ?? 0) + 1;
          if (a.doctorName.isNotEmpty) {
            docNames[a.doctorId] = a.doctorName;
          }
        }
        final spec = a.doctorSpecialty.isNotEmpty
            ? a.doctorSpecialty
            : allDoctors.where((d) => d.id == a.doctorId).firstOrNull?.specialtyName;
        if (spec != null && spec.isNotEmpty) {
          specVisits[spec] = (specVisits[spec] ?? 0) + 1;
        }
      }

      String? topDocId;
      int topDocCount = 0;
      docVisits.forEach((id, count) {
        if (count > topDocCount) {
          topDocCount = count;
          topDocId = id;
        }
      });

      String? topSpec;
      int topSpecCount = 0;
      specVisits.forEach((spec, count) {
        if (count > topSpecCount) {
          topSpecCount = count;
          topSpec = spec;
        }
      });

      final topDocName = allDoctors.where((d) => d.id == topDocId).firstOrNull?.doctorName ??
          (topDocId != null ? docNames[topDocId] : null);

      if (topDocName != null) {
        final visitWord = topDocCount == 1 ? 'visit' : 'visits';
        if (topSpec != null) {
          final pct = ((topSpecCount / completedAppointments.length) * 100).round();
          insightSubtitle = 'Top Doctor: $topDocName ($topDocCount $visitWord) • Dept: $topSpec ($pct%)';
        } else {
          insightSubtitle = 'Most Visited Doctor: $topDocName ($topDocCount $visitWord)';
        }
      } else {
        insightSubtitle = '${completedAppointments.length} completed consultation${completedAppointments.length == 1 ? '' : 's'} on record';
      }
    } else if (upcomingAppointments.isNotEmpty) {
      final next = upcomingAppointments.first;
      insightSubtitle = 'Upcoming: Dr. ${next.doctorName.replaceFirst(RegExp(r'^Dr\.\s*'), '')} • ${DateTimeUtils.formatLocalDate(next.scheduledTimeUtc)}';
    } else {
      insightSubtitle = 'Tap to view health trends, visit history, and consultation stats';
    }

    // Always navigate to the dedicated Personal Care Insights screen, mirroring Admin Overview
    insightOnTap = () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PatientCareInsightsScreen(),
        ),
      );
    };

    // Check if search or active filters are applied
    final searchQuery = _searchController.text.trim();
    final hasActiveFilter = _selectedMinRating != null ||
        _selectedMaxFee != null ||
        _sortMode != 'rating';
    final isSearchMode = searchQuery.isNotEmpty ||
        _selectedSpecialty != 'All' ||
        hasActiveFilter;

    // Filter doctors for the full directory view
    List<DoctorModel> filteredDoctors = List<DoctorModel>.from(allDoctors);
    if (_selectedSpecialty != 'All') {
      filteredDoctors = filteredDoctors
          .where((d) => d.specialtyName.toLowerCase() == _selectedSpecialty.toLowerCase())
          .toList();
    }
    if (_selectedMinRating != null) {
      filteredDoctors = filteredDoctors
          .where((d) => d.rating >= _selectedMinRating!)
          .toList();
    }
    if (_selectedMaxFee != null) {
      filteredDoctors = filteredDoctors
          .where((d) => d.consultationFee <= _selectedMaxFee!)
          .toList();
    }
    if (searchQuery.isNotEmpty) {
      filteredDoctors = SmartSearchEngine.filterAndSort<DoctorModel>(
        items: filteredDoctors,
        query: searchQuery,
        primaryTextBuilder: (d) => d.doctorName,
        secondaryTextsBuilder: (d) => [d.specialtyName, d.bio],
      );
    } else {
      if (_sortMode == 'rating') {
        filteredDoctors.sort((a, b) => b.rating.compareTo(a.rating));
      } else if (_sortMode == 'fee') {
        filteredDoctors.sort((a, b) => a.consultationFee.compareTo(b.consultationFee));
      } else if (_sortMode == 'exp') {
        filteredDoctors.sort((a, b) => b.experienceYears.compareTo(a.experienceYears));
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // 1. Search Bar with Filter Trigger
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: AppSearchBar(
                      controller: _searchController,
                      hintText: 'Search doctors, specialties, clinics...',
                      onChanged: (_) => setState(() {}),
                      onClear: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showFilterModal(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: hasActiveFilter
                            ? AppColors.primary
                            : (isDark ? surfaceColor : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasActiveFilter ? AppColors.primary : borderColor,
                        ),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: hasActiveFilter ? Colors.white : textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Active Filters Strip
          if (hasActiveFilter)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedMinRating != null) ...[
                        _buildActiveFilterTag(
                          'Rating: ★ ${_selectedMinRating!}+',
                          () => setState(() => _selectedMinRating = null),
                          borderColor,
                          textSecondary,
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (_selectedMaxFee != null) ...[
                        _buildActiveFilterTag(
                          'Max Fee: ≤ \$${_selectedMaxFee!.toInt()}',
                          () => setState(() => _selectedMaxFee = null),
                          borderColor,
                          textSecondary,
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (_sortMode != 'rating') ...[
                        _buildActiveFilterTag(
                          'Sort: ${_sortMode == 'fee' ? 'Lowest Fee' : 'Experience'}',
                          () => setState(() => _sortMode = 'rating'),
                          borderColor,
                          textSecondary,
                        ),
                        const SizedBox(width: 6),
                      ],
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedMinRating = null;
                            _selectedMaxFee = null;
                            _sortMode = 'rating';
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Clear All', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. Specialties Horizontal Filter Chips Strip
          SliverToBoxAdapter(
            child: AutoCenterFilterBar(
              items: specialtyNames.map((name) {
                return AutoCenterFilterItem(
                  id: name,
                  label: name,
                  isSelected: _selectedSpecialty == name,
                  onTap: () => setState(() => _selectedSpecialty = name),
                );
              }).toList(),
            ),
          ),

          // -------------------------------------------------------------
          // DASHBOARD SECTIONS (Shown when not in active keyword search)
          // -------------------------------------------------------------
          if (!isSearchMode) ...[
            // 4. Actionable Ongoing Consultation Ribbon (if any active appointment)
            if (upcomingAppointments.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: _buildActionableConsultationRibbon(
                    context,
                    upcomingAppointments.first,
                    isDark: isDark,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              ),
            ],

            // 5. Personal Health & Consultation Stats Grid (2x2 Flat Cards)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _DashboardMetricTile(
                          title: 'Upcoming',
                          value: '${upcomingAppointments.length}',
                          subtitle: 'Scheduled visits',
                          icon: Icons.calendar_month_outlined,
                          onTap: () {
                            ref.read(patientSelectedTabProvider.notifier).state = 1;
                          },
                        ),
                        const SizedBox(width: 12),
                        _DashboardMetricTile(
                          title: 'Completed',
                          value: '${completedAppointments.length}',
                          subtitle: 'Past visits',
                          icon: Icons.check_circle_outline_rounded,
                          onTap: () {
                            ref.read(patientSelectedTabProvider.notifier).state = 1;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _DashboardMetricTile(
                          title: 'Prescriptions',
                          value: '${completedAppointments.where((a) => a.consultationNotes != null || a.prescriptionId != null).length}',
                          subtitle: 'Active records',
                          icon: Icons.medication_outlined,
                          onTap: () {
                            ref.read(patientSelectedTabProvider.notifier).state = 2;
                          },
                        ),
                        const SizedBox(width: 12),
                        _DashboardMetricTile(
                          title: 'Specialists Visited',
                          value: '${visitedDoctorIds.length}',
                          subtitle: 'Care network',
                          icon: Icons.people_outline_rounded,
                          onTap: () {
                            if (visitedDoctors.isNotEmpty) {
                              _scrollToKey(_directoryKey);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 6. Quick Action Dock
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Row(
                  children: [
                    _QuickActionButton(
                      icon: Icons.person_search_rounded,
                      label: 'Find Doctor',
                      onTap: () => _scrollToKey(_directoryKey),
                    ),
                    const SizedBox(width: 10),
                    _QuickActionButton(
                      icon: Icons.category_outlined,
                      label: 'Specialties',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PatientSpecialtiesScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _QuickActionButton(
                      icon: Icons.calendar_today_outlined,
                      label: 'Appointments',
                      onTap: () {
                        ref.read(patientSelectedTabProvider.notifier).state = 1;
                      },
                    ),
                    const SizedBox(width: 10),
                    _QuickActionButton(
                      icon: Icons.receipt_long_outlined,
                      label: 'Prescriptions',
                      onTap: () {
                        ref.read(patientSelectedTabProvider.notifier).state = 2;
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 6.1 Flat Personal Care Insights Row (Matching Admin Overview layout & style)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Divider(height: 1, color: borderColor),
                  InkWell(
                    onTap: insightOnTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.insights_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Personal Care Insights',
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  insightSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: textSecondary),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: borderColor),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // 7. Medical Specialties Showcase (with Live Doctor Counts)
            if (specialties.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medical Specialties',
                            style: AppTypography.headline.copyWith(
                              fontSize: 17,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Clinical departments & verified specialists',
                            style: AppTypography.caption.copyWith(color: textSecondary),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PatientSpecialtiesScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                        label: const Text('See All'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 108,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: specialties.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (ctx, idx) {
                      final spec = specialties[idx];
                      final docCount = doctorCountBySpecialtyId[spec.id] ?? 0;

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PatientSpecialtyDoctorsScreen(specialty: spec),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  spec.iconData,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 7),
                              SizedBox(
                                width: 84,
                                child: Text(
                                  spec.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$docCount Doc${docCount == 1 ? '' : 's'}',
                                textAlign: TextAlign.center,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 10.5,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    Divider(height: 1, color: borderColor),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],

            // 8. Top-Rated Specialists Section
            if (topSpecialistsPreview.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top-Rated Specialists',
                            style: AppTypography.headline.copyWith(
                              fontSize: 17,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Highest patient reviews & recommendations',
                            style: AppTypography.caption.copyWith(color: textSecondary),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => _scrollToKey(_directoryKey),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, idx) {
                    final doc = topSpecialistsPreview[idx];
                    return Column(
                      children: [
                        _FlatPatientDoctorRow(
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
                        ),
                        Divider(height: 1, indent: 76, endIndent: 20, color: borderColor),
                      ],
                    );
                  },
                  childCount: topSpecialistsPreview.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],

            // 9. Previously Visited Doctors Section (if any completed appointments)
            if (visitedDoctors.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Past Consultations',
                        style: AppTypography.headline.copyWith(
                          fontSize: 17,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Doctors you have consulted previously for easy follow-up',
                        style: AppTypography.caption.copyWith(color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, idx) {
                    final doc = visitedDoctors[idx];
                    return Column(
                      children: [
                        _FlatPatientDoctorRow(
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
                        ),
                        Divider(height: 1, indent: 76, endIndent: 20, color: borderColor),
                      ],
                    );
                  },
                  childCount: visitedDoctors.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ],

          // -------------------------------------------------------------
          // SPECIALIST DIRECTORY SECTION HEADER
          // -------------------------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              key: _directoryKey,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSearchMode ? 'Search Results' : 'Specialist Directory',
                        style: AppTypography.headline.copyWith(
                          fontSize: 17,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${filteredDoctors.length} Verified Specialist${filteredDoctors.length == 1 ? '' : 's'} Available',
                        style: AppTypography.caption.copyWith(color: textSecondary),
                      ),
                    ],
                  ),
                  if (isSearchMode)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _selectedSpecialty = 'All';
                          _selectedMinRating = null;
                          _selectedMaxFee = null;
                          _sortMode = 'rating';
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Reset Search'),
                    ),
                ],
              ),
            ),
          ),

          // -------------------------------------------------------------
          // VERIFIED SPECIALISTS LIST
          // -------------------------------------------------------------
          doctorsAsync.when(
            data: (_) {
              if (filteredDoctors.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                      child: EmptyStateView(
                        icon: Icons.search_off_rounded,
                        title: 'No Specialists Found',
                        description: 'No medical practitioners match your active filters. Try loosening your search criteria.',
                        actionLabel: 'Clear Filters',
                        onAction: () {
                          setState(() {
                            _searchController.clear();
                            _selectedSpecialty = 'All';
                            _selectedMinRating = null;
                            _selectedMaxFee = null;
                            _sortMode = 'rating';
                          });
                        },
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, index) {
                    final doc = filteredDoctors[index];
                    return Column(
                      children: [
                        _FlatPatientDoctorRow(
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
                        ),
                        Divider(height: 1, indent: 76, endIndent: 20, color: borderColor),
                      ],
                    );
                  },
                  childCount: filteredDoctors.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    children: [
                      Text(
                        'Unable to load specialists: $err',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(color: textSecondary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(verifiedDoctorsStreamProvider),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom padding for the floating navigation bar
          const SliverToBoxAdapter(
            child: SizedBox(height: 118),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterTag(
    String label,
    VoidCallback onRemove,
    Color borderColor,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 13, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionableConsultationRibbon(
    BuildContext context,
    AppointmentModel appointment, {
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isLive = appointment.status == AppointmentStatus.inProgress;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? surfaceColor : const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLive ? AppColors.warning : AppColors.primary.withValues(alpha: 0.35),
          width: isLive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isLive
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isLive ? Icons.sensors_rounded : Icons.event_available_rounded,
                  color: isLive ? AppColors.warning : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isLive
                                ? AppColors.warning.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isLive ? '● LIVE CONSULTATION' : 'UPCOMING CONSULTATION',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isLive ? AppColors.warning : AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Confirmed',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appointment.doctorName,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '${appointment.doctorSpecialty} • ${DateTimeUtils.formatFullWithTimeZone(appointment.scheduledTimeUtc)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, thickness: 1, color: borderColor),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppointmentChatScreen(
                        appointmentId: appointment.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                label: const Text('Chat'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(70, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoConsultationScreen(
                        appointmentId: appointment.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.videocam_rounded, size: 14),
                label: const Text('Join Video Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(120, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardMetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: AppTypography.caption.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(icon, size: 18, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: AppTypography.display.copyWith(
                  fontSize: 22,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlatPatientDoctorRow extends StatelessWidget {
  final DoctorModel doctor;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;
  final VoidCallback onBook;

  const _FlatPatientDoctorRow({
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
                          ? doctor.doctorName.replaceFirst(RegExp(r'^Dr\.\s*'), '').characters.first.toUpperCase()
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
