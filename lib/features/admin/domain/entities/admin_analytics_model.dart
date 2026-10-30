import '../../../doctor/domain/entities/doctor_model.dart';

/// Live aggregated metrics fetched directly from Cloud Firestore.
class AdminAnalyticsModel {
  final int totalPatients;
  final int verifiedDoctors;
  final int pendingVerifications;
  final int rejectedDoctors;
  final int totalSpecialties;
  final int totalAppointments;
  final int upcomingAppointments;
  final int completedAppointments;
  final int cancelledAppointments;
  final double avgConsultationFee;
  final double minConsultationFee;
  final double maxConsultationFee;
  final double avgExperienceYears;
  final double avgDoctorRating;
  final int totalReviewsCount;
  final Map<String, int> doctorCountBySpecialtyId;
  final Map<String, double> avgFeeBySpecialtyId;
  final List<DoctorModel> topDoctors;

  const AdminAnalyticsModel({
    required this.totalPatients,
    required this.verifiedDoctors,
    required this.pendingVerifications,
    this.rejectedDoctors = 0,
    required this.totalSpecialties,
    required this.totalAppointments,
    this.upcomingAppointments = 0,
    required this.completedAppointments,
    required this.cancelledAppointments,
    this.avgConsultationFee = 0.0,
    this.minConsultationFee = 0.0,
    this.maxConsultationFee = 0.0,
    this.avgExperienceYears = 0.0,
    this.avgDoctorRating = 0.0,
    this.totalReviewsCount = 0,
    required this.doctorCountBySpecialtyId,
    this.avgFeeBySpecialtyId = const {},
    this.topDoctors = const [],
  });

  double get cancellationRatePercentage {
    if (totalAppointments == 0) return 0.0;
    return (cancelledAppointments / totalAppointments) * 100.0;
  }

  double get completionRatePercentage {
    if (totalAppointments == 0) return 100.0;
    final nonCancelled = totalAppointments - cancelledAppointments;
    if (nonCancelled <= 0) return 0.0;
    return (completedAppointments / nonCancelled) * 100.0;
  }
}
