import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/user_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/smart_search_utils.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../appointment/domain/entities/appointment_model.dart';

class DoctorRequestsScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const DoctorRequestsScreen({super.key, this.scrollController});

  @override
  ConsumerState<DoctorRequestsScreen> createState() =>
      _DoctorRequestsScreenState();
}

class _DoctorRequestsScreenState extends ConsumerState<DoctorRequestsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleApprove(AppointmentModel apt) async {
    final user = ref.read(currentUserProvider);
    try {
      await ref.read(appointmentRepositoryProvider).updateStatus(
            appointmentId: apt.id,
            targetStatus: AppointmentStatus.confirmed,
            actorUserId: user?.id ?? 'doctor',
            note: 'Doctor accepted consultation request',
          );

      UserNotificationService.instance.sendPatientNotification(
        patientUserId: apt.patientId,
        title: 'Consultation Confirmed',
        body: 'Dr. ${apt.doctorName} confirmed your consultation request.',
        type: 'appointment_confirmed',
        targetId: apt.id,
      );

      ref.invalidate(userAppointmentsProvider);
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Consultation request confirmed!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Confirmation failed: $e');
      }
    }
  }

  void _handleDecline(AppointmentModel apt) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.cancel_outlined,
        tone: AppDialogTone.destructive,
        title: 'Decline Booking Request',
        message: 'Are you sure you want to decline ${apt.patientName}\'s booking request?',
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: reasonController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reason for declining',
              hintText: 'e.g. Schedule emergency, conflicting clinic shift...',
            ),
          ),
        ),
        cancelLabel: 'Cancel',
        onCancel: () => Navigator.pop(ctx),
        confirmLabel: 'Decline Request',
        confirmIsDestructive: true,
        onConfirm: () async {
          Navigator.pop(ctx);
          final user = ref.read(currentUserProvider);
          try {
            final reason = reasonController.text.trim().isNotEmpty
                ? reasonController.text.trim()
                : 'Doctor unavailable at requested time';

            await ref.read(appointmentRepositoryProvider).updateStatus(
                  appointmentId: apt.id,
                  targetStatus: AppointmentStatus.rejected,
                  actorUserId: user?.id ?? 'doctor',
                  cancellationReason: reason,
                  note: reason,
                );

            UserNotificationService.instance.sendPatientNotification(
              patientUserId: apt.patientId,
              title: 'Consultation Request Declined',
              body: 'Dr. ${apt.doctorName} could not accept your booking request: $reason',
              type: 'appointment_declined',
              targetId: apt.id,
            );

            ref.invalidate(userAppointmentsProvider);
            if (mounted) {
              AppSnackBar.showInfo(context, 'Booking request declined.');
            }
          } catch (e) {
            if (mounted) {
              AppSnackBar.showError(context, e.toString());
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return appointmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      error: (e, _) => ErrorStateView(
        message: 'Failed to load booking requests: $e',
        onRetry: () => ref.refresh(userAppointmentsProvider),
      ),
      data: (appointments) {
        final pendingRequests = appointments
            .where((a) => a.status == AppointmentStatus.requested)
            .toList();

        final filtered = SmartSearchEngine.filterAndSort<AppointmentModel>(
          items: pendingRequests,
          query: _query,
          primaryTextBuilder: (a) => a.patientName,
          secondaryTextsBuilder: (a) => [a.patientEmail, a.reasonForVisit],
          fallbackComparator: (a, b) =>
              a.scheduledTimeUtc.compareTo(b.scheduledTimeUtc),
        );

        return Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AppSearchBar(
                controller: _searchCtrl,
                hintText: 'Search requests by patient or reason...',
                onChanged: (val) => setState(() => _query = val),
                onClear: () => setState(() => _query = ''),
              ),
            ),

            // Requests List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: EmptyStateView(
                          icon: Icons.mark_email_read_outlined,
                          title: _query.isNotEmpty
                              ? 'No Matching Requests'
                              : 'No Pending Requests',
                          description: _query.isNotEmpty
                              ? 'No booking requests match "$_query".'
                              : 'You have zero pending patient consultation requests. New booking submissions will appear here.',
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final apt = filtered[index];

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.12),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          apt.patientName,
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                            color: textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          apt.patientEmail,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Requested',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Time Pill
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded,
                                        size: 15, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        DateTimeUtils.formatFullWithTimeZone(
                                            apt.scheduledTimeUtc),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (apt.reasonForVisit.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Reason for visit:',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  apt.reasonForVisit,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textPrimary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Divider(height: 1, color: borderColor),
                              const SizedBox(height: 12),

                              // Actions Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _handleDecline(apt),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: Size.zero,
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(color: AppColors.error),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 9),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text('Decline',
                                        style: TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: () => _handleApprove(apt),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: Size.zero,
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 9),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text('Accept',
                                        style: TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ],
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
    );
  }
}
