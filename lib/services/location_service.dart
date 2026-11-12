import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fibus/core/constants/app_constants.dart';
import 'package:fibus/services/realtime_db_service.dart';

/// Whether a fix should be uploaded: always when the bus moved, and at least
/// every [AppConstants.heartbeatSeconds] while it stands still, so a bus
/// waiting at a stop or signal never looks like lost GPS to riders.
bool shouldPublishFix({
  required double movedMeters,
  required Duration? sinceLastPublish,
}) {
  if (sinceLastPublish == null) return true;
  if (movedMeters >= AppConstants.minPublishDistanceMeters) return true;
  return sinceLastPublish.inSeconds >= AppConstants.heartbeatSeconds;
}

/// GPS location broadcasting service for the Fibus Tracker application.
///
/// Samples GPS every few seconds whether or not the bus moves, filters poor
/// fixes, uploads to the Realtime Database, and records whether each upload
/// was confirmed so the UI never claims riders can see a bus they cannot.
class LocationService extends ChangeNotifier {
  final RealtimeDbService _rtdbService;

  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _lastPositionController =
      StreamController<Position>.broadcast();

  bool _isTracking = false;
  Position? _lastPosition;
  String? _activeBusId;
  int? _activeSessionGeneration;
  String? _lastError;

  Position? _lastPublishedPosition;
  DateTime? _lastPublishAttemptAt;
  DateTime? _lastUploadConfirmedAt;
  bool _superseded = false;

  /// Singleton instance.
  static final LocationService _instance = LocationService._internal();

  /// Shared singleton accessor.
  static LocationService get instance => _instance;

  /// Factory accessor returning singleton or dependency-injected instance.
  factory LocationService({RealtimeDbService? rtdbService}) {
    if (rtdbService != null) {
      return LocationService._internal(rtdbService: rtdbService);
    }
    return _instance;
  }

  LocationService._internal({RealtimeDbService? rtdbService})
    : _rtdbService = rtdbService ?? RealtimeDbService();

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// Whether the location service is actively capturing and broadcasting GPS fixes.
  bool get isTracking => _isTracking;

  /// Most recent valid GPS position fix recorded.
  Position? get currentPosition => _lastPosition;

  /// Broadcast stream of accepted GPS fixes.
  Stream<Position> get lastPosition => _lastPositionController.stream;

  /// The bus ID currently being tracked, or `null` if idle.
  String? get activeBusId => _activeBusId;

  /// The active session generation number.
  int? get activeSessionGeneration => _activeSessionGeneration;

  /// Last error message encountered during location tracking.
  String? get lastError => _lastError;

  /// When the server last confirmed an uploaded fix for this session.
  DateTime? get lastUploadConfirmedAt => _lastUploadConfirmedAt;

  /// True once the server rejected an upload because another phone took
  /// over this bus (or the operator was unassigned). Tracking is stopped.
  bool get superseded => _superseded;

  // ---------------------------------------------------------------------------
  // Tracking Lifecycle
  // ---------------------------------------------------------------------------

  /// Checks that location is on and permitted, asking the user if needed.
  /// Call before claiming a trip so a refusal never leaves a ghost trip.
  /// Throws a [LocationSetupException] with a message fit for the operator.
  Future<void> ensureReady() => _ensureLocationPermissions();

