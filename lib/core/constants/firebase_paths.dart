/// Centralized path registry for Cloud Firestore and Firebase Realtime Database.
///
/// Ensures consistent collection names and path generation across the app.
abstract final class FirebasePaths {
  // ---------------------------------------------------------------------------
  // Firestore Collection Names
  // ---------------------------------------------------------------------------
  static const String usersCollection = 'users';
  static const String busesCollection = 'buses';
  static const String routesCollection = 'routes';
  static const String stopsCollection = 'stops';
  static const String stopTimesCollection = 'stopTimes';
  static const String operatorAssignmentsCollection = 'operatorAssignments';
  static const String commutePreferencesCollection = 'commutePreferences';
  static const String alertSessionsCollection = 'alertSessions';

  // ---------------------------------------------------------------------------
  // Firestore Document Path Helpers
  // ---------------------------------------------------------------------------

  /// Path to a specific user document: `users/{uid}`
  static String user(String uid) => '$usersCollection/$uid';

  /// Path to a specific bus document: `buses/{busId}`
  static String bus(String busId) => '$busesCollection/$busId';

  /// Path to a specific route document: `routes/{routeId}`
  static String route(String routeId) => '$routesCollection/$routeId';

  /// Path to a specific stop document: `stops/{stopId}`
  static String stop(String stopId) => '$stopsCollection/$stopId';

  /// Path to a specific scheduled stop time: `stopTimes/{stopTimeId}`
  static String stopTime(String stopTimeId) => '$stopTimesCollection/$stopTimeId';

  /// Path to an operator assignment document: `operatorAssignments/{assignmentId}`
  static String operatorAssignment(String assignmentId) =>
      '$operatorAssignmentsCollection/$assignmentId';

  /// Path to a commuter's preference document: `commutePreferences/{prefId}`
  static String commutePreference(String prefId) =>
      '$commutePreferencesCollection/$prefId';

  /// Path to a commuter's primary preference:
  /// `users/{uid}/commutePreferences/primary`
  static String primaryCommutePreference(String uid) =>
      '$usersCollection/$uid/$commutePreferencesCollection/primary';

  /// Path to an active alert session document: `alertSessions/{sessionId}`
  static String alertSession(String sessionId) =>
      '$alertSessionsCollection/$sessionId';

  // ---------------------------------------------------------------------------
  // Realtime Database (RTDB) Path Helpers
  // ---------------------------------------------------------------------------
  static const String liveBusesPath = 'liveBuses';
  static const String activeSessionsPath = 'activeSessions';

  /// RTDB node for a live bus's telemetry and stop ETAs: `liveBuses/{busId}`
  static String liveBus(String busId) => '$liveBusesPath/$busId';

  /// RTDB sub-path for a live bus's ETA map: `liveBuses/{busId}/busEta`
  static String liveBusEta(String busId) => '$liveBusesPath/$busId/busEta';

  /// RTDB sub-path for a specific stop's ETA seconds: `liveBuses/{busId}/busEta/{stopId}`
  static String liveBusStopEta(String busId, String stopId) =>
      '$liveBusesPath/$busId/busEta/$stopId';

  /// RTDB node for tracking operator session state: `activeSessions/{busId}`
  static String activeSession(String busId) => '$activeSessionsPath/$busId';
}
