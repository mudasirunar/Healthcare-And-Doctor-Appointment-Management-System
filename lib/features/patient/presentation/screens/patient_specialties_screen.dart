import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/smart_search_utils.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../doctor/domain/entities/specialty_model.dart';
import 'patient_specialty_doctors_screen.dart';

class PatientSpecialtiesScreen extends ConsumerStatefulWidget {
  const PatientSpecialtiesScreen({super.key});

  @override
  ConsumerState<PatientSpecialtiesScreen> createState() =>
      _PatientSpecialtiesScreenState();
}

class _PatientSpecialtiesScreenState
    extends ConsumerState<PatientSpecialtiesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final specialtiesAsync = ref.watch(specialtiesProvider);
    final analyticsAsync = ref.watch(adminAnalyticsProvider);
    final docCounts = analyticsAsync.valueOrNull?.doctorCountBySpecialtyId ?? {};
    final avgFees = analyticsAsync.valueOrNull?.avgFeeBySpecialtyId ?? {};

    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  'Medical Specialties',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar (Flat)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: AppSearchBar(
              controller: _searchController,
              hintText: 'Search medical departments, clinics...',
              onChanged: (_) => setState(() {}),
              onClear: () => setState(() {}),
            ),
          ),

          // Specialties List
          Expanded(
            child: specialtiesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              error: (err, _) => ErrorStateView(
                message: err.toString(),
                onRetry: () => ref.refresh(specialtiesProvider),
              ),
              data: (specialties) {
                final filtered = SmartSearchEngine.filterAndSort<SpecialtyModel>(
                  items: specialties,
                  query: _searchController.text,
                  primaryTextBuilder: (s) => s.name,
                  secondaryTextsBuilder: (s) => [s.description, s.iconName],
                );

                if (filtered.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.local_hospital_outlined,
                    title: 'No Specialties Found',
                    description: 'No medical departments match your query.',
                  );
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, thickness: 1, color: borderColor),
                  itemBuilder: (context, index) {
                    final spec = filtered[index];
                    final count = docCounts[spec.id] ?? spec.activeDoctorCount;
                    final fee = avgFees[spec.id] ?? 0.0;

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PatientSpecialtyDoctorsScreen(
                              specialty: spec,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                spec.iconData,
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
                                    spec.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    spec.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        '$count Available Specialists',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      if (fee > 0) ...[
                                        Text(
                                          ' • Avg \$${fee.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right_rounded,
                                color: textSecondary, size: 20),
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
      ),
    );
  }
}
