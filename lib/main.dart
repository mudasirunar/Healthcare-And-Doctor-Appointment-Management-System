import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local User Preferences (ThemeMode persistence)
  await PreferencesService.instance.initialize();

  // Native Firebase initialization using google-services.json & GoogleService-Info.plist
  try {
    await Firebase.initializeApp();

    // Initialize Push Notifications
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  runApp(
    const ProviderScope(
      child: HealthcareApp(),
    ),
  );
}
