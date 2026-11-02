import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/preferences_service.dart';

/// Set to true for local testing with zero quota and instant responses.
/// Set to false before building the production release APK.
const bool kUseLocalFirestore = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local User Preferences (ThemeMode persistence)
  await PreferencesService.instance.initialize();

  // Native Firebase initialization using google-services.json & GoogleService-Info.plist
  try {
    await Firebase.initializeApp();

    // Route Firestore to local emulator if enabled
    if (kUseLocalFirestore) {
      // 192.168.1.106 allows physical iOS/Android phones and simulators on the same Wi-Fi to connect to Mac's emulator
      final host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : '192.168.1.106';
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
      debugPrint('⚡ Connected FirebaseFirestore to Local Emulator at $host:8080');
    }

    // Initialize Push Notifications (Android only, non-blocking)
    if (!Platform.isIOS) {
      NotificationService.instance.initialize().catchError((e) {
        debugPrint('Notification service init notice: $e');
      });
    }
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  runApp(
    const ProviderScope(
      child: HealthcareApp(),
    ),
  );
}
