import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/smart_search_utils.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../doctor/domain/entities/specialty_model.dart';
import '../../domain/entities/admin_analytics_model.dart';
import 'admin_specialty_doctors_screen.dart';

/// Green-tinted "+ Add" button for Medical Specialties.
class GreenAddSpecialtyButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const GreenAddSpecialtyButton({
    super.key,
    required this.onTap,
    this.label = 'Add',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: isDark ? 0.20 : 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_rounded,
              size: 17,
              color: AppColors.secondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showAddSpecialtyDialog(BuildContext context, WidgetRef ref) {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        'New Medical Specialty',
        style: AppTypography.headline.copyWith(
          color: AppColors.textPrimaryOf(ctx),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Department Name',
              hintText: 'e.g. Ophthalmology',
              prefixIcon: Icon(Icons.medical_information_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Clinical Scope & Description',
              hintText: 'Describe conditions treated...',
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            final newSpec = SpecialtyModel(
              id: 'spec_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
              name: name,
              description: descCtrl.text.trim().isEmpty
                  ? 'Specialized clinical care and consultations'
                  : descCtrl.text.trim(),
              iconName: name.toLowerCase(),
              activeDoctorCount: 0,
            );
            await ref.read(doctorRepositoryProvider).saveSpecialty(newSpec);
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size(110, 42)),
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

class AdminSpecialtiesScreen extends ConsumerStatefulWidget {
  final AsyncValue<List<SpecialtyModel>>? specialtiesAsync;
  final AsyncValue<AdminAnalyticsModel>? analyticsAsync;
  final VoidCallback? onAddSpecialty;
  final ScrollController? scrollController;
  final bool isStandalone;

  const AdminSpecialtiesScreen({
    super.key,
    this.specialtiesAsync,
    this.analyticsAsync,
    this.onAddSpecialty,
    this.scrollController,
    this.isStandalone = true,
  });

  @override
  ConsumerState<AdminSpecialtiesScreen> createState() =>
      _AdminSpecialtiesScreenState();
}

class _AdminSpecialtiesScreenState
    extends ConsumerState<AdminSpecialtiesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<SpecialtyModel>> specsAsync =
        widget.specialtiesAsync ?? ref.watch(specialtiesProvider);
    final AsyncValue<AdminAnalyticsModel> statsAsync =
        widget.analyticsAsync ?? ref.watch(adminAnalyticsProvider);
    final countsBySpec =
        statsAsync.valueOrNull?.doctorCountBySpecialtyId ?? {};
    final avgFeesBySpec = statsAsync.valueOrNull?.avgFeeBySpecialtyId ?? {};

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: AppSearchBar(
            controller: _searchCtrl,
            hintText: 'Search medical specialty, category ID, description...',
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Divider(height: 1, color: AppColors.borderOf(context)),
        Expanded(
          child: specsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorStateView(message: e.toString()),
            data: (specialties) {
              final filtered = SmartSearchEngine.filterAndSort<SpecialtyModel>(
                items: specialties,
                query: _query,
                primaryTextBuilder: (s) => s.name,
                secondaryTextsBuilder: (s) => [s.id, s.description, s.iconName],
              );

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'No matching medical specialties found.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                );
              }

              return ListView.separated(
                controller: widget.scrollController,
                padding: EdgeInsets.only(
                  top: 6,
                  bottom: widget.isStandalone ? 40 : 118,
                ),
                itemCount: filtered.length,
                separatorBuilder: (context, _) => Divider(
                  height: 1,
                  thickness: 1,
                  indent: 82,
                  endIndent: 20,
                  color: AppColors.borderOf(context),
                ),
                itemBuilder: (context, index) {
                  final spec = filtered[index];
                  final liveDocCount =
                      countsBySpec[spec.id] ?? spec.activeDoctorCount;
                  final avgFee = avgFeesBySpec[spec.id] ?? 0.0;
                  final accent = spec.accentColor;

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminSpecialtyDoctorsScreen(
                            specialty: spec,
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        spec.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.headline.copyWith(
                                          fontSize: 16,
                                          color:
                                              AppColors.textPrimaryOf(context),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (avgFee > 0) ...[
                                      Text(
                                        'Avg \$${avgFee.toStringAsFixed(0)} • ',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textSecondaryOf(
                                            context,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
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
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondaryOf(context),
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

    if (!widget.isStandalone) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Medical Specialties'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GreenAddSpecialtyButton(
                onTap: widget.onAddSpecialty ??
                    () => showAddSpecialtyDialog(context, ref),
              ),
            ),
          ),
        ],
      ),
      body: content,
    );
  }
}
