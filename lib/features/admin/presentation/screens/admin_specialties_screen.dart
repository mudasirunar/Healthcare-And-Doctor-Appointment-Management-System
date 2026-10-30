import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../doctor/domain/entities/specialty_model.dart';
import '../../domain/entities/admin_analytics_model.dart';

class AdminSpecialtiesScreen extends StatelessWidget {
  final AsyncValue<List<SpecialtyModel>> specialtiesAsync;
  final AsyncValue<AdminAnalyticsModel> analyticsAsync;
  final VoidCallback onAddSpecialty;
  final ScrollController? scrollController;

  const AdminSpecialtiesScreen({
    super.key,
    required this.specialtiesAsync,
    required this.analyticsAsync,
    required this.onAddSpecialty,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final countsBySpec = analyticsAsync.valueOrNull?.doctorCountBySpecialtyId ?? {};

    return specialtiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorStateView(message: e.toString()),
      data: (specialties) {
        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.only(top: 6, bottom: 118),
          itemCount: specialties.length,
          separatorBuilder: (context, _) => Divider(
            height: 1,
            thickness: 1,
            indent: 82,
            endIndent: 20,
            color: AppColors.borderOf(context),
          ),
          itemBuilder: (context, index) {
            final spec = specialties[index];
            final liveDocCount = countsBySpec[spec.id] ?? spec.activeDoctorCount;
            final accent = spec.accentColor;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      spec.iconData,
                      color: accent,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                spec.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headline.copyWith(
                                  fontSize: 16,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$liveDocCount ${liveDocCount == 1 ? 'Doc' : 'Docs'}',
                                style: AppTypography.caption.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          spec.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
