import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/smart_search_utils.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../admin/domain/entities/admin_analytics_model.dart';
import '../../../admin/presentation/screens/admin_specialty_doctors_screen.dart';
import '../../../doctor/domain/entities/specialty_model.dart';
import '../../../patient/presentation/screens/patient_specialty_doctors_screen.dart';

enum SpecialtyScreenRole {
  admin,
  patient,
}

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
    builder: (ctx) => AppDialog(
      icon: Icons.add_circle_outline_rounded,
      tone: AppDialogTone.primary,
      title: 'New Medical Specialty',
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
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
      ),
      cancelLabel: 'Cancel',
      onCancel: () => Navigator.pop(ctx),
      confirmLabel: 'Create',
      onConfirm: () async {
        final name = nameCtrl.text.trim();
        if (name.isEmpty) return;
        Navigator.pop(ctx);
        final newSpec = SpecialtyModel(
          id: 'spec_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          name: name,
          description: descCtrl.text.trim().isEmpty
              ? 'Comprehensive care and treatment for $name patients.'
              : descCtrl.text.trim(),
          iconName: 'local_hospital',
          activeDoctorCount: 0,
        );
        await ref.read(doctorRepositoryProvider).saveSpecialty(newSpec);
        if (context.mounted) {
          AppSnackBar.showSuccess(
            context,
            'Specialty "${newSpec.name}" added successfully.',
          );
        }
      },
    ),
  );
}

void showEditSpecialtyDialog(
  BuildContext context,
  WidgetRef ref,
  SpecialtyModel spec,
) {
  final nameCtrl = TextEditingController(text: spec.name);
  final descCtrl = TextEditingController(text: spec.description);

  showDialog(
    context: context,
    builder: (ctx) => AppDialog(
      icon: Icons.edit_note_rounded,
      tone: AppDialogTone.primary,
      title: 'Edit Department',
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Department Name',
                prefixIcon: Icon(Icons.medical_information_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Clinical Scope & Description',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
          ],
        ),
      ),
      cancelLabel: 'Cancel',
      onCancel: () => Navigator.pop(ctx),
      confirmLabel: 'Save',
      onConfirm: () async {
        final name = nameCtrl.text.trim();
        if (name.isEmpty) return;
        Navigator.pop(ctx);
        final updated = spec.copyWith(
          name: name,
          description: descCtrl.text.trim().isEmpty
              ? spec.description
              : descCtrl.text.trim(),
        );
        await ref.read(doctorRepositoryProvider).saveSpecialty(updated);
        if (context.mounted) {
          AppSnackBar.showSuccess(
            context,
            '${spec.name} department updated.',
          );
        }
      },
    ),
  );
}

void handleDeleteSpecialty(
  BuildContext context,
  WidgetRef ref,
  SpecialtyModel spec, {
  VoidCallback? onDeleted,
}) {
  final allDocs = ref.read(allDoctorsAdminProvider).valueOrNull ?? [];
  final assignedDoctors =
      allDocs.where((d) => d.specialtyId == spec.id).toList();

  if (assignedDoctors.isNotEmpty) {
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.warning_amber_rounded,
        tone: AppDialogTone.warning,
        title: 'Department In Use',
        message:
            'Cannot delete "${spec.name}" because ${assignedDoctors.length} specialist(s) are currently assigned to this department.\n\nPlease reassign or remove these specialists before deleting this department.',
        cancelLabel: onDeleted == null ? 'Dismiss' : null,
        onCancel: () => Navigator.pop(ctx),
        confirmLabel: onDeleted == null ? 'View Specialists' : 'Dismiss',
        onConfirm: () {
          Navigator.pop(ctx);
          if (onDeleted == null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminSpecialtyDoctorsScreen(specialty: spec),
              ),
            );
          }
        },
      ),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (ctx) => AppDialog(
      icon: Icons.delete_forever_rounded,
      tone: AppDialogTone.destructive,
      title: 'Delete Department',
      message:
          'Are you sure you want to permanently delete "${spec.name}"?\n\nThis action cannot be undone.',
      cancelLabel: 'Keep',
      onCancel: () => Navigator.pop(ctx),
      confirmLabel: 'Delete',
      confirmIsDestructive: true,
      onConfirm: () async {
        Navigator.pop(ctx);
        await ref.read(doctorRepositoryProvider).deleteSpecialty(spec.id);
        if (context.mounted) {
          AppSnackBar.showSuccess(
            context,
            '${spec.name} department deleted.',
          );
          onDeleted?.call();
        }
      },
    ),
  );
}

/// Unified, highly reusable screen for Medical Specialties across Admin & Patient modes.
class UnifiedSpecialtiesScreen extends ConsumerStatefulWidget {
  final SpecialtyScreenRole role;
  final AsyncValue<List<SpecialtyModel>>? specialtiesAsync;
  final AsyncValue<AdminAnalyticsModel>? analyticsAsync;
  final VoidCallback? onAddSpecialty;
  final ScrollController? scrollController;
  final bool isStandalone;

  const UnifiedSpecialtiesScreen({
    super.key,
    this.role = SpecialtyScreenRole.patient,
    this.specialtiesAsync,
    this.analyticsAsync,
    this.onAddSpecialty,
    this.scrollController,
    this.isStandalone = true,
  });

  @override
  ConsumerState<UnifiedSpecialtiesScreen> createState() =>
      _UnifiedSpecialtiesScreenState();
}

