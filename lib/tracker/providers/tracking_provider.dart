import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fibus/core/constants/app_constants.dart';
import 'package:fibus/services/location_service.dart';

/// State management provider for active GPS location broadcasting in the Tracker app.
///
/// Bridges [LocationService] with Flutter UI widgets, exposing real-time
/// tracking metrics including speed, accuracy, elapsed duration, and fix counters.
class TrackingProvider extends ChangeNotifier {
  final LocationService _locationService;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _durationTimer;

  bool _isTracking = false;
  Position? _currentPosition;
  double _speed = 0.0; // instantaneous speed in m/s
  double _accuracy = 0.0; // horizontal accuracy in meters
  int _fixCount = 0;
  DateTime? _sessionStartTime;
  Duration _sessionDuration = Duration.zero;
  String? _activeBusId;
  int? _sessionGeneration;
  DateTime? _lastFixTime;

  /// Creates a [TrackingProvider] instance.
  TrackingProvider({LocationService? locationService})
      : _locationService = locationService ?? LocationService.instance {
    _locationService.addListener(_onServiceChanged);
  }

  /// Mirrors upload confirmations and a service-side stop (for example when
  /// another phone takes over) into this provider.
  void _onServiceChanged() {
    if (_isTracking && !_locationService.isTracking) {
      _isTracking = false;
      _durationTimer?.cancel();
      _durationTimer = null;
    }
    notifyListeners();
  }

  /// When the server last confirmed an uploaded fix.
  DateTime? get lastUploadConfirmedAt => _locationService.lastUploadConfirmedAt;

  /// True when another phone took over this bus and tracking was stopped.
  bool get superseded => _locationService.superseded;

  /// Whether riders can currently see this bus: tracking, with an upload
  /// confirmed by the server recently.
  bool get ridersCanSee {
    final at = lastUploadConfirmedAt;
    return _isTracking &&
        at != null &&
        DateTime.now().difference(at).inSeconds <=
            AppConstants.uploadFreshSeconds;
  }

  /// Checks location is on and permitted before a trip is claimed.
  Future<void> ensureReady() => _locationService.ensureReady();

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// Whether active GPS broadcasting is in progress.
  bool get isTracking => _isTracking;

  /// The most recent valid [Position] received from GPS hardware.
  Position? get currentPosition => _currentPosition;

  /// Current instantaneous velocity in meters per second (m/s).
  double get speed => _speed;

  /// Current velocity converted to kilometers per hour (km/h).
  double get speedKmh => _speed * 3.6;

  /// Current GPS horizontal accuracy estimate in meters (lower is better).
  double get accuracy => _accuracy;

  /// Total count of valid, broadcasted GPS fixes in the current session.
  int get fixCount => _fixCount;

  /// Timestamp when the current tracking session was initiated.
  DateTime? get sessionStartTime => _sessionStartTime;

  /// Elapsed time duration since tracking began.
  Duration get sessionDuration => _sessionDuration;

  /// Formatted elapsed duration string in `HH:mm:ss` format.
  String get sessionDurationFormatted {
    final hours = _sessionDuration.inHours.toString().padLeft(2, '0');
    final minutes =
        (_sessionDuration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds =
        (_sessionDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Target bus identifier currently being tracked.
  String? get activeBusId => _activeBusId;

  /// Monotonically increasing session generation number.
  int? get sessionGeneration => _sessionGeneration;

  /// Timestamp of the latest accepted GPS fix.
  DateTime? get lastFixTime => _lastFixTime;

  /// Seconds elapsed since the last received GPS fix.
  int get secondsSinceLastFix {
    if (_lastFixTime == null) return -1;
    return DateTime.now().difference(_lastFixTime!).inSeconds;
  }

  // ---------------------------------------------------------------------------
  // Tracking Actions
  // ---------------------------------------------------------------------------

  /// Initiates foreground GPS tracking and RTDB broadcasting for [busId].
  Future<void> startTracking(String busId, int sessionGeneration) async {
    if (_isTracking &&
        _activeBusId == busId &&
        _sessionGeneration == sessionGeneration) {
      return;
    }

    _activeBusId = busId;
    _sessionGeneration = sessionGeneration;
    _fixCount = 0;
    _speed = 0.0;
    _accuracy = 0.0;
    _sessionStartTime = DateTime.now();
    _sessionDuration = Duration.zero;
    _lastFixTime = null;

    // Start elapsed duration ticker
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sessionStartTime != null) {
        _sessionDuration = DateTime.now().difference(_sessionStartTime!);
        notifyListeners();
      }
    });

    // Subscribe to position updates from LocationService
    await _positionSubscription?.cancel();
    _positionSubscription = _locationService.lastPosition.listen(_handleNewPosition);

    // Start the underlying LocationService
    await _locationService.startTracking(
      busId: busId,
      sessionGeneration: sessionGeneration,
    );

    _isTracking = true;
    notifyListeners();
  }

  /// Stops active GPS tracking and clears duration tickers.
  Future<void> stopTracking() async {
    _durationTimer?.cancel();
    _durationTimer = null;

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    await _locationService.stopTracking();

    _isTracking = false;
    _speed = 0.0;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  void _handleNewPosition(Position position) {
    _currentPosition = position;
    _speed = position.speed >= 0 ? position.speed : 0.0;
    _accuracy = position.accuracy;
    _lastFixTime = DateTime.now();
    _fixCount++;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationService.removeListener(_onServiceChanged);
    _durationTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
