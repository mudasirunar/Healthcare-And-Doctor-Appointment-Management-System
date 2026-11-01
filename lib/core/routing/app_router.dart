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
import '../../features/doctor/presentation/screens/doctor_main_screen.dart';
import '../../features/doctor/presentation/screens/doctor_availability_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_notifications_screen.dart';
import '../../features/admin/presentation/screens/admin_doctor_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_patient_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_appointment_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_specialties_screen.dart';
import '../../features/admin/presentation/screens/admin_analytics_screen.dart';
import '../../features/consultation/presentation/screens/video_consultation_screen.dart';
import '../../features/consultation/presentation/screens/appointment_chat_screen.dart';
import '../../features/consultation/presentation/screens/prescription_viewer_screen.dart';

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
      path: '/doctor/workspace',
      builder: (context, state) => const DoctorMainScreen(),
    ),
    GoRoute(
      path: '/doctor/availability',
      builder: (context, state) => const DoctorAvailabilityScreen(),
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
  ],
);
