import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/smart_search_utils.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../consultation/domain/entities/prescription_model.dart';
import '../../../consultation/presentation/screens/prescription_viewer_screen.dart';

class PatientPrescriptionsScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const PatientPrescriptionsScreen({
    super.key,
    this.scrollController,
  });

  @override
  ConsumerState<PatientPrescriptionsScreen> createState() =>
      _PatientPrescriptionsScreenState();
}

class _PatientPrescriptionsScreenState
    extends ConsumerState<PatientPrescriptionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final aptRepo = ref.watch(appointmentRepositoryProvider);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);

    return Column(
      children: [
        // Search Bar Strip
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AppSearchBar(
            controller: _searchController,
            hintText: 'Search doctor, diagnosis, medication, or Rx #...',
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Divider(height: 1, color: borderColor),

        // Prescriptions List
        Expanded(
          child: FutureBuilder<List<PrescriptionModel>>(
            future: user != null
                ? aptRepo.getPrescriptionsForPatient(user.id)
                : null,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.receipt_long_rounded,
                  title: 'No Digital Prescriptions',
                  description:
                      'Prescriptions issued by your consulting doctor after completed sessions will appear here.',
                );
              }

              final results =
                  SmartSearchEngine.filterAndSort<PrescriptionModel>(
                items: list,
                query: _searchQuery,
                primaryTextBuilder: (rx) => rx.doctorName,
                secondaryTextsBuilder: (rx) => [
                  rx.id,
                  rx.diagnosis,
                  rx.doctorSpecialty,
                  if (rx.notes != null) rx.notes!,
                  ...rx.medications.map((m) => '${m.name} ${m.dosage}'),
                ],
                fallbackComparator: (a, b) =>
                    b.issuedAtUtc.compareTo(a.issuedAtUtc),
              );

              if (results.isEmpty) {
                return Center(
                  child: Text(
                    'No matching prescriptions found.',
                    style:
                        AppTypography.bodyMedium.copyWith(color: textSecondary),
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
                          builder: (_) =>
                              PrescriptionViewerScreen(prescriptionId: rx.id),
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
                              color: AppColors.primary.withValues(alpha: 0.12),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rx.doctorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodyLarge.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
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
                                        color: AppColors.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${rx.medications.length} Meds',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${rx.diagnosis} • ${rx.doctorSpecialty}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  DateTimeUtils.formatFullWithTimeZone(
                                    rx.issuedAtUtc,
                                  ),
                                  style: AppTypography.caption.copyWith(
                                    color: textSecondary.withValues(alpha: 0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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

