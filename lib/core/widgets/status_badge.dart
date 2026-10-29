import 'package:flutter/material.dart';
import '../../features/appointment/domain/entities/appointment_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class StatusBadge extends StatelessWidget {
  final AppointmentStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    switch (status) {
      case AppointmentStatus.requested:
        bg = AppColors.warningLight;
        text = AppColors.warning;
        break;
      case AppointmentStatus.confirmed:
        bg = AppColors.primaryLight;
        text = AppColors.primary;
        break;
      case AppointmentStatus.inProgress:
        bg = AppColors.secondaryLight;
        text = AppColors.secondary;
        break;
      case AppointmentStatus.completed:
        bg = AppColors.successLight;
        text = AppColors.success;
        break;
      case AppointmentStatus.cancelled:
      case AppointmentStatus.rejected:
        bg = AppColors.errorLight;
        text = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: AppTypography.caption.copyWith(color: text, fontWeight: FontWeight.w700),
      ),
    );
  }
}
