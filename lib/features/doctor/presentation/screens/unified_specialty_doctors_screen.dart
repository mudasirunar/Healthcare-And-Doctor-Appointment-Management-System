import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/smart_search_utils.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../admin/presentation/screens/admin_doctor_detail_screen.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import '../../../doctor/domain/entities/specialty_model.dart';
import '../../../patient/presentation/screens/doctor_details_screen.dart';
import 'unified_specialties_screen.dart';

class UnifiedSpecialtyDoctorsScreen extends ConsumerStatefulWidget {
  final SpecialtyModel specialty;
  final SpecialtyScreenRole role;

  const UnifiedSpecialtyDoctorsScreen({
    super.key,
    required this.specialty,
    this.role = SpecialtyScreenRole.patient,
  });

  @override
  ConsumerState<UnifiedSpecialtyDoctorsScreen> createState() =>
      _UnifiedSpecialtyDoctorsScreenState();
}

class _UnifiedSpecialtyDoctorsScreenState
    extends ConsumerState<UnifiedSpecialtyDoctorsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = widget.role == SpecialtyScreenRole.admin
        ? ref.watch(allDoctorsAdminProvider)
        : ref.watch(verifiedDoctorsStreamProvider);

    final allSpecialties = ref.watch(specialtiesProvider).valueOrNull ?? [];
    final spec = allSpecialties
            .where((s) => s.id == widget.specialty.id)
            .firstOrNull ??
        widget.specialty;
    final accent = spec.accentColor;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(spec.name),
        actions: [
          if (widget.role == SpecialtyScreenRole.admin) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Department',
              onPressed: () => showEditSpecialtyDialog(context, ref, spec),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              tooltip: 'Delete Department',
              onPressed: () => handleDeleteSpecialty(
                context,
                ref,
                spec,
                onDeleted: () {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
        ],
      ),
      body: doctorsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        error: (e, _) => ErrorStateView(
          message: e.toString(),
          onRetry: () {
            if (widget.role == SpecialtyScreenRole.admin) {
              ref.invalidate(allDoctorsAdminProvider);
            } else {
              ref.invalidate(verifiedDoctorsStreamProvider);
            }
          },
        ),
        data: (allDoctors) {
          final departmentDoctors = allDoctors.where((d) {
            final matches = d.specialtyId == spec.id ||
                d.specialtyId.toLowerCase() == spec.id.toLowerCase() ||
                (d.specialtyName.isNotEmpty &&
                    d.specialtyName.toLowerCase() == spec.name.toLowerCase());
            if (widget.role == SpecialtyScreenRole.patient) {
              return matches && d.isVerified;
            }
            return matches;
          }).toList();

          final filtered = SmartSearchEngine.filterAndSort<DoctorModel>(
            items: departmentDoctors,
            query: _query,
            primaryTextBuilder: (d) => d.doctorName,
            secondaryTextsBuilder: (d) => [
              d.licenseNumber,
              d.bio,
              '${d.experienceYears} yrs',
              '\$${d.consultationFee.toStringAsFixed(0)}',
              d.verificationStatus.displayName,
            ],
            fallbackComparator: (a, b) => a.doctorName
                .toLowerCase()
                .compareTo(b.doctorName.toLowerCase()),
          );

          final verifiedCount = departmentDoctors
              .where((d) => d.verificationStatus == VerificationStatus.approved)
              .length;

          final docsWithFee =
              departmentDoctors.where((d) => d.consultationFee > 0).toList();
          double avgFee = docsWithFee.isNotEmpty
              ? docsWithFee.fold<double>(
                      0.0, (sum, d) => sum + d.consultationFee) /
                  docsWithFee.length
              : 0.0;
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

          final avgExp = departmentDoctors.isEmpty
              ? 0.0
              : departmentDoctors.fold<int>(
                    0,
                    (sum, d) => sum + d.experienceYears,
                  ) /
                  departmentDoctors.length;

          final docsWithRating =
              departmentDoctors.where((d) => d.rating > 0).toList();
          final avgRating = docsWithRating.isNotEmpty
              ? docsWithRating.fold<double>(0.0, (sum, d) => sum + d.rating) /
                  docsWithRating.length
              : 5.0;

          return Column(
            children: [
              // 1. Flat Specialty Department Header + Quick Metrics
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            spec.iconData,
                            color: accent,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                spec.name,
                                style: AppTypography.headline.copyWith(
                                  fontSize: 18,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
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
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _DepartmentStatChip(
                          label: 'Specialists',
                          value: widget.role == SpecialtyScreenRole.admin
                              ? '$verifiedCount Active'
                              : '$verifiedCount Available',
                          color: accent,
                        ),
                        _DepartmentStatChip(
                          label: 'Avg Fee',
                          value: '\$${avgFee.toStringAsFixed(0)}',
                          color: AppColors.primary,
                        ),
                        _DepartmentStatChip(
                          label: 'Avg Exp',
                          value: '${avgExp.toStringAsFixed(1)} yrs',
                          color: AppColors.primary,
                        ),
                        _DepartmentStatChip(
                          label: 'Avg Rating',
                          value: '${avgRating.toStringAsFixed(1)} ★',
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppSearchBar(
                      controller: _searchCtrl,
                      hintText: widget.role == SpecialtyScreenRole.admin
                          ? 'Search ${spec.name} specialists by name, bio, license...'
                          : 'Search ${spec.name} specialists by name, bio...',
                      onChanged: (v) => setState(() => _query = v),
                      onClear: () => setState(() => _query = ''),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),

              // 2. Flat Detailed Specialist List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _query.trim().isEmpty
                                ? 'No specialists registered in ${spec.name} yet.'
                                : 'No ${spec.name} specialists match "$_query".',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: textSecondary,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 4, bottom: 40),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 84,
                          endIndent: 20,
                          color: borderColor,
                        ),
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final isPending = doc.verificationStatus ==
                              VerificationStatus.pending;

                          return InkWell(
                            onTap: () {
                              if (widget.role == SpecialtyScreenRole.admin) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminDoctorDetailScreen(
                                      doctorId: doc.id,
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DoctorDetailsScreen(
                                      doctorId: doc.id,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    doc.doctorName
                                        .replaceFirst('Dr. ', '')
                                        .characters
                                        .first
                                        .toUpperCase(),
                                    style: AppTypography.headline.copyWith(
                                      color: accent,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Line 1: Name + Rating / Pending Status
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              doc.doctorName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.headline
                                                  .copyWith(
                                                fontSize: 16,
                                                color: textPrimary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (widget.role ==
                                                  SpecialtyScreenRole.admin &&
                                              isPending)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.warning
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Pending',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                  color: AppColors.warning,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            )
                                          else
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.10),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.star_rounded,
                                                    size: 14,
                                                    color: AppColors.primary,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${doc.rating.toStringAsFixed(1)} (${doc.reviewCount})',
                                                    style: AppTypography
                                                        .caption
                                                        .copyWith(
                                                      color:
                                                          AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),

                                      // Line 2: Experience, Fee, License & Slot Duration
                                      Text(
                                        '${doc.experienceYears} yrs exp • \$${doc.consultationFee.toStringAsFixed(0)} fee • License ${doc.licenseNumber} • ${doc.slotDurationMinutes}m slot',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.caption.copyWith(
                                          color: accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),

                                      // Line 3: Clinical Bio / Description Preview
                                      if (doc.bio.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          doc.bio,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                            color: textSecondary,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    color: textSecondary,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DepartmentStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DepartmentStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: textSecondary,
          ),
        ),
      ],
    );
  }
}
