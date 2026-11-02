import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/smart_search_utils.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../appointment/domain/entities/appointment_model.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../consultation/presentation/screens/prescription_builder_dialog.dart';
import '../../../doctor/domain/entities/doctor_model.dart';
import '../../../patient/presentation/screens/unified_patient_detail_screen.dart';
import 'doctor_practice_insights_screen.dart';
import 'unified_specialties_screen.dart';
import 'unified_specialty_doctors_screen.dart';

class DoctorDashboardScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const DoctorDashboardScreen({super.key, this.scrollController});

  @override
  ConsumerState<DoctorDashboardScreen> createState() =>
      _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends ConsumerState<DoctorDashboardScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedFilter = 'Active'; // 'All' | 'Active' | 'Completed'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showNotesDialog(AppointmentModel apt) {
    final notesController =
        TextEditingController(text: apt.consultationNotes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.note_alt_outlined,
        tone: AppDialogTone.primary,
        title: 'Clinical Observations',
        message: 'Patient: ${apt.patientName} • Reason: "${apt.reasonForVisit}"',
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Clinical Notes',
              hintText: 'Enter clinical impressions, diagnosis, symptoms, or observations...',
              alignLabelWithHint: true,
            ),
          ),
        ),
        cancelLabel: 'Cancel',
        onCancel: () => Navigator.pop(ctx),
        confirmLabel: 'Save Notes',
        onConfirm: () async {
          Navigator.pop(ctx);
          final user = ref.read(currentUserProvider);
          await ref.read(appointmentRepositoryProvider).updateStatus(
                appointmentId: apt.id,
                targetStatus: apt.status,
                actorUserId: user?.id ?? 'doctor',
                note: notesController.text.trim(),
              );
          ref.invalidate(userAppointmentsProvider);
          if (mounted) {
            AppSnackBar.showSuccess(context, 'Clinical notes saved.');
          }
        },
      ),
    );
  }

  void _startConsultation(AppointmentModel apt) async {
    final user = ref.read(currentUserProvider);
    if (apt.status == AppointmentStatus.confirmed) {
      await ref.read(appointmentRepositoryProvider).updateStatus(
            appointmentId: apt.id,
            targetStatus: AppointmentStatus.inProgress,
            actorUserId: user?.id ?? 'doctor',
            note: 'Doctor initiated consultation call',
          );
      ref.invalidate(userAppointmentsProvider);
    }
    if (mounted) {
      context.push('/consultation/room/${apt.id}');
    }
  }

  void _openPrescriptionBuilder(AppointmentModel apt) {
    showDialog(
      context: context,
      builder: (ctx) => PrescriptionBuilderDialog(
        appointment: apt,
        onPrescriptionCreated: () {
          ref.invalidate(userAppointmentsProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final specialtiesAsync = ref.watch(specialtiesProvider);
    final doctorRepo = ref.watch(doctorRepositoryProvider);

    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    final allAppointments = appointmentsAsync.valueOrNull ?? [];
    final specialties = specialtiesAsync.valueOrNull ?? [];
    final doctorsAsync = ref.watch(verifiedDoctorsStreamProvider);
    final allDoctors = doctorsAsync.valueOrNull ?? [];

    final Map<String, int> doctorCountBySpecialtyId = {};
    for (final spec in specialties) {
      doctorCountBySpecialtyId[spec.id] =
          allDoctors.where((d) => d.specialtyId == spec.id).length;
    }

    // Metrics calculations
    final now = DateTime.now();
    final todayAppointments = allAppointments.where((a) {
      try {
        final d = DateTime.parse(a.scheduledTimeUtc).toLocal();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      } catch (_) {
        return false;
      }
    }).toList();

    final pendingRequests = allAppointments
        .where((a) => a.status == AppointmentStatus.requested)
        .toList();

    final completedVisits = allAppointments
        .where((a) => a.status == AppointmentStatus.completed)
        .toList();

    final inProgressVisit = allAppointments
        .where((a) => a.status == AppointmentStatus.inProgress)
        .firstOrNull;

    final nextUpcomingVisit = allAppointments
        .where((a) => a.status == AppointmentStatus.confirmed)
        .firstOrNull;

    final heroAppointment = inProgressVisit ?? nextUpcomingVisit;

    // Filter agenda by tab and query
    final filteredByTab = allAppointments.where((a) {
      if (_selectedFilter == 'Active') {
        return a.status == AppointmentStatus.confirmed ||
            a.status == AppointmentStatus.inProgress;
      } else if (_selectedFilter == 'Completed') {
        return a.status == AppointmentStatus.completed;
      }
      return true; // 'All'
    }).toList();

    final filteredAppointments =
        SmartSearchEngine.filterAndSort<AppointmentModel>(
      items: filteredByTab,
      query: _query,
      primaryTextBuilder: (a) => a.patientName,
      secondaryTextsBuilder: (a) => [a.patientEmail, a.reasonForVisit],
      fallbackComparator: (a, b) =>
          b.scheduledTimeUtc.compareTo(a.scheduledTimeUtc),
    );

    // My Patients unique list
    final Map<String, AppointmentModel> uniquePatientsMap = {};
    for (final a in allAppointments) {
      if (a.patientId.isNotEmpty && !uniquePatientsMap.containsKey(a.patientId)) {
        uniquePatientsMap[a.patientId] = a;
      }
    }
    final myPatients = uniquePatientsMap.values.toList();

    return FutureBuilder<DoctorModel?>(
      future: user != null ? doctorRepo.getDoctorByUserId(user.id) : null,
      builder: (context, docSnap) {
        final doctor = docSnap.data;
        final fee = doctor?.consultationFee ?? 50.0;
        final totalEarnings = completedVisits.length * fee;
        final int completionRate = allAppointments.isNotEmpty
            ? ((completedVisits.length / allAppointments.length) * 100).round()
            : 100;

        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            // 1. Practice Metrics Quick Stats (2x2 Flat Cards)
            Row(
              children: [
                _DoctorDashboardStatCard(
                  title: "Today's Visits",
                  value: '${todayAppointments.length}',
                  subtitle: 'Scheduled visits',
                  icon: Icons.calendar_today_rounded,
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'Active';
                      _query = '';
                      _searchCtrl.clear();
                    });
                  },
                ),
                const SizedBox(width: 12),
                _DoctorDashboardStatCard(
                  title: 'Requests',
                  value: '${pendingRequests.length}',
                  subtitle: 'Pending review',
                  icon: Icons.mark_email_unread_rounded,
                  onTap: () {
                    ref.read(doctorSelectedTabProvider.notifier).state = 1;
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _DoctorDashboardStatCard(
                  title: 'Completed',
                  value: '${completedVisits.length}',
                  subtitle: 'Past consultations',
                  icon: Icons.check_circle_outline_rounded,
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'Completed';
                      _query = '';
                      _searchCtrl.clear();
                    });
                  },
                ),
                const SizedBox(width: 12),
                _DoctorDashboardStatCard(
                  title: 'Revenue',
                  value: '\$${totalEarnings.toStringAsFixed(0)}',
                  subtitle: 'Earned consultations',
                  icon: Icons.attach_money_rounded,
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'Completed';
                      _query = '';
                      _searchCtrl.clear();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Hero Active / Next Up Consultation Card (if any)
            if (heroAppointment != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    heroAppointment.status == AppointmentStatus.inProgress
                        ? 'Ongoing Consultation'
                        : 'Next Consultation',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  StatusBadge(status: heroAppointment.status),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: heroAppointment.status == AppointmentStatus.inProgress
                        ? AppColors.primary
                        : borderColor,
                    width: heroAppointment.status == AppointmentStatus.inProgress
                        ? 1.5
                        : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          child: Text(
                            heroAppointment.patientName.isNotEmpty
                                ? heroAppointment.patientName[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                heroAppointment.patientName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateTimeUtils.formatFullWithTimeZone(
                                    heroAppointment.scheduledTimeUtc),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (heroAppointment.reasonForVisit.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Reason: "${heroAppointment.reasonForVisit}"',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Divider(height: 1, color: borderColor),
                    const SizedBox(height: 12),

                    // Quick Action Buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _startConsultation(heroAppointment),
                          icon: const Icon(Icons.videocam_rounded, size: 16),
                          label: Text(
                            heroAppointment.status == AppointmentStatus.inProgress
                                ? 'Resume Video Call'
                                : 'Start Video Call',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                              '/consultation/chat/${heroAppointment.id}'),
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 15),
                          label: const Text('Chat'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: BorderSide(color: borderColor),
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showNotesDialog(heroAppointment),
                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                          label: const Text('Notes'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: BorderSide(color: borderColor),
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openPrescriptionBuilder(heroAppointment),
                          icon: const Icon(Icons.medication_outlined, size: 16),
                          label: const Text('Prescribe'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: BorderSide(color: borderColor),
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // 3. Flat Practice & Clinical Insights Banner (Matching Patient side style)
            Divider(height: 1, color: borderColor),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DoctorPracticeInsightsScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
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
                            'Practice & Clinical Insights',
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            completedVisits.isEmpty
                                ? 'Review clinical performance, revenue & volume trends'
                                : '${completedVisits.length} visits completed • $completionRate% completion • \$${totalEarnings.toStringAsFixed(0)} revenue',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: textSecondary),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 16),

            // 4. Medical Specialties Showcase (Flat with dynamic icons, matching patient side)
            if (specialties.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medical Specialties',
                          style: AppTypography.headline.copyWith(
                            fontSize: 17,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Clinical departments & verified specialists',
                          style: AppTypography.caption.copyWith(color: textSecondary),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/doctor/specialties'),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: const Text('See All'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: specialties.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (ctx, idx) {
                    final spec = specialties[idx];
                    final docCount = doctorCountBySpecialtyId[spec.id] ?? 0;

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UnifiedSpecialtyDoctorsScreen(
                              specialty: spec,
                              role: SpecialtyScreenRole.doctor,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                spec.iconData,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 7),
                            SizedBox(
                              width: 84,
                              child: Text(
                                spec.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$docCount Doc${docCount == 1 ? '' : 's'}',
                              textAlign: TextAlign.center,
                              style: AppTypography.caption.copyWith(
                                fontSize: 10.5,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 20),
            ],

            // 4. Consultation Agenda & Timeline
            Text(
              'Consultation Agenda',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Search Bar
            AppSearchBar(
              controller: _searchCtrl,
              hintText: 'Search agenda by patient or reason...',
              onChanged: (val) => setState(() => _query = val),
              onClear: () => setState(() => _query = ''),
            ),
            const SizedBox(height: 10),

            // Filter Chips
            Row(
              children: ['Active', 'Completed', 'All'].map((f) {
                final isSelected = _selectedFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilter = f);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Agenda List
            if (filteredAppointments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    _query.isNotEmpty
                        ? 'No appointments match "$_query".'
                        : 'No consultations found under "$_selectedFilter".',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ),
              )
            else
              ...filteredAppointments.map((apt) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.12),
                                child: Text(
                                  apt.patientName.isNotEmpty
                                      ? apt.patientName[0].toUpperCase()
                                      : 'P',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    apt.patientName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  Text(
                                    DateTimeUtils.formatFullWithTimeZone(
                                        apt.scheduledTimeUtc),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          StatusBadge(status: apt.status),
                        ],
                      ),
                      if (apt.reasonForVisit.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Reason: "${apt.reasonForVisit}"',
                          style: TextStyle(fontSize: 12.5, color: textSecondary),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Divider(height: 1, color: borderColor),
                      const SizedBox(height: 8),

                      // Action bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showNotesDialog(apt),
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: const Text('Notes', style: TextStyle(fontSize: 12.5)),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: () =>
                                context.push('/consultation/chat/${apt.id}'),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                            label: const Text('Chat', style: TextStyle(fontSize: 12.5)),
                          ),
                          if (apt.status == AppointmentStatus.confirmed ||
                              apt.status == AppointmentStatus.inProgress) ...[
                            const SizedBox(width: 4),
                            ElevatedButton.icon(
                              onPressed: () => _startConsultation(apt),
                              icon: const Icon(Icons.videocam_rounded, size: 15),
                              label: Text(
                                apt.status == AppointmentStatus.inProgress
                                    ? 'Resume'
                                    : 'Call',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 22),

            // 5. My Patients Section
            if (myPatients.isNotEmpty) ...[
              Text(
                'My Patients (${myPatients.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: myPatients.length > 5 ? 5 : myPatients.length,
                  separatorBuilder: (_, __) => Divider(height: 1, indent: 64, color: borderColor),
                  itemBuilder: (context, index) {
                    final apt = myPatients[index];

                    return ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UnifiedPatientDetailScreen(
                              patientId: apt.patientId,
                              role: UserRole.doctor,
                            ),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          apt.patientName.isNotEmpty ? apt.patientName[0].toUpperCase() : 'P',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        apt.patientName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Last visit: ${DateTimeUtils.formatRelativeTime(apt.scheduledTimeUtc)}',
                        style: TextStyle(fontSize: 11.5, color: textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DoctorDashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _DoctorDashboardStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  Icon(icon, size: 18, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

