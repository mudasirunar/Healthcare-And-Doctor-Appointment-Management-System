import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import '../../domain/entities/admin_analytics_model.dart';
import 'admin_doctor_detail_screen.dart';

class AdminVerificationsScreen extends ConsumerWidget {
  final AsyncValue<List<DoctorModel>>? pendingAsync;
  final AsyncValue<AdminAnalyticsModel>? analyticsAsync;
  final ValueChanged<DoctorModel>? onApprove;
  final ValueChanged<DoctorModel>? onReject;
  final ScrollController? scrollController;
  final bool isStandalone;

  const AdminVerificationsScreen({
    super.key,
    this.pendingAsync,
    this.analyticsAsync,
    this.onApprove,
    this.onReject,
    this.scrollController,
    this.isStandalone = false,
  });

  Future<void> _defaultApprove(
    BuildContext context,
    WidgetRef ref,
    DoctorModel doc,
  ) async {
    await ref
        .read(doctorRepositoryProvider)
        .updateVerificationStatus(doc.id, VerificationStatus.approved);
    ref.invalidate(filteredDoctorsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${doc.doctorName} approved and published.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _defaultReject(BuildContext context, WidgetRef ref, DoctorModel doc) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Decline Credentials',
          style: AppTypography.headline.copyWith(
            color: AppColors.textPrimaryOf(ctx),
          ),
        ),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Enter verification notes...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              await ref.read(doctorRepositoryProvider).updateVerificationStatus(
                    doc.id,
                    VerificationStatus.rejected,
                    reason,
                  );
              ref.invalidate(filteredDoctorsProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DoctorModel>> pendingVal =
        pendingAsync ?? ref.watch(pendingDoctorsProvider);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    final body = pendingVal.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorStateView(message: e.toString()),
      data: (pending) {
        if (pending.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 64,
                horizontal: 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.successLightOf(context),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      size: 30,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Verification Queue Cleared',
                    style: AppTypography.headline.copyWith(
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When a new specialist registers, their medical board license and credentials will appear here for approval.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          controller: scrollController,
          padding: EdgeInsets.only(
            top: 8,
            bottom: isStandalone ? 40 : 118,
          ),
          children: [
            ...pending.map((doc) {
                return Column(
                  children: [
                    InkWell(
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
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                    Icons.medical_services_rounded,
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
                                      Text(
                                        doc.doctorName,
                                        style: AppTypography.headline.copyWith(
                                          fontSize: 16,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${doc.specialtyName} • License ${doc.licenseNumber} • ${doc.experienceYears} yrs exp',
                                        style: AppTypography.caption.copyWith(
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (doc.bio.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                doc.bio,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => onReject != null
                                        ? onReject!(doc)
                                        : _defaultReject(context, ref, doc),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 17,
                                    ),
                                    label: const Text('Decline'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => onApprove != null
                                        ? onApprove!(doc)
                                        : _defaultApprove(context, ref, doc),
                                    icon: const Icon(
                                      Icons.check_rounded,
                                      size: 17,
                                    ),
                                    label: const Text('Approve'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: borderColor),
                  ],
                );
              }),
          ],
        );
      },
    );

    if (!isStandalone) return body;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Doctor Verifications'),
      ),
      body: body,
    );
  }
}
