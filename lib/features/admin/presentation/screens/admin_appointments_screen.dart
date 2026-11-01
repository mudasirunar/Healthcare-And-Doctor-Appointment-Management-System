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
import '../../../../core/widgets/status_badge.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../consultation/domain/entities/prescription_model.dart';
import '../../../consultation/presentation/screens/prescription_viewer_screen.dart';
import 'admin_appointment_detail_screen.dart';

enum AdminAppointmentFilter {
  all,
  ongoing,
  completed,
  cancelled,
  prescriptions,
}

final adminAppointmentFilterProvider = StateProvider<AdminAppointmentFilter>(
  (ref) => AdminAppointmentFilter.all,
);

/// Incremented whenever an external screen (e.g. Overview) explicitly triggers an appointment filter tab.
final adminAppointmentFilterTriggerProvider = StateProvider<int>((ref) => 0);

class AdminAppointmentsScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const AdminAppointmentsScreen({
    super.key,
    this.scrollController,
  });

  @override
  ConsumerState<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState
    extends ConsumerState<AdminAppointmentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminAppointmentFilterProvider);
    final filterTrigger = ref.watch(adminAppointmentFilterTriggerProvider);
    final appointmentsAsync = ref.watch(allAppointmentsAdminProvider);
    final prescriptionsAsync = ref.watch(allPrescriptionsAdminProvider);
    final analytics = ref.watch(adminAnalyticsProvider).valueOrNull;

    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final isDark = AppColors.isDark(context);

    return Column(
      children: [
        // 1. Search Bar + Contextual Booking Stats Strip
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AppSearchBar(
            controller: _searchController,
            hintText: filter == AdminAppointmentFilter.prescriptions
                ? 'Search patient, specialist, diagnosis, medication...'
                : 'Search patient, specialist, department, visit reason...',
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        if (analytics != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${analytics.upcomingAppointments} Ongoing • ${analytics.completedAppointments} Completed • ${analytics.cancelledAppointments} Cancelled • ${analytics.totalPrescriptions} Prescriptions',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 2. Filter Chips (Auto-centers selected chip on tap or external trigger)
        AutoCenterFilterBar(
          focusItemId: filter.name,
          scrollTrigger: filterTrigger,
          items: [
            AutoCenterFilterItem(
              id: AdminAppointmentFilter.all.name,
              label: 'All Bookings',
              isSelected: filter == AdminAppointmentFilter.all,
              onTap: () => ref
                  .read(adminAppointmentFilterProvider.notifier)
                  .state = AdminAppointmentFilter.all,
            ),
            AutoCenterFilterItem(
              id: AdminAppointmentFilter.ongoing.name,
              label: 'Ongoing & Upcoming',
              isSelected: filter == AdminAppointmentFilter.ongoing,
              onTap: () => ref
                  .read(adminAppointmentFilterProvider.notifier)
                  .state = AdminAppointmentFilter.ongoing,
            ),
            AutoCenterFilterItem(
              id: AdminAppointmentFilter.completed.name,
              label: 'Completed',
              isSelected: filter == AdminAppointmentFilter.completed,
              onTap: () => ref
                  .read(adminAppointmentFilterProvider.notifier)
                  .state = AdminAppointmentFilter.completed,
            ),
            AutoCenterFilterItem(
              id: AdminAppointmentFilter.cancelled.name,
              label: 'Cancelled',
              isSelected: filter == AdminAppointmentFilter.cancelled,
              onTap: () => ref
                  .read(adminAppointmentFilterProvider.notifier)
                  .state = AdminAppointmentFilter.cancelled,
            ),
            AutoCenterFilterItem(
              id: AdminAppointmentFilter.prescriptions.name,
              label: 'Prescriptions',
              isSelected: filter == AdminAppointmentFilter.prescriptions,
              onTap: () => ref
                  .read(adminAppointmentFilterProvider.notifier)
                  .state = AdminAppointmentFilter.prescriptions,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: borderColor),

        // 3. Flat List (Appointments or Prescriptions)
        Expanded(
          child: filter == AdminAppointmentFilter.prescriptions
              ? prescriptionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorStateView(message: e.toString()),
                  data: (prescriptions) {
                    final results =
                        SmartSearchEngine.filterAndSort<PrescriptionModel>(
                      items: prescriptions,
                      query: _searchQuery,
                      primaryTextBuilder: (rx) => rx.patientName,
                      secondaryTextsBuilder: (rx) => [
                        rx.doctorName,
                        rx.doctorSpecialty,
                        rx.diagnosis,
                        rx.notes,
                        rx.id,
                        ...rx.medications.map((m) => m.name),
                      ],
                      fallbackComparator: (a, b) =>
                          b.issuedAtUtc.compareTo(a.issuedAtUtc),
                    );

                    if (results.isEmpty) {
                      return Center(
                        child: Text(
                          'No prescriptions found.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 118),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final rx = results[index];
                        return _AdminPrescriptionCard(
                          rx: rx,
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        );
                      },
                    );
                  },
                )
              : appointmentsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorStateView(message: e.toString()),
                  data: (appointments) {
                    var filtered = appointments;
                    switch (filter) {
                      case AdminAppointmentFilter.ongoing:
                        filtered = filtered
                            .where(
                              (a) =>
                                  a.status == AppointmentStatus.requested ||
                                  a.status == AppointmentStatus.confirmed ||
                                  a.status == AppointmentStatus.inProgress,
                            )
                            .toList();
                      case AdminAppointmentFilter.completed:
                        filtered = filtered
                            .where(
                              (a) => a.status == AppointmentStatus.completed,
                            )
                            .toList();
                      case AdminAppointmentFilter.cancelled:
                        filtered = filtered
                            .where(
                              (a) =>
                                  a.status == AppointmentStatus.cancelled ||
                                  a.status == AppointmentStatus.rejected,
                            )
                            .toList();
                      case AdminAppointmentFilter.all:
                      case AdminAppointmentFilter.prescriptions:
                        break;
                    }

                    final results =
                        SmartSearchEngine.filterAndSort<AppointmentModel>(
                      items: filtered,
                      query: _searchQuery,
                      primaryTextBuilder: (a) => a.patientName,
                      secondaryTextsBuilder: (a) => [
                        a.doctorName,
                        a.doctorSpecialty,
                        a.reasonForVisit,
                        a.status.displayName,
                        a.consultationNotes,
                        a.patientEmail,
                        a.id,
                      ],
                      fallbackComparator: (a, b) =>
                          b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc),
                    );

                    if (results.isEmpty) {
                      return Center(
                        child: Text(
                          'No matching appointments found.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 118),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final apt = results[index];
                        return _AdminAppointmentCard(
                          appointment: apt,
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
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

class _AdminAppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final bool isDark;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _AdminAppointmentCard({
    required this.appointment,
    required this.isDark,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final bookingCode = appointment.id.length > 8
        ? appointment.id.substring(0, 8).toUpperCase()
        : appointment.id.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminAppointmentDetailScreen(
                  appointmentId: appointment.id,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Badges Row: Booking code + Room + Status + Chevron
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '#$bookingCode',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.meeting_room_outlined,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Room ${appointment.displayRoomName}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    StatusBadge(status: appointment.status),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: textSecondary.withValues(alpha: 0.4),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(height: 1, color: borderColor),
                const SizedBox(height: 12),

                // 2. Clear visual participants layout: Patient & Doctor
                // Patient row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isDark
                          ? const Color(0xFF0369A1).withValues(alpha: 0.25)
                          : const Color(0xFFE0F2FE),
                      child: Text(
                        appointment.patientName.isNotEmpty
                            ? appointment.patientName[0].toUpperCase()
                            : 'P',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PATIENT',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            appointment.patientName,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (appointment.patientEmail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              appointment.patientEmail,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Doctor row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        appointment.doctorName.isNotEmpty
                            ? (appointment.doctorName.startsWith('Dr.') &&
                                    appointment.doctorName.length > 4
                                ? appointment.doctorName
                                    .substring(4, 5)
                                    .toUpperCase()
                                : appointment.doctorName[0].toUpperCase())
                            : 'D',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SPECIALIST',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            appointment.doctorName,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (appointment.doctorSpecialty.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor, width: 0.8),
                        ),
                        child: Text(
                          appointment.doctorSpecialty,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF93C5FD)
                                : AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // 3. Schedule & Details Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${DateTimeUtils.formatLocalDate(appointment.scheduledTimeUtc)} • ${DateTimeUtils.formatLocalTime(appointment.scheduledTimeUtc)} (${appointment.durationMinutes} mins)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (appointment.reasonForVisit.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.notes_rounded,
                              size: 13,
                              color: textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Reason: ${appointment.reasonForVisit}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (appointment.cancellationReason != null &&
                          appointment.cancellationReason!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.cancel_outlined,
                              size: 13,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cancelled: ${appointment.cancellationReason}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminPrescriptionCard extends StatelessWidget {
  final PrescriptionModel rx;
  final bool isDark;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _AdminPrescriptionCard({
    required this.rx,
    required this.isDark,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final rxCode = rx.id.length > 8
        ? rx.id.substring(0, 8).toUpperCase()
        : rx.id.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrescriptionViewerScreen(
                  prescriptionId: rx.id,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '#$rxCode',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${rx.medications.length} Medications',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: textSecondary.withValues(alpha: 0.4),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: borderColor),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isDark
                          ? const Color(0xFF0369A1).withValues(alpha: 0.25)
                          : const Color(0xFFE0F2FE),
                      child: Text(
                        rx.patientName.isNotEmpty
                            ? rx.patientName[0].toUpperCase()
                            : 'P',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PATIENT',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            rx.patientName,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
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
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.medication_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRESCRIBING SPECIALIST',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            rx.doctorName,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (rx.doctorSpecialty.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor, width: 0.8),
                        ),
                        child: Text(
                          rx.doctorSpecialty,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF93C5FD)
                                : AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Diagnosis: ${rx.diagnosis}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 13,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Issued: ${DateTimeUtils.formatLocalDate(rx.issuedAtUtc)} • ${DateTimeUtils.formatLocalTime(rx.issuedAtUtc)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
