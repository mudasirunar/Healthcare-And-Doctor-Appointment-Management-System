import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import 'booking_screen.dart';

class DoctorDetailsScreen extends ConsumerWidget {
  final String doctorId;

  const DoctorDetailsScreen({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorRepo = ref.watch(doctorRepositoryProvider);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Specialist Profile'),
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
      ),
      body: FutureBuilder<DoctorModel?>(
        future: doctorRepo.getDoctorById(doctorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
          }
          final doctor = snapshot.data;
          if (doctor == null) {
            return const ErrorStateView(message: 'Specialist record not found.');
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    // 1. Flat Header Section (Avatar, Name, Specialty, Verified Badge)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            backgroundImage: doctor.avatarUrl != null
                                ? NetworkImage(doctor.avatarUrl!)
                                : null,
                            child: doctor.avatarUrl == null
                                ? Text(
                                    doctor.doctorName.isNotEmpty
                                        ? doctor.doctorName
                                            .replaceFirst(RegExp(r'^Dr\.\s*'), '')
                                            .characters
                                            .first
                                            .toUpperCase()
                                        : 'D',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        doctor.doctorName,
                                        style: AppTypography.display.copyWith(
                                          fontSize: 20,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (doctor.isVerified) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, size: 18, color: AppColors.primary),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${doctor.specialtyName} • License ${doctor.licenseNumber}',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Verified Specialist',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: borderColor),

                    // 2. Flat Key Metrics Row
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _FlatStatItem(
                            label: 'Experience',
                            value: '${doctor.experienceYears} yrs',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          _FlatStatItem(
                            label: 'Consult Fee',
                            value: '\$${doctor.consultationFee.toStringAsFixed(0)}',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          _FlatStatItem(
                            label: 'Rating',
                            value: '${doctor.rating.toStringAsFixed(1)} ★',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          _FlatStatItem(
                            label: 'Reviews',
                            value: '${doctor.reviewCount}',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: borderColor),

                    // 3. Biography & Clinical Background
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Text(
                        'Clinical Background',
                        style: AppTypography.headline.copyWith(
                          fontSize: 16,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        doctor.bio.isNotEmpty
                            ? doctor.bio
                            : 'Dedicated medical practitioner focused on providing comprehensive diagnostic care and tailored clinical consultations.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Divider(height: 1, color: borderColor),

                    // 4. Clinical Details & Credentials
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Text(
                        'Professional Credentials',
                        style: AppTypography.headline.copyWith(
                          fontSize: 16,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    _DetailRow(
                      icon: Icons.badge_outlined,
                      label: 'License Number',
                      value: doctor.licenseNumber,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    Divider(height: 1, indent: 56, endIndent: 20, color: borderColor),
                    _DetailRow(
                      icon: Icons.category_outlined,
                      label: 'Medical Department',
                      value: doctor.specialtyName,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    Divider(height: 1, indent: 56, endIndent: 20, color: borderColor),
                    _DetailRow(
                      icon: Icons.translate_rounded,
                      label: 'Languages',
                      value: 'English, Spanish',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    Divider(height: 1, color: borderColor),

                    // 5. Weekly Availability Hours
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Text(
                        'Weekly Consultation Hours',
                        style: AppTypography.headline.copyWith(
                          fontSize: 16,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    ...['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'].map((day) {
                      final windows = doctor.weeklyAvailability[day] ?? [];
                      final capitalizedDay = day[0].toUpperCase() + day.substring(1);
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  capitalizedDay,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                if (windows.isEmpty)
                                  Text(
                                    'Unavailable',
                                    style: AppTypography.caption.copyWith(color: textSecondary),
                                  )
                                else
                                  Row(
                                    children: windows.map<Widget>((w) {
                                      return Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${w.start} - ${w.end}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                          Divider(height: 1, indent: 20, endIndent: 20, color: borderColor),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              // 6. Sticky Bottom Action Bar (Book Appointment)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Consultation Fee',
                            style: AppTypography.caption.copyWith(color: textSecondary),
                          ),
                          Text(
                            '\$${doctor.consultationFee.toStringAsFixed(0)}',
                            style: AppTypography.headline.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookingScreen(doctorId: doctor.id),
                                ),
                              );
                            },
                            icon: const Icon(Icons.calendar_month_rounded, size: 18),
                            label: const Text('Book Appointment', style: TextStyle(fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FlatStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;

  const _FlatStatItem({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.headline.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(color: textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
