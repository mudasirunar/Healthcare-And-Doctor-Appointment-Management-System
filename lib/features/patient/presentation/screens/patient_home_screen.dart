import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/smart_search_utils.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/auto_center_filter_bar.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import 'doctor_details_screen.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const PatientHomeScreen({super.key, this.scrollController});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController;

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
            fontSize: 12,
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

    final currentUser = ref.watch(currentUserProvider);
    final unreadNotifs = ref.watch(unreadPatientNotificationsCountProvider);
    final specialtiesAsync = ref.watch(specialtiesProvider);
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final upcomingAppointments = appointmentsAsync.value
            ?.where((a) =>
                a.status == AppointmentStatus.confirmed ||
                a.status == AppointmentStatus.requested ||
                a.status == AppointmentStatus.inProgress)
            .toList() ??
        [];

    final doctorsAsync = ref.watch(verifiedDoctorsStreamProvider);

    final hasActiveFilter =
        _selectedMinRating != null || _selectedMaxFee != null || _sortMode != 'rating';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // 1. Welcome & Greeting Flat Header with Notification & Chat Shortcuts
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: currentUser?.avatarUrl != null
                        ? NetworkImage(currentUser!.avatarUrl!)
                        : null,
                    child: currentUser?.avatarUrl == null
                        ? Text(
                            currentUser != null && currentUser.displayName.isNotEmpty
                                ? currentUser.displayName[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                        Text(
                          currentUser?.displayName ?? 'Patient',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Chats Hub Shortcut
                  IconButton(
                    icon: const Icon(Icons.chat_outlined, size: 22),
                    color: textPrimary,
                    tooltip: 'Consultation Messages',
                    onPressed: () => context.push('/patient/chats'),
                  ),
                  // Notification Bell with Unread Badge
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, size: 24),
                        color: textPrimary,
                        tooltip: 'Notifications',
                        onPressed: () => context.push('/patient/notifications'),
                      ),
                      if (unreadNotifs > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadNotifs > 9 ? '9+' : '$unreadNotifs',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. Upcoming Consultation Banner (Flat minimal container with live Call/Chat CTA)
          if (upcomingAppointments.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                child: _buildUpcomingConsultationBanner(
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

          // 3. Search Bar with Advanced Filter Trigger
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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

          // 4. Active Filters Strip
          if (hasActiveFilter)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedMinRating != null) ...[
                        _buildActiveFilterTag('Rating ≥ $_selectedMinRating', () {
                          setState(() => _selectedMinRating = null);
                        }, borderColor, textSecondary),
                        const SizedBox(width: 6),
                      ],
                      if (_selectedMaxFee != null) ...[
                        _buildActiveFilterTag(
                            'Fee ≤ \$${_selectedMaxFee!.toStringAsFixed(0)}', () {
                          setState(() => _selectedMaxFee = null);
                        }, borderColor, textSecondary),
                        const SizedBox(width: 6),
                      ],
                      if (_sortMode != 'rating') ...[
                        _buildActiveFilterTag(
                            _sortMode == 'fee' ? 'Lowest Fee' : 'Most Experienced', () {
                          setState(() => _sortMode = 'rating');
                        }, borderColor, textSecondary),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Clear', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Auto-Centering Specialty Filter Bar
          specialtiesAsync.when(
            data: (specialties) {
              final allFilters = ['All', ...specialties.map((s) => s.name)];
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: AutoCenterFilterBar(
                    items: allFilters.map((category) {
                      final isSelected =
                          _selectedSpecialty.toLowerCase() == category.toLowerCase();
                      return AutoCenterFilterItem(
                        id: category,
                        label: category,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedSpecialty = category;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: SizedBox(height: 48),
            ),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // 6. Section Header: Medical Departments & Specialists
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Verified Specialists',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  InkWell(
                    onTap: () => context.push('/patient/specialties'),
                    child: const Text(
                      'All Specialties',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 7. Specialist Flat List Rows
          doctorsAsync.when(
            data: (doctors) {
              // 1. Filter by verification & specialty
              final verifiedDoctors = doctors.where((d) => d.isVerified).toList();
              final specialtyFiltered = verifiedDoctors.where((doc) {
                return _selectedSpecialty == 'All' ||
                    doc.specialtyName.toLowerCase() == _selectedSpecialty.toLowerCase();
              }).toList();

              // 2. Filter by rating & fee
              final criteriaFiltered = specialtyFiltered.where((doc) {
                final passesRating =
                    _selectedMinRating == null || doc.rating >= _selectedMinRating!;
                final passesFee =
                    _selectedMaxFee == null || doc.consultationFee <= _selectedMaxFee!;
                return passesRating && passesFee;
              }).toList();

              // 3. Apply search query
              final searched = SmartSearchEngine.filterAndSort<DoctorModel>(
                items: criteriaFiltered,
                query: _searchController.text,
                primaryTextBuilder: (d) => d.doctorName,
                secondaryTextsBuilder: (d) => [
                  d.specialtyName,
                  d.bio,
                  d.licenseNumber,
                ],
              );

              // 4. Apply sorting
              final filtered = List<DoctorModel>.from(searched);
              if (_sortMode == 'fee') {
                filtered.sort((a, b) => a.consultationFee.compareTo(b.consultationFee));
              } else if (_sortMode == 'exp') {
                filtered.sort((a, b) => b.experienceYears.compareTo(a.experienceYears));
              } else {
                filtered.sort((a, b) => b.rating.compareTo(a.rating));
              }

              if (filtered.isEmpty) {
                return SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.person_search_outlined,
                            size: 44, color: textSecondary.withOpacity(0.5)),
                        const SizedBox(height: 10),
                        Text(
                          'No specialists found',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try clearing filter brackets or selecting another specialty.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doctor = filtered[index];
                      return Column(
                        children: [
                          _FlatPatientDoctorRow(
                            doctor: doctor,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DoctorDetailsScreen(doctorId: doctor.id),
                                ),
                              );
                            },
                            onBook: () => context.push('/patient/book/${doctor.id}'),
                          ),
                          if (index < filtered.length - 1)
                            Divider(height: 1, thickness: 1, color: borderColor),
                        ],
                      );
                    },
                    childCount: filtered.length,
                  ),
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
      String label, VoidCallback onRemove, Color borderColor, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
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
            child: const Icon(Icons.close_rounded,
                size: 13, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingConsultationBanner(
    BuildContext context,
    AppointmentModel appointment, {
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? surfaceColor : const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? borderColor : AppColors.primary.withOpacity(0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_available_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'UPCOMING CONSULTATION',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '● Online',
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
                      DateTimeUtils.formatFullWithTimeZone(
                          appointment.scheduledTimeUtc),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
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
                onPressed: () =>
                    context.push('/consultation/chat/${appointment.id}'),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                label: const Text('Chat'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(70, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () =>
                    context.push('/consultation/room/${appointment.id}'),
                icon: const Icon(Icons.videocam_rounded, size: 14),
                label: const Text('Join Video Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(110, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
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
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: doctor.avatarUrl != null
                  ? NetworkImage(doctor.avatarUrl!)
                  : null,
              child: doctor.avatarUrl == null
                  ? Text(
                      doctor.doctorName.isNotEmpty
                          ? doctor.doctorName[0].toUpperCase()
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
                      const Icon(Icons.verified,
                          size: 14, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doctor.specialtyName,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${doctor.experienceYears}y experience',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 15, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '\$${doctor.consultationFee.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Book',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
