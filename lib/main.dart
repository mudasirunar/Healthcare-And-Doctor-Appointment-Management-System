import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/preferences_service.dart';

/// Set to true for local testing with zero quota and instant responses.
/// Set to false before building the production release APK.
const bool kUseLocalFirestore = true;

/// Current Wi-Fi IP of this Mac running the Firestore emulator.
/// Allows physical iPhones and Android phones on the same Wi-Fi network to connect.
const String kMacLocalIp = '10.238.43.141';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local User Preferences (ThemeMode persistence)
  await PreferencesService.instance.initialize();

  // Native Firebase initialization using google-services.json & GoogleService-Info.plist
  try {
    await Firebase.initializeApp();

    // Route Firestore to local emulator if enabled
    if (kUseLocalFirestore) {
      // Connect to Mac's emulator (works across iOS Simulator, Android Emulator, and physical Wi-Fi devices)
      final host = kMacLocalIp;
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
