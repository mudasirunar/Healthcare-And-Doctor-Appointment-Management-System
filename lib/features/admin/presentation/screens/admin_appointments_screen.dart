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
                      padding: const EdgeInsets.only(top: 4, bottom: 118),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 80,
                        endIndent: 20,
                        color: borderColor,
                      ),
                      itemBuilder: (context, index) {
                        final rx = results[index];
                        return InkWell(
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.description_outlined,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              rx.patientName,
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
                                          Text(
                                            '${rx.medications.length} Meds',
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
                                        '${rx.diagnosis} • Issued by ${rx.doctorName}',
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
                      padding: const EdgeInsets.only(top: 4, bottom: 118),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 80,
                        endIndent: 20,
                        color: borderColor,
                      ),
                      itemBuilder: (context, index) {
                        final apt = results[index];
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminAppointmentDetailScreen(
                                  appointmentId: apt.id,
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
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today_rounded,
                                    color: AppColors.primary,
                                    size: 20,
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
                                              '${apt.patientName} → ${apt.doctorName}',
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
                                          StatusBadge(
                                            status: apt.status,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${DateTimeUtils.formatLocalDate(apt.scheduledTimeUtc)} • ${DateTimeUtils.formatLocalTime(apt.scheduledTimeUtc)} • ${apt.doctorSpecialty} • ${apt.reasonForVisit}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.caption.copyWith(
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
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
        ),
      ],
    );
  }
}
