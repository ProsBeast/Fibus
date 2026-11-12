import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fibus/app/tracker_app.dart';
import 'package:fibus/services/notification_service.dart';

/// Entry point for the Fibus Tracker (Operator / Driver) Android application.
///
/// Configures Flutter bindings, initializes Firebase Spark services,
/// registers foreground/local notification channels, locks device orientation
/// to portrait for driver dashboard stability, and launches [TrackerApp].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase services
  try {
    await Firebase.initializeApp();
  } catch (e, stack) {
    developer.log('Firebase initialization notice: $e', stackTrace: stack);
  }

  // 2. Initialize notification channels for background departure & alert tracking
  try {
    await NotificationService.instance.initialize();
  } catch (e, stack) {
    developer.log(
      'NotificationService initialization notice: $e',
      stackTrace: stack,
    );
  }

  // 3. Lock orientation to portrait for driver dashboard stability
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    developer.log('Orientation lock notice: $e');
  }

  runApp(const TrackerApp());
}
