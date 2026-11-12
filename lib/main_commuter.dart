import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fibus/app/commuter_app.dart';
import 'package:fibus/services/notification_service.dart';

/// Entry point for the Fibus Commuter Android application.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase Spark suite
  try {
    await Firebase.initializeApp();
  } catch (e, stack) {
    developer.log('Firebase initialization notice: $e', stackTrace: stack);
  }

  // Initialize background & local notification delivery service
  try {
    await NotificationService.instance.initialize();
  } catch (e, stack) {
    developer.log(
      'NotificationService initialization notice: $e',
      stackTrace: stack,
    );
  }

  runApp(const CommuterApp());
}
