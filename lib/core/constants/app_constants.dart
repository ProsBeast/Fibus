/// Application-wide constants for the Fibus ecosystem.
///
/// Contains tracking thresholds, GPS configuration, timing parameters,
/// and default buffer times used across Commuter and Tracker applications.
abstract final class AppConstants {
  // App Identifiers
  static const String commuterAppName = 'Fibus Commuter';
  static const String trackerAppName = 'Fibus Tracker';
  static const String commuterPackageName = 'com.fibus.commuter';
  static const String trackerPackageName = 'com.fibus.tracker';

  // Tracking & GPS Thresholds
  /// Bus status is considered stale if no GPS update has been received within 60 seconds.
  static const int staleThresholdSeconds = 60;
  static const Duration staleThreshold = Duration(seconds: staleThresholdSeconds);

  /// Target interval between continuous GPS location updates in the Tracker app.
  static const int gpsIntervalSeconds = 5;
  static const Duration gpsInterval = Duration(seconds: gpsIntervalSeconds);

  /// Time window over which speed and position updates are smoothed for ETA calculation.
  static const int smoothingWindowSeconds = 180;
  static const Duration smoothingWindow = Duration(seconds: smoothingWindowSeconds);

  /// Maximum acceptable GPS fix horizontal accuracy in meters.
  /// Fixes with accuracy worse (higher) than 50m are rejected.
  static const double minAccuracyMeters = 50.0;

  /// Commuter-side ETA ignores fixes worse than this (PRD §9.2: 100 m).
  static const double maxEtaFixAccuracyMeters = 100.0;

  /// Maximum age in seconds for a cached location fix before it is discarded.
  static const int maxFixAgeSeconds = 30;
  static const Duration maxFixAge = Duration(seconds: maxFixAgeSeconds);

  // Commute & Departure Buffers
  /// Minimum time allocated for the commuter to walk to the stop and board the bus.
  static const int boardingBufferMinutes = 5;
  static const Duration boardingBuffer = Duration(minutes: boardingBufferMinutes);

  /// Maximum dynamic safety margin added to commuter departure time under unpredictable conditions.
  static const int maxSafetyMarginMinutes = 5;
  static const Duration maxSafetyMargin = Duration(minutes: maxSafetyMarginMinutes);

  /// Default advance warning time in minutes before recommended departure.
  static const int defaultAdvanceWarningMinutes = 10;
  static const Duration defaultAdvanceWarning = Duration(minutes: defaultAdvanceWarningMinutes);

  // Service Region (pilot runs in Telangana)
  /// State name that location search results must belong to.
  static const String serviceRegionState = 'Telangana';

  /// Bounding box around Telangana as `minLon,minLat,maxLon,maxLat`.
  static const String serviceRegionBbox = '77.2,15.8,81.4,19.95';

  // Map & Navigation Defaults
  /// Default map center latitude (Hyderabad, Telangana, India).
  static const double defaultLatitude = 17.3850;
  /// Default map center longitude (Hyderabad, Telangana, India).
  static const double defaultLongitude = 78.4867;

  static const double defaultMapZoom = 14.0;
  static const double minMapZoom = 8.0;
  static const double maxMapZoom = 19.0;
  static const double activeBusTrackingZoom = 16.0;

  // Notification Channel IDs
  static const String departureAlertChannelId = 'fibus_departure_alerts';
  static const String departureAlertChannelName = 'Departure Alerts';
  static const String departureAlertChannelDesc =
      'Real-time notifications warning when to leave home for your bus.';

  static const String trackerServiceChannelId = 'fibus_tracker_service';
  static const String trackerServiceChannelName = 'Bus Tracking Service';
  static const String trackerServiceChannelDesc =
      'Foreground service notification while actively broadcasting bus location.';
}
