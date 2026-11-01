import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/smart_search_utils.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import '../../../doctor/domain/entities/specialty_model.dart';
import 'doctor_details_screen.dart';

class PatientSpecialtyDoctorsScreen extends ConsumerStatefulWidget {
  final SpecialtyModel specialty;

  const PatientSpecialtyDoctorsScreen({super.key, required this.specialty});

  @override
  ConsumerState<PatientSpecialtyDoctorsScreen> createState() =>
      _PatientSpecialtyDoctorsScreenState();
}

class _PatientSpecialtyDoctorsScreenState
    extends ConsumerState<PatientSpecialtyDoctorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'rating'; // 'rating' | 'fee' | 'exp'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(verifiedDoctorsStreamProvider);
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
                Expanded(
                  child: Text(
                    '${widget.specialty.name} Specialists',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.sort_rounded, color: textPrimary),
                  tooltip: 'Sort Doctors',
                  onSelected: (val) => setState(() => _sortBy = val),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'rating',
                      child: Text('Highest Rating'),
                    ),
                    const PopupMenuItem(
                      value: 'fee',
                      child: Text('Lowest Fee'),
                    ),
                    const PopupMenuItem(
                      value: 'exp',
                      child: Text('Most Experienced'),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Department Description Ribbon (Flat)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                Icon(widget.specialty.iconData,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.specialty.description,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: AppSearchBar(
              controller: _searchController,
              hintText: 'Search within ${widget.specialty.name}...',
              onChanged: (_) => setState(() {}),
              onClear: () => setState(() {}),
            ),
          ),

          // Doctor List
          Expanded(
            child: doctorsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              error: (err, _) => ErrorStateView(
                message: err.toString(),
                onRetry: () => ref.refresh(allDoctorsAdminProvider),
              ),
              data: (doctors) {
                // Filter by specialty & verification
                final specialtyDoctors = doctors.where((d) {
                  final matchesSpec = d.specialtyId == widget.specialty.id ||
                      d.specialtyName.toLowerCase() ==
                          widget.specialty.name.toLowerCase();
                  return matchesSpec && d.isVerified;
                }).toList();

                // Apply Search
                final searched = SmartSearchEngine.filterAndSort<DoctorModel>(
                  items: specialtyDoctors,
                  query: _searchController.text,
                  primaryTextBuilder: (d) => d.doctorName,
                  secondaryTextsBuilder: (d) => [d.bio, d.licenseNumber],
                );

                // Apply Sorting
                final sorted = List<DoctorModel>.from(searched);
                if (_sortBy == 'fee') {
                  sorted.sort((a, b) =>
                      a.consultationFee.compareTo(b.consultationFee));
                } else if (_sortBy == 'exp') {
                  sorted.sort((a, b) =>
                      b.experienceYears.compareTo(a.experienceYears));
                } else {
                  // Default highest rating
                  sorted.sort((a, b) => b.rating.compareTo(a.rating));
                }

                if (sorted.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.person_search_outlined,
                    title: 'No Doctors Found',
                    description:
                        'No verified doctors found in ${widget.specialty.name} matching your search.',
                  );
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, thickness: 1, color: borderColor),
                  itemBuilder: (context, index) {
                    final doctor = sorted[index];
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DoctorDetailsScreen(doctorId: doctor.id),
                          ),
                        );
                      },
                      child: Container(
                        color: surfaceColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.primaryLight,
                              backgroundImage: doctor.avatarUrl != null
                                  ? NetworkImage(doctor.avatarUrl!)
                                  : null,
                              child: doctor.avatarUrl == null
                                  ? Text(
                                      doctor.doctorName.isNotEmpty
                                          ? doctor.doctorName[0].toUpperCase()
                                          : 'D',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          doctor.doctorName,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified,
                                          size: 14, color: AppColors.primary),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${doctor.experienceYears}y experience',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          size: 15, color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 3),
                                      Text(
                                        doctor.rating.toStringAsFixed(1),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      Text(
                                        ' (${doctor.reviewCount})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '\$${doctor.consultationFee.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () =>
                                  context.push('/patient/book/${doctor.id}'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Book',
                                style: TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w700),
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
      ),
    );
  }
}

