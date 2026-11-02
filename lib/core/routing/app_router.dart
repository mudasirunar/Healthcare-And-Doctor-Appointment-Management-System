import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/role_dispatcher_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/patient/presentation/screens/patient_main_screen.dart';
import '../../features/patient/presentation/screens/doctor_details_screen.dart';
import '../../features/patient/presentation/screens/booking_screen.dart';
import '../../features/patient/presentation/screens/patient_appointments_screen.dart';
import '../../features/patient/presentation/screens/patient_notifications_screen.dart';
import '../../features/patient/presentation/screens/patient_specialties_screen.dart';
import '../../features/consultation/presentation/screens/patient_chats_hub_screen.dart';
import '../../features/consultation/presentation/screens/doctor_chats_hub_screen.dart';
import '../../features/doctor/presentation/screens/doctor_main_screen.dart';
import '../../features/doctor/presentation/screens/doctor_notifications_screen.dart';
import '../../features/doctor/presentation/screens/doctor_practice_insights_screen.dart';
import '../../features/doctor/presentation/screens/doctor_agenda_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_notifications_screen.dart';
import '../../features/admin/presentation/screens/admin_doctor_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_patient_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_appointment_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_specialties_screen.dart';
import '../../features/admin/presentation/screens/admin_analytics_screen.dart';
import '../../features/appointment/domain/entities/appointment_model.dart';
import '../../features/consultation/presentation/screens/video_consultation_screen.dart';
import '../../features/consultation/presentation/screens/appointment_chat_screen.dart';
import '../../features/consultation/presentation/screens/prescription_viewer_screen.dart';
import '../../features/consultation/presentation/screens/doctor_prescription_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const RoleDispatcherScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/patient',
      builder: (context, state) => const PatientMainScreen(),
    ),
    GoRoute(
      path: '/patient/home',
      builder: (context, state) => const PatientMainScreen(),
    ),
    GoRoute(
      path: '/patient/doctor/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return DoctorDetailsScreen(doctorId: id);
      },
    ),
    GoRoute(
      path: '/patient/book/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return BookingScreen(doctorId: id);
      },
    ),
    GoRoute(
      path: '/patient/appointments',
      builder: (context, state) => const PatientAppointmentsScreen(isStandalone: true),
    ),
    GoRoute(
      path: '/patient/notifications',
      builder: (context, state) => const PatientNotificationsScreen(),
    ),
    GoRoute(
      path: '/patient/specialties',
      builder: (context, state) => const PatientSpecialtiesScreen(),
    ),
    GoRoute(
      path: '/patient/chats',
      builder: (context, state) => const PatientChatsHubScreen(),
    ),
    GoRoute(
      path: '/doctor',
      builder: (context, state) => const DoctorMainScreen(),
    ),
    GoRoute(
      path: '/doctor/workspace',
      builder: (context, state) => const DoctorMainScreen(),
    ),
    GoRoute(
      path: '/doctor/chats',
      builder: (context, state) => const DoctorChatsHubScreen(),
    ),
    GoRoute(
      path: '/doctor/notifications',
      builder: (context, state) => const DoctorNotificationsScreen(),
    ),
    GoRoute(
      path: '/doctor/specialties',
      builder: (context, state) => const UnifiedSpecialtiesScreen(role: SpecialtyScreenRole.doctor),
    ),
    GoRoute(
      path: '/doctor/insights',
      builder: (context, state) => const DoctorPracticeInsightsScreen(),
    ),
    GoRoute(
      path: '/doctor/agenda',
      builder: (context, state) => const DoctorAgendaScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/notifications',
      builder: (context, state) => const AdminNotificationsScreen(),
    ),
    GoRoute(
      path: '/admin/specialties',
      builder: (context, state) => const AdminSpecialtiesScreen(),
    ),
    GoRoute(
      path: '/admin/analytics',
      builder: (context, state) => const AdminAnalyticsScreen(),
    ),
    GoRoute(
      path: '/admin/doctor/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return AdminDoctorDetailScreen(doctorId: id);
      },
    ),
    GoRoute(
      path: '/admin/patient/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return AdminPatientDetailScreen(patientId: id);
      },
    ),
    GoRoute(
      path: '/admin/appointment/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return AdminAppointmentDetailScreen(appointmentId: id);
      },
    ),
    GoRoute(
      path: '/consultation/room/:appointmentId',
      builder: (context, state) {
        final aptId = state.pathParameters['appointmentId'] ?? '';
        return VideoConsultationScreen(appointmentId: aptId);
      },
    ),
    GoRoute(
      path: '/consultation/chat/:appointmentId',
      builder: (context, state) {
        final aptId = state.pathParameters['appointmentId'] ?? '';
        return AppointmentChatScreen(appointmentId: aptId);
      },
    ),
    GoRoute(
      path: '/prescription/:id',
      builder: (context, state) {
        final rxId = state.pathParameters['id'] ?? '';
        return PrescriptionViewerScreen(prescriptionId: rxId);
      },
    ),
    GoRoute(
      path: '/doctor/prescription',
      builder: (context, state) {
        final apt = state.extra as AppointmentModel?;
        if (apt == null) {
          return const Scaffold(
            body: Center(child: Text('Appointment record required')),
          );
        }
        return DoctorPrescriptionScreen(appointment: apt);
      },
    ),
  ],
);
