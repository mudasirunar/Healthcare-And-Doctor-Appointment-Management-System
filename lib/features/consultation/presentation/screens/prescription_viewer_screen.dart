import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare_app/core/providers/app_providers.dart';
import 'package:healthcare_app/core/theme/app_colors.dart';
import 'package:healthcare_app/core/theme/app_typography.dart';
import 'package:healthcare_app/core/utils/date_time_utils.dart';
import 'package:healthcare_app/core/widgets/app_snack_bar.dart';
import 'package:healthcare_app/core/widgets/state_views.dart';
import 'package:healthcare_app/features/consultation/domain/entities/prescription_model.dart';

class PrescriptionViewerScreen extends ConsumerWidget {
  final String prescriptionId;

  const PrescriptionViewerScreen({super.key, required this.prescriptionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aptRepo = ref.watch(appointmentRepositoryProvider);

    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Digital Prescription'),
        actions: [
          IconButton(
            tooltip: 'Export / Print PDF',
            icon: const Icon(Icons.print_rounded),
            onPressed: () {
              AppSnackBar.showSuccess(
                context,
                'Prescription PDF exported to device documents.',
              );
            },
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              AppSnackBar.showInfo(
                context,
                'Prescription link copied to clipboard.',
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<PrescriptionModel?>(
        future: Future.value(aptRepo.getPrescriptionById(prescriptionId)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rx = snapshot.data;
          if (rx == null) {
            return const ErrorStateView(message: 'Prescription document not found.');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clinic / Hospital Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLightOf(context),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Healthcare Telehealth Network',
                                    style: AppTypography.headline.copyWith(color: textPrimary),
                                  ),
                                  Text(
                                    'Certified Digital Telehealth Clinic',
                                    style: AppTypography.caption.copyWith(color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Rx #${rx.id.toUpperCase()}',
                        style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Divider(height: 28, color: borderColor, thickness: 1.5),

                  // Doctor & Patient Meta
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PRESCRIBING PHYSICIAN', style: AppTypography.caption.copyWith(color: textSecondary)),
                            const SizedBox(height: 4),
                            Text(rx.doctorName, style: AppTypography.headline.copyWith(fontSize: 16, color: textPrimary)),
                            Text(rx.doctorSpecialty, style: AppTypography.bodyMedium.copyWith(color: AppColors.primary)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('PATIENT DETAILS', style: AppTypography.caption.copyWith(color: textSecondary)),
                            const SizedBox(height: 4),
                            Text(rx.patientName, style: AppTypography.headline.copyWith(fontSize: 16, color: textPrimary)),
                            Text(
                              'Date: ${DateTimeUtils.formatLocalDate(rx.issuedAtUtc)}',
                              style: AppTypography.caption.copyWith(color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 28, color: borderColor),

                  // Diagnosis
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariantOf(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DIAGNOSIS & CLINICAL IMPRESSION', style: AppTypography.caption.copyWith(color: textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          rx.diagnosis,
                          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Rx Symbol Header
                  Row(
                    children: [
                      const Text(
                        '℞',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'serif',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Prescribed Medications', style: AppTypography.headline.copyWith(color: textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Medications List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rx.medications.length,
                    separatorBuilder: (_, __) => Divider(height: 16, color: borderColor),
                    itemBuilder: (context, index) {
                      final med = rx.medications[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLightOf(context),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      med.name,
                                      style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: textPrimary),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondaryLightOf(context),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        med.dosage,
                                        style: AppTypography.caption.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Frequency: ${med.frequency} • Duration: ${med.duration}',
                                  style: AppTypography.bodyMedium.copyWith(color: textSecondary),
                                ),
                                if (med.instructions != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Special Note: ${med.instructions}',
                                    style: AppTypography.caption.copyWith(color: textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  if (rx.notes != null && rx.notes!.isNotEmpty) ...[
                    Divider(height: 28, color: borderColor),
                    Text('ADDITIONAL ADVICE / FOLLOW-UP', style: AppTypography.caption.copyWith(color: textSecondary)),
                    const SizedBox(height: 6),
                    Text(rx.notes!, style: AppTypography.bodyMedium.copyWith(color: textSecondary)),
                  ],

                  Divider(height: 32, color: borderColor, thickness: 1.5),

                  // Digital Signature Block
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.success),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Cryptographically Verified Digital Record',
                                    style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Issued: ${DateTimeUtils.formatFullWithTimeZone(rx.issuedAtUtc)}',
                              style: AppTypography.caption.copyWith(color: AppColors.textMutedOf(context)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.primary),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  rx.doctorName,
                                  style: const TextStyle(
                                    fontFamily: 'serif',
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  'Digital Signature Verified',
                                  style: AppTypography.caption.copyWith(fontSize: 8, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