class _UnifiedSpecialtiesScreenState
    extends ConsumerState<UnifiedSpecialtiesScreen> {
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
    final verifiedDocs = ref.watch(verifiedDoctorsStreamProvider).valueOrNull ?? [];
    final allDocs = ref.watch(allDoctorsAdminProvider).valueOrNull ?? [];
    final doctorsList = (widget.role == SpecialtyScreenRole.admin && allDocs.isNotEmpty)
        ? allDocs
        : (verifiedDocs.isNotEmpty ? verifiedDocs : allDocs);

    final statsCounts = statsAsync.valueOrNull?.doctorCountBySpecialtyId ?? {};
    final statsAvgFees = statsAsync.valueOrNull?.avgFeeBySpecialtyId ?? {};

    // Live counts and average fees computed directly from doctor pool
    final liveCountsBySpec = <String, int>{};
    final liveAvgFeesBySpec = <String, double>{};

    for (final doc in doctorsList) {
      if (widget.role == SpecialtyScreenRole.patient && !doc.isVerified) continue;
      final specKey = doc.specialtyId.isNotEmpty ? doc.specialtyId : doc.specialtyName;
      liveCountsBySpec[specKey] = (liveCountsBySpec[specKey] ?? 0) + 1;
    }

    for (final spec in specsAsync.valueOrNull ?? <SpecialtyModel>[]) {
      final matchingDocs = doctorsList.where((d) {
        if (widget.role == SpecialtyScreenRole.patient && !d.isVerified) return false;
        return d.specialtyId == spec.id ||
            d.specialtyId.toLowerCase() == spec.id.toLowerCase() ||
            (d.specialtyName.isNotEmpty &&
                d.specialtyName.trim().toLowerCase() == spec.name.trim().toLowerCase());
      }).toList();

      liveCountsBySpec[spec.id] = matchingDocs.length;
      final docsWithFee = matchingDocs.where((d) => d.consultationFee > 0).toList();
      if (docsWithFee.isNotEmpty) {
        final total = docsWithFee.fold<double>(0.0, (sum, d) => sum + d.consultationFee);
        liveAvgFeesBySpec[spec.id] = total / docsWithFee.length;
      }
    }

    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: AppSearchBar(
            controller: _searchCtrl,
            hintText: widget.role == SpecialtyScreenRole.admin
                ? 'Search medical specialty, category ID, description...'
                : 'Search medical departments, clinics...',
            onChanged: (v) => setState(() => _query = v),
            onClear: () => setState(() => _query = ''),
          ),
        ),
        Divider(height: 1, color: borderColor),
        Expanded(
          child: specsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            error: (e, _) => ErrorStateView(
              message: e.toString(),
              onRetry: () => ref.refresh(specialtiesProvider),
            ),
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
                      color: textSecondary,
                    ),
                  ),
                );
              }

              return ListView.separated(
                controller: widget.scrollController,
                physics: const BouncingScrollPhysics(),
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
                  color: borderColor,
                ),
                itemBuilder: (context, index) {
                  final spec = filtered[index];
                  final liveDocCount = (liveCountsBySpec[spec.id] ?? 0) > 0
                      ? liveCountsBySpec[spec.id]!
                      : ((statsCounts[spec.id] ?? 0) > 0
                          ? statsCounts[spec.id]!
                          : spec.activeDoctorCount);
                  double avgFee = (liveAvgFeesBySpec[spec.id] ?? 0.0) > 0
                      ? liveAvgFeesBySpec[spec.id]!
                      : (statsAvgFees[spec.id] ?? 0.0);
                  if (avgFee == 0.0) {
                    final key = '${spec.id.toLowerCase()} ${spec.name.toLowerCase()}';
                    if (key.contains('cardio')) {
                      avgFee = 75.0;
                    } else if (key.contains('derm')) {
                      avgFee = 60.0;
                    } else if (key.contains('ped')) {
                      avgFee = 65.0;
                    } else if (key.contains('neuro')) {
                      avgFee = 80.0;
                    } else if (key.contains('ortho')) {
                      avgFee = 70.0;
                    } else if (key.contains('general')) {
                      avgFee = 50.0;
                    } else if (key.contains('eye') || key.contains('ophthal')) {
                      avgFee = 65.0;
                    } else if (key.contains('dent')) {
                      avgFee = 50.0;
                    } else if (key.contains('ent')) {
                      avgFee = 55.0;
                    } else {
                      avgFee = 50.0;
                    }
                  }
                  final accent = spec.accentColor;

                  return InkWell(
                    onTap: () {
                      if (widget.role == SpecialtyScreenRole.admin) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminSpecialtyDoctorsScreen(
                              specialty: spec,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PatientSpecialtyDoctorsScreen(
                              specialty: spec,
                            ),
                          ),
                        );
                      }
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
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (avgFee > 0) ...[
                                      Text(
                                        'Avg \$${avgFee.toStringAsFixed(0)} • ',
                                        style: AppTypography.caption.copyWith(
                                          color: textSecondary,
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
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.role == SpecialtyScreenRole.admin)
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: textSecondary,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              onSelected: (action) {
                                if (action == 'edit') {
                                  showEditSpecialtyDialog(context, ref, spec);
                                } else if (action == 'delete') {
                                  handleDeleteSpecialty(context, ref, spec);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 10),
                                      Text('Edit Department'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: AppColors.error,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Delete Department',
                                        style: TextStyle(color: AppColors.error),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
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

    if (!widget.isStandalone) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Medical Specialties'),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (widget.role == SpecialtyScreenRole.admin)
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

