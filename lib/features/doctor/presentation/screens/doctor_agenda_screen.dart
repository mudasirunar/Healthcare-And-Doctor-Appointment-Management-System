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
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../admin/presentation/screens/admin_appointment_detail_screen.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../consultation/presentation/screens/prescription_builder_dialog.dart';
import '../../../patient/presentation/screens/unified_patient_detail_screen.dart';

enum AgendaTabSegment { active, completed, all, cancelled }

enum AgendaSortMode {
  timeAscending,
  timeDescending,
  patientAlphabetical,
  longestDuration,
}

/// Comprehensive Consultation Agenda Screen for Doctors.
/// Features segmented tabs, auto-centering filter chips, smart search,
/// and flat on-screen consultation items with complete clinical actions.
class DoctorAgendaScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final bool isStandalone;

  const DoctorAgendaScreen({
    super.key,
    this.scrollController,
    this.isStandalone = false,
  });

  @override
  ConsumerState<DoctorAgendaScreen> createState() => _DoctorAgendaScreenState();
}

class _DoctorAgendaScreenState extends ConsumerState<DoctorAgendaScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _internalScrollController;

  String _searchQuery = '';
  AgendaTabSegment _selectedSegment = AgendaTabSegment.active;
  String? _selectedFilterChip; // e.g. 'today', 'confirmed', 'inProgress', null
  AgendaSortMode _sortMode = AgendaSortMode.timeAscending;

  @override
  void initState() {
    super.initState();
    _internalScrollController = widget.scrollController ?? ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.scrollController == null) {
      _internalScrollController.dispose();
    }
    super.dispose();
  }

  String _sortLabel(AgendaSortMode mode) {
    return switch (mode) {
      AgendaSortMode.timeAscending => 'Scheduled Time (Earliest First)',
      AgendaSortMode.timeDescending => 'Scheduled Time (Latest First)',
      AgendaSortMode.patientAlphabetical => 'Patient Name (A–Z)',
      AgendaSortMode.longestDuration => 'Duration (Longest First)',
    };
  }

  void _showSortBottomSheet(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);
    final isDark = AppColors.isDark(context);
    final activeColor = isDark ? const Color(0xFF38BDF8) : AppColors.primary;

    final options = <(AgendaSortMode, IconData, String, String)>[
      (
        AgendaSortMode.timeAscending,
        Icons.access_time_rounded,
        'Scheduled Time (Earliest)',
        'Soonest upcoming sessions at the top',
      ),
      (
        AgendaSortMode.timeDescending,
        Icons.history_rounded,
        'Scheduled Time (Latest)',
        'Most recent or distant sessions first',
      ),
      (
        AgendaSortMode.patientAlphabetical,
        Icons.sort_by_alpha_rounded,
        'Patient Name (A–Z)',
        'Alphabetical by patient full name',
      ),
      (
        AgendaSortMode.longestDuration,
        Icons.timer_outlined,
        'Duration (Longest)',
        'Sessions with longer consultation slots',
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
                        'Sort Agenda',
                        style: AppTypography.headline.copyWith(
                          color: textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: borderColor),
                ...options.map((opt) {
                  final isSelected = _sortMode == opt.$1;
                  return InkWell(
                    onTap: () {
                      setState(() => _sortMode = opt.$1);
                      Navigator.pop(ctx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? activeColor.withValues(alpha: 0.14)
                                  : AppColors.surfaceVariantOf(context),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              opt.$2,
                              size: 19,
                              color: isSelected ? activeColor : textSecondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opt.$3,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected ? activeColor : textPrimary,
                                  ),
                                ),
                                Text(
                                  opt.$4,
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

  void _startConsultation(AppointmentModel apt) async {
    final user = ref.read(currentUserProvider);
    if (apt.status == AppointmentStatus.confirmed) {
      await ref.read(appointmentRepositoryProvider).updateStatus(
            appointmentId: apt.id,
            targetStatus: AppointmentStatus.inProgress,
            actorUserId: user?.id ?? 'doctor',
            note: 'Doctor initiated consultation room',
          );
      ref.invalidate(userAppointmentsProvider);
    }
    if (mounted) {
      context.push('/consultation/room/${apt.id}');
    }
  }

  void _openPrescriptionBuilder(AppointmentModel apt) {
    showDialog(
      context: context,
      builder: (ctx) => PrescriptionBuilderDialog(
        appointment: apt,
        onPrescriptionCreated: () {
          ref.invalidate(userAppointmentsProvider);
          ref.invalidate(allAppointmentsAdminProvider);
        },
      ),
    );
  }

  int _compareAppointments(AppointmentModel a, AppointmentModel b) {
    switch (_sortMode) {
      case AgendaSortMode.timeAscending:
        return a.scheduledTimeUtc.compareTo(b.scheduledTimeUtc);
      case AgendaSortMode.timeDescending:
        return b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc);
      case AgendaSortMode.patientAlphabetical:
        return a.patientName.toLowerCase().compareTo(b.patientName.toLowerCase());
      case AgendaSortMode.longestDuration:
        return b.durationMinutes.compareTo(a.durationMinutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final unreadChats = ref.watch(unreadConversationsCountProvider);

    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);

    final content = appointmentsAsync.when(
        data: (allAppointments) {
          final now = DateTime.now();

          // Segment partition counts
          final activeList = allAppointments.where((a) =>
              a.status == AppointmentStatus.confirmed ||
              a.status == AppointmentStatus.inProgress).toList();
          final completedList = allAppointments
              .where((a) => a.status == AppointmentStatus.completed)
              .toList();
          final cancelledList = allAppointments.where((a) =>
              a.status == AppointmentStatus.cancelled ||
              a.status == AppointmentStatus.rejected).toList();

          // Filter by active segment tab
          List<AppointmentModel> segmentAppointments = switch (_selectedSegment) {
            AgendaTabSegment.active => activeList,
            AgendaTabSegment.completed => completedList,
            AgendaTabSegment.cancelled => cancelledList,
            AgendaTabSegment.all => allAppointments,
          };

          // Filter by AutoCenterFilterChip if selected
          if (_selectedFilterChip != null) {
            segmentAppointments = segmentAppointments.where((a) {
              if (_selectedFilterChip == 'today') {
                try {
                  final d = DateTime.parse(a.scheduledTimeUtc).toLocal();
                  return d.year == now.year && d.month == now.month && d.day == now.day;
                } catch (_) {
                  return false;
                }
              } else if (_selectedFilterChip == 'confirmed') {
                return a.status == AppointmentStatus.confirmed;
              } else if (_selectedFilterChip == 'inProgress') {
                return a.status == AppointmentStatus.inProgress;
              } else if (_selectedFilterChip == 'completed') {
                return a.status == AppointmentStatus.completed;
              } else if (_selectedFilterChip == 'cancelled') {
                return a.status == AppointmentStatus.cancelled ||
                    a.status == AppointmentStatus.rejected;
              }
              return true;
            }).toList();
          }

          // Smart Search & Sort
          final filtered = SmartSearchEngine.filterAndSort<AppointmentModel>(
            items: segmentAppointments,
            query: _searchQuery,
            primaryTextBuilder: (a) => a.patientName,
            secondaryTextsBuilder: (a) => [
              a.patientEmail,
              a.reasonForVisit,
              a.displayRoomName,
              a.id,
            ],
            fallbackComparator: _compareAppointments,
          );

          return Column(
            children: [
              // 1. Top Segmented Switcher (Active | Completed | All | Cancelled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                            label: 'Active (${activeList.length})',
                            isSelected: _selectedSegment == AgendaTabSegment.active,
                            onTap: () => setState(
                              () => _selectedSegment = AgendaTabSegment.active,
                            ),
                          ),
                          _SegmentButton(
                            label: 'Done (${completedList.length})',
                            isSelected: _selectedSegment == AgendaTabSegment.completed,
                            onTap: () => setState(
                              () => _selectedSegment = AgendaTabSegment.completed,
                            ),
                          ),
                          _SegmentButton(
                            label: 'All (${allAppointments.length})',
                            isSelected: _selectedSegment == AgendaTabSegment.all,
                            onTap: () => setState(
                              () => _selectedSegment = AgendaTabSegment.all,
                            ),
                          ),
                          _SegmentButton(
                            label: 'Past/Other',
                            isSelected: _selectedSegment == AgendaTabSegment.cancelled,
                            onTap: () => setState(
                              () => _selectedSegment = AgendaTabSegment.cancelled,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2. Search Bar + Sort Trigger Button
                    Row(
                      children: [
                        Expanded(
                          child: AppSearchBar(
                            controller: _searchController,
                            hintText: 'Search patient, reason, room, or Rx...',
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                            onClear: () => setState(() => _searchQuery = ''),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Tooltip(
                          message: 'Sort Agenda: ${_sortLabel(_sortMode)}',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _showSortBottomSheet(context),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: _sortMode != AgendaSortMode.timeAscending
                                    ? AppColors.primary.withValues(alpha: 0.14)
                                    : AppColors.surfaceVariantOf(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _sortMode != AgendaSortMode.timeAscending
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
                                    color: _sortMode != AgendaSortMode.timeAscending
                                        ? AppColors.primary
                                        : textPrimary,
                                  ),
                                  if (_sortMode != AgendaSortMode.timeAscending)
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
                    ),
                  ],
                ),
              ),

              // 3. Category Filter Chips (AutoCenterFilterBar)
              AutoCenterFilterBar(
                focusItemId: _selectedFilterChip ?? 'all_chip',
                items: [
                  AutoCenterFilterItem(
                    id: 'all_chip',
                    label: 'All Items',
                    isSelected: _selectedFilterChip == null,
                    onTap: () => setState(() => _selectedFilterChip = null),
                  ),
                  AutoCenterFilterItem(
                    id: 'today',
                    label: 'Today',
                    isSelected: _selectedFilterChip == 'today',
                    onTap: () => setState(() => _selectedFilterChip =
                        _selectedFilterChip == 'today' ? null : 'today'),
                  ),
                  AutoCenterFilterItem(
                    id: 'confirmed',
                    label: 'Confirmed',
                    isSelected: _selectedFilterChip == 'confirmed',
                    onTap: () => setState(() => _selectedFilterChip =
                        _selectedFilterChip == 'confirmed' ? null : 'confirmed'),
                  ),
                  AutoCenterFilterItem(
                    id: 'inProgress',
                    label: 'In Progress',
                    isSelected: _selectedFilterChip == 'inProgress',
                    onTap: () => setState(() => _selectedFilterChip =
                        _selectedFilterChip == 'inProgress' ? null : 'inProgress'),
                  ),
                  AutoCenterFilterItem(
                    id: 'completed',
                    label: 'Completed',
                    isSelected: _selectedFilterChip == 'completed',
                    onTap: () => setState(() => _selectedFilterChip =
                        _selectedFilterChip == 'completed' ? null : 'completed'),
                  ),
                  AutoCenterFilterItem(
                    id: 'cancelled',
                    label: 'Cancelled',
                    isSelected: _selectedFilterChip == 'cancelled',
                    onTap: () => setState(() => _selectedFilterChip =
                        _selectedFilterChip == 'cancelled' ? null : 'cancelled'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Divider(height: 1, color: borderColor),

              // 4. Agenda Consultation Items List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: EmptyStateView(
                            icon: Icons.event_available_rounded,
                            title: _searchQuery.isNotEmpty
                                ? 'No Consultations Found'
                                : 'No Consultations in ${_selectedSegment.name.toUpperCase()}',
                            description: _searchQuery.isNotEmpty
                                ? 'No appointments match "$_searchQuery". Try clearing your search term or adjusting filters.'
                                : 'There are currently no consultation records under this section.',
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _internalScrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final apt = filtered[index];

                          return Container(
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Row: Patient Info & Status Badge (Tappable to patient profile)
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UnifiedPatientDetailScreen(
                                          patientId: apt.patientId,
                                          role: UserRole.doctor,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: AppColors.primary
                                              .withValues(alpha: 0.12),
                                          child: Text(
                                            apt.patientName.isNotEmpty
                                                ? apt.patientName[0].toUpperCase()
                                                : 'P',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      apt.patientName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.chevron_right_rounded,
                                                    size: 17,
                                                    color: textSecondary,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                DateTimeUtils
                                                    .formatFullWithTimeZone(
                                                        apt.scheduledTimeUtc),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        StatusBadge(status: apt.status),
                                      ],
                                    ),
                                  ),
                                ),

                                // Metadata Strip: Room, Duration, Booking ID
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariantOf(context),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color: textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${apt.durationMinutes} mins',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          '•',
                                          style: TextStyle(color: textSecondary),
                                        ),
                                        const SizedBox(width: 10),
                                        Icon(
                                          Icons.meeting_room_outlined,
                                          size: 14,
                                          color: textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            apt.displayRoomName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '#${apt.id.length > 6 ? apt.id.substring(0, 6).toUpperCase() : apt.id.toUpperCase()}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Reason for Visit
                                if (apt.reasonForVisit.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                                    child: Text(
                                      'Reason: "${apt.reasonForVisit}"',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: textPrimary.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 6),
                                Divider(height: 1, color: borderColor),

                                // Action Buttons Row
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // View Full Appointment Details
                                        TextButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    AdminAppointmentDetailScreen(
                                                  appointmentId: apt.id,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.info_outline_rounded,
                                            size: 15,
                                          ),
                                          label: const Text(
                                            'Details',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                        const SizedBox(width: 4),

                                        // Chat
                                        TextButton.icon(
                                          onPressed: () => context.push(
                                            '/consultation/chat/${apt.id}',
                                          ),
                                          icon: const Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 14,
                                          ),
                                          label: const Text(
                                            'Chat',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),

                                        const SizedBox(width: 14),

                                        // Prescribe (Emerald Green)
                                        if (apt.status ==
                                                AppointmentStatus.confirmed ||
                                            apt.status ==
                                                AppointmentStatus.inProgress ||
                                            apt.status ==
                                                AppointmentStatus.completed) ...[
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _openPrescriptionBuilder(apt),
                                            icon: const Icon(
                                              Icons.medication_outlined,
                                              size: 14,
                                            ),
                                            label: const Text(
                                              'Rx',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.secondary,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],

                                        // Video Consultation Trigger (Call / Resume)
                                        if (apt.status ==
                                                AppointmentStatus.confirmed ||
                                            apt.status ==
                                                AppointmentStatus.inProgress) ...[
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _startConsultation(apt),
                                            icon: const Icon(
                                              Icons.videocam_rounded,
                                              size: 15,
                                            ),
                                            label: Text(
                                              apt.status ==
                                                      AppointmentStatus.inProgress
                                                  ? 'Resume'
                                                  : 'Call',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        error: (e, _) => ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.invalidate(userAppointmentsProvider),
        ),
      );

    if (!widget.isStandalone) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Consultation Agenda'),
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
        actions: [
          _DoctorChatIconButton(
            unreadCount: unreadChats,
            onTap: () => context.push('/doctor/chats'),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: content,
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
    final textPrimary = AppColors.textPrimaryOf(context);
    final isDark = AppColors.isDark(context);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? textPrimary : AppColors.textSecondaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoctorChatIconButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _DoctorChatIconButton({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariantOf(context),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              unreadCount > 0
                  ? Icons.chat_bubble_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 19,
              color: unreadCount > 0 ? AppColors.primary : textPrimary,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: AppColors.surfaceOf(context),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
