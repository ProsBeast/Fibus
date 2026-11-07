import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fibus/core/constants/app_constants.dart';
import 'package:fibus/services/realtime_db_service.dart';

/// GPS location broadcasting service for the Fibus Tracker application.
///
/// Manages high-accuracy GPS streams via [Geolocator], enforces foreground
/// service persistence via [FlutterForegroundTask], validates fixes against
/// staleness/accuracy thresholds, and streams telemetry to Firebase RTDB.
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

  // ---------------------------------------------------------------------------
  // Tracking Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts foreground GPS tracking and RTDB broadcasting for [busId].
  ///
  /// Requests required device permissions, initiates foreground notification,
  /// configures high-accuracy GPS sampling (5s interval, 3m filter), and
  /// continuously broadcasts valid fixes to the RTDB.
  Future<void> startTracking({
    required String busId,
    required int sessionGeneration,
  }) async {
    if (_isTracking) {
      debugPrint('LocationService: Already tracking bus $_activeBusId.');
      if (_activeBusId == busId) return;
      await stopTracking();
    }

    _lastError = null;

    try {
      // 1. Verify and request GPS location permissions
      await _ensureLocationPermissions();

      // 2. Initialize and start Foreground Task Notification
      await _initForegroundTask(busId);
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Fibus Tracker Active',
        notificationText: 'Tracking Bus $busId',
      );

      // 3. Configure GPS stream settings
      final LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
          intervalDuration: const Duration(
            seconds: AppConstants.gpsIntervalSeconds,
          ),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        );
      }

      // 4. Subscribe to Geolocator position stream
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
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
    _positionSubscription?.cancel();
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
    // Quality check: Reject stale, inaccurate, or duplicate fixes
    if (!_isValidFix(position)) {
      debugPrint(
        'Discarded GPS fix: acc=${position.accuracy}m, age=${DateTime.now().difference(position.timestamp).inSeconds}s',
      );
      return;
    }

    _lastPosition = position;
    _lastPositionController.add(position);
    notifyListeners();

    // Broadcast to RTDB
    try {
      await _rtdbService.publishLocation(
        busId: busId,
        lat: position.latitude,
        lng: position.longitude,
        speed: position.speed,
        heading: position.heading,
        accuracy: position.accuracy,
        sessionGeneration: sessionGeneration,
      );

      // Update foreground notification status with live metrics
      final speedKmh = (position.speed * 3.6).toStringAsFixed(0);
      final accM = position.accuracy.toStringAsFixed(0);
      FlutterForegroundTask.updateService(
        notificationTitle: 'Tracking Bus $busId',
        notificationText: 'Live: $speedKmh km/h | Accuracy: ±${accM}m',
      );
    } catch (e) {
      debugPrint('Failed to publish location fix to RTDB: $e');
    }
  }

  /// Enforces validation criteria:
  /// 1. Horizontal accuracy < 50 meters
  /// 2. Age < 30 seconds
  /// 3. Must not be an exact duplicate of the previous fix
  bool _isValidFix(Position position) {
    // 1. Accuracy check
    if (position.accuracy > AppConstants.minAccuracyMeters) {
      return false;
    }

    // 2. Age check
    final now = DateTime.now();
    final fixAge = now.difference(position.timestamp);
    if (fixAge.inSeconds.abs() > AppConstants.maxFixAgeSeconds) {
      return false;
    }

    // 3. Duplicate check
    final last = _lastPosition;
    if (last != null) {
      final isSameLat = (last.latitude - position.latitude).abs() < 0.000005;
      final isSameLng = (last.longitude - position.longitude).abs() < 0.000005;
      final isSameTime = last.timestamp == position.timestamp;
      if (isSameLat && isSameLng && isSameTime) {
        return false;
      }
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Permissions & Foreground Task Setup
  // ---------------------------------------------------------------------------

  Future<void> _ensureLocationPermissions() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied by the user.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied. Please enable them in system settings.',
      );
    }

    // Check notification permission on Android 13+
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
        eventAction: ForegroundTaskEventAction.repeat(5000),
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
