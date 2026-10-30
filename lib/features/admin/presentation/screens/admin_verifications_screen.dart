import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import '../../domain/entities/admin_analytics_model.dart';

class AdminVerificationsScreen extends StatelessWidget {
  final AsyncValue<List<DoctorModel>> pendingAsync;
  final AsyncValue<AdminAnalyticsModel> analyticsAsync;
  final ValueChanged<DoctorModel> onApprove;
  final ValueChanged<DoctorModel> onReject;
  final ScrollController? scrollController;

  const AdminVerificationsScreen({
    super.key,
    required this.pendingAsync,
    required this.analyticsAsync,
    required this.onApprove,
    required this.onReject,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final approvedCount = analyticsAsync.valueOrNull?.verifiedDoctors ?? 18;

    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorStateView(message: e.toString()),
      data: (pending) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 118),
          children: [
              // Summary Banner Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderOf(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLightOf(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$approvedCount Verified Specialists Active',
                            style: AppTypography.headline.copyWith(
                              fontSize: 15,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            pending.isEmpty
                                ? 'All submitted medical licenses have been reviewed.'
                                : '${pending.length} new practitioner application(s) awaiting review.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (pending.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.successLightOf(context),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.task_alt_rounded,
                          size: 32,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Verification Queue Cleared',
                        style: AppTypography.headline.copyWith(
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'When a new doctor registers on the platform, their medical board license and credentials will appear here for approval.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...pending.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PendingDoctorCard(
                      doctor: doc,
                      onApprove: () => onApprove(doc),
                      onReject: () => onReject(doc),
                    ),
                  ),
                ),
            ],
          );
      },
    );
  }
}

class _PendingDoctorCard extends StatelessWidget {
  final DoctorModel doctor;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingDoctorCard({
    required this.doctor,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLightOf(context),
                child: Text(
                  doctor.doctorName.replaceAll('Dr. ', '').substring(0, 1).toUpperCase(),
                  style: AppTypography.headline.copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.doctorName,
                      style: AppTypography.headline.copyWith(
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${doctor.specialtyName} • ${doctor.experienceYears} yrs experience',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warningLightOf(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Pending',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.badge_outlined,
                label: 'License: ${doctor.licenseNumber}',
              ),
              _InfoChip(
                icon: Icons.payments_outlined,
                label: 'Fee: \$${doctor.consultationFee.toStringAsFixed(0)}',
              ),
            ],
          ),
          if (doctor.bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              doctor.bio,
              style: AppTypography.bodyMedium.copyWith(color: textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.borderOf(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(0, 42),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size(0, 42),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantOf(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondaryOf(context)),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

