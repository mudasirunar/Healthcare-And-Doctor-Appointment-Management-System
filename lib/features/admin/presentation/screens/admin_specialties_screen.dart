import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../doctor/domain/entities/specialty_model.dart';
import '../../../doctor/presentation/screens/unified_specialties_screen.dart';
import '../../domain/entities/admin_analytics_model.dart';

export '../../../doctor/presentation/screens/unified_specialties_screen.dart'
    show
        GreenAddSpecialtyButton,
        showAddSpecialtyDialog,
        showEditSpecialtyDialog,
        handleDeleteSpecialty,
        SpecialtyScreenRole,
        UnifiedSpecialtiesScreen;

class AdminSpecialtiesScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return UnifiedSpecialtiesScreen(
      role: SpecialtyScreenRole.admin,
      specialtiesAsync: specialtiesAsync,
      analyticsAsync: analyticsAsync,
      onAddSpecialty: onAddSpecialty,
      scrollController: scrollController,
      isStandalone: isStandalone,
    );
  }
}