  /// Starts foreground GPS tracking and RTDB broadcasting for [busId].
  Future<void> startTracking({
    required String busId,
    required int sessionGeneration,
  }) async {
    if (_isTracking) {
      debugPrint('LocationService: already tracking a bus');
      if (_activeBusId == busId &&
          _activeSessionGeneration == sessionGeneration) {
        return;
      }
      await stopTracking();
    }

    _lastError = null;
    _superseded = false;
    _lastPublishedPosition = null;
    _lastPublishAttemptAt = null;
    _lastUploadConfirmedAt = null;

    try {
      await _ensureLocationPermissions();

      await _initForegroundTask(busId);
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Fibus Tracker is sharing this bus',
        notificationText: 'Open to see status or end the trip',
      );

      // distanceFilter 0: deliver a fix every interval even when stationary.
      // Uploads are throttled in [_onLocationReceived] instead.
      final LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          intervalDuration: const Duration(
            seconds: AppConstants.gpsIntervalSeconds,
          ),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );
      }

      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen(
                (Position position) => _onLocationReceived(
                  position: position,
                  busId: busId,
                  sessionGeneration: sessionGeneration,
                ),
                onError: (dynamic error) {
                  _lastError = 'Location stream error: $error';
                  debugPrint(_lastError);
                  notifyListeners();
                },
              );

      _isTracking = true;
      _activeBusId = busId;
      _activeSessionGeneration = sessionGeneration;
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to start tracking: $e';
      debugPrint(_lastError);
      await stopTracking();
      rethrow;
    }
  }

  /// Stops GPS sampling, cancels subscriptions, and terminates the foreground task.
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('Error stopping foreground task service: $e');
    }

    _isTracking = false;
    _activeBusId = null;
    _activeSessionGeneration = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Location Processing & RTDB Publishing
  // ---------------------------------------------------------------------------

  Future<void> _onLocationReceived({
    required Position position,
    required String busId,
    required int sessionGeneration,
  }) async {
    if (!_isValidFix(position)) return;

    _lastPosition = position;
    _lastPositionController.add(position);
    notifyListeners();

    final now = DateTime.now();
    final last = _lastPublishedPosition;
    final moved = last == null
        ? double.infinity
        : Geolocator.distanceBetween(
            last.latitude,
            last.longitude,
            position.latitude,
            position.longitude,
          );
    if (!shouldPublishFix(
      movedMeters: moved,
      sinceLastPublish: _lastPublishAttemptAt == null
          ? null
          : now.difference(_lastPublishAttemptAt!),
    )) {
      return;
    }
    _lastPublishedPosition = position;
    _lastPublishAttemptAt = now;

    try {
      // Offline, the write stays queued and this future would never finish;
      // the timeout only stops us counting it as confirmed.
      await _rtdbService
          .publishLocation(
            busId: busId,
            lat: position.latitude,
            lng: position.longitude,
            speed: position.speed.isFinite ? position.speed : 0,
            heading: position.heading.isFinite ? position.heading : 0,
            accuracy: position.accuracy,
            sessionGeneration: sessionGeneration,
          )
          .timeout(const Duration(seconds: AppConstants.uploadTimeoutSeconds));
      _lastUploadConfirmedAt = DateTime.now();
      notifyListeners();
    } on TimeoutException {
      debugPrint('Location upload not confirmed yet (no connection?)');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Another phone claimed a newer session, or the assignment was removed.
        _superseded = true;
        debugPrint('Location upload rejected: this session was superseded');
        await stopTracking();
      } else {
        debugPrint('Location upload failed: ${e.code}');
      }
    } catch (e) {
      debugPrint('Location upload failed: $e');
    }
  }

  /// Accepts a fix when its accuracy is within the PRD's 100 m limit, it is
  /// recent, and it is not an exact repeat of the previous one.
  bool _isValidFix(Position position) {
    if (position.accuracy > AppConstants.minAccuracyMeters) return false;

    final fixAge = DateTime.now().difference(position.timestamp);
    if (fixAge.inSeconds.abs() > AppConstants.maxFixAgeSeconds) return false;

    final last = _lastPosition;
    if (last != null && last.timestamp == position.timestamp) return false;

    return true;
  }

  // ---------------------------------------------------------------------------
  // Permissions & Foreground Task Setup
  // ---------------------------------------------------------------------------

  Future<void> _ensureLocationPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationSetupException(
        'Location is turned off. Turn it on in quick settings and try again',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationSetupException(
        'Fibus Tracker needs location permission to share the bus',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationSetupException(
        'Location permission is blocked. Allow it for Fibus Tracker in '
        'Android settings',
      );
    }

    // The foreground-service notification needs this on Android 13+.
    final notifPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notifPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  Future<void> _initForegroundTask(String busId) async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: AppConstants.trackerServiceChannelId,
        channelName: AppConstants.trackerServiceChannelName,
        channelDescription: AppConstants.trackerServiceChannelDesc,
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _lastPositionController.close();
    super.dispose();
  }
}

/// A location problem the operator can fix, with a message to show them.
class LocationSetupException implements Exception {
  const LocationSetupException(this.message);
  final String message;

  @override
  String toString() => message;
}
