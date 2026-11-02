import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/app_providers.dart';
import 'core/routing/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/presence_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/entities/user_model.dart';

class HealthcareApp extends ConsumerStatefulWidget {
  const HealthcareApp({super.key});

  @override
  ConsumerState<HealthcareApp> createState() => _HealthcareAppState();
}

class _HealthcareAppState extends ConsumerState<HealthcareApp> {
  @override
  void initState() {
    super.initState();

    // Configure notification tap navigation handler
    NotificationService.instance.onNotificationTap = (payload) {
      if (payload.contains('admin')) {
        appRouter.push('/admin/notifications');
      } else {
        appRouter.push('/patient/notifications');
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    // Automatically manage real-time notification listener and presence ONLY when user changes
    ref.listen<UserModel?>(currentUserProvider, (previous, next) {
      if (next != null) {
        if (previous?.id != next.id) {
          NotificationService.instance.startListeningForUser(
            next.id,
            isAdmin: next.isAdmin,
          );
          if (!next.isAdmin) {
            PresenceService.instance.initialize(next.id);
          }
        }
      } else if (previous != null) {
        NotificationService.instance.stopListening();
        PresenceService.instance.dispose();
      }
    });

    return MaterialApp.router(
      title: 'Healthcare App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
