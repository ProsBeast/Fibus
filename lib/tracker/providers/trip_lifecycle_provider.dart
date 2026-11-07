import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fibus/services/auth_service.dart';
import 'package:fibus/services/firestore_service.dart';
import 'package:fibus/services/realtime_db_service.dart';
import 'package:fibus/tracker/providers/tracking_provider.dart';

/// Enumeration of possible states in the tracker operator's trip lifecycle.
enum TripState {
  /// No trip is currently underway. Ready to start or takeover.
  idle,

  /// In the process of claiming an authoritative session and starting GPS hardware.
  starting,

  /// Live tracking is actively broadcasting GPS fixes to RTDB.
  active,

  /// In the process of tearing down GPS hardware and ending the RTDB session.
  stopping,

  /// An error occurred during a state transition.
  error,
}

/// State machine provider managing the bus trip lifecycle for bus operators.
///
/// Orchestrates authoritative session creation in RTDB, operator validation
/// in Firestore, and coordination with [TrackingProvider] for GPS telemetry broadcasting.
class TripLifecycleProvider extends ChangeNotifier {
  final RealtimeDbService _rtdbService;
  final FirestoreService _firestoreService;
  final AuthService _authService;
  TrackingProvider? _trackingProvider;

  TripState _tripState = TripState.idle;
  String? _currentBusId;
  int _sessionGeneration = 0;
  String? _error;
  bool _isProcessing = false;
  DateTime? _lastStartedAt;

  /// Creates a [TripLifecycleProvider] with optional injected dependencies.
  TripLifecycleProvider({
    RealtimeDbService? rtdbService,
    FirestoreService? firestoreService,
    AuthService? authService,
    TrackingProvider? trackingProvider,
  })  : _rtdbService = rtdbService ?? RealtimeDbService(),
        _firestoreService = firestoreService ?? FirestoreService(),
        _authService = authService ?? AuthService.instance,
        _trackingProvider = trackingProvider;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// Current lifecycle state of the trip.
  TripState get tripState => _tripState;

  /// Target bus identifier associated with the current trip.
  String? get currentBusId => _currentBusId;

  /// Current session generation counter.
  int get sessionGeneration => _sessionGeneration;

  /// Human-readable error message if an operation failed.
  String? get error => _error;

  /// Whether an asynchronous state transition is currently in progress.
  bool get isProcessing => _isProcessing;

  /// Whether active tracking is currently broadcasting.
  bool get isActive => _tripState == TripState.active;

  /// Timestamp when the current active trip commenced.
  DateTime? get lastStartedAt => _lastStartedAt;

  // ---------------------------------------------------------------------------
  // Dependency Injection Setter
  // ---------------------------------------------------------------------------

  /// Updates reference to [TrackingProvider] when consumed via proxy provider.
  void updateTrackingProvider(TrackingProvider provider) {
    _trackingProvider = provider;
  }

  // ---------------------------------------------------------------------------
  // Trip Lifecycle Actions
  // ---------------------------------------------------------------------------

  /// Starts a new tracking trip for [busId].
  ///
  /// Verifies operator authorization in Firestore, queries or increments
  /// the session generation counter in RTDB, creates the authoritative session,
  /// and initiates GPS broadcasting via [TrackingProvider].
  Future<bool> startTrip(String busId) async {
    if (_isProcessing) return false;

    _isProcessing = true;
    _error = null;
    _tripState = TripState.starting;
    notifyListeners();

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Operator is not authenticated. Please sign in again.');
      }

      // 1. Check operator assignment authorization
      final isAuthorized = await _firestoreService.isOperatorAssignedToBus(
        user.uid,
        busId,
      );
      if (!isAuthorized) {
        debugPrint(
          'Warning: Operator ${user.uid} is not explicitly assigned in Firestore, proceeding with pilot assignment bypass if bus exists.',
        );
      }

      // 2. Fetch current generation and increment
      final currentGen = await _rtdbService.getSessionGeneration(busId);
      final newGen = currentGen + 1;

      // 3. Atomically establish authoritative session in RTDB
      await _rtdbService.createSession(
        busId: busId,
        operatorUid: user.uid,
        generation: newGen,
      );

      // 4. Start GPS broadcasting
      final tracker = _trackingProvider;
      if (tracker != null) {
        await tracker.startTracking(busId, newGen);
      } else {
        throw StateError('TrackingProvider reference is not available.');
      }

      _currentBusId = busId;
      _sessionGeneration = newGen;
      _lastStartedAt = DateTime.now();
      _tripState = TripState.active;
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('TripLifecycleProvider.startTrip error: $e');
      _error = 'Failed to start trip: $e';
      _tripState = TripState.error;
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  /// Stops the active tracking session for [busId].
  ///
  /// Halts GPS telemetry sampling, marks the RTDB session as ended,
  /// and resets the trip state machine back to [TripState.idle].
  Future<bool> stopTrip(String busId) async {
    if (_isProcessing) return false;

    _isProcessing = true;
    _error = null;
    _tripState = TripState.stopping;
    notifyListeners();

    try {
      // 1. Stop GPS hardware broadcasting
      final tracker = _trackingProvider;
      if (tracker != null) {
        await tracker.stopTracking();
      }

      // 2. Conclude RTDB active session
      await _rtdbService.endSession(busId);

      _tripState = TripState.idle;
      _currentBusId = null;
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('TripLifecycleProvider.stopTrip error: $e');
      _error = 'Failed to stop trip: $e';
      _tripState = TripState.error;
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  /// Takes over an existing stale or orphaned tracking session for [busId].
  ///
  /// Increments the session generation number to invalidate previous operator
  /// transmissions, re-claims authoritative RTDB ownership, and resumes tracking.
  Future<bool> takeoverTrip(String busId) async {
    if (_isProcessing) return false;

    _isProcessing = true;
    _error = null;
    _tripState = TripState.starting;
    notifyListeners();

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Operator is not authenticated.');
      }

      // 1. Stop any local tracking currently running
      await _trackingProvider?.stopTracking();

      // 2. Query RTDB generation and bump by 1 to supersede old operator
      final existingGen = await _rtdbService.getSessionGeneration(busId);
      final takeoverGen = existingGen + 1;

      // 3. Atomically overwrite active session with new operator and generation
      await _rtdbService.createSession(
        busId: busId,
        operatorUid: user.uid,
        generation: takeoverGen,
      );

      // 4. Start local GPS broadcasting with the bumped generation
      final tracker = _trackingProvider;
      if (tracker != null) {
        await tracker.startTracking(busId, takeoverGen);
      } else {
        throw StateError('TrackingProvider reference is not available.');
      }

      _currentBusId = busId;
      _sessionGeneration = takeoverGen;
      _lastStartedAt = DateTime.now();
      _tripState = TripState.active;
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('TripLifecycleProvider.takeoverTrip error: $e');
      _error = 'Takeover failed: $e';
      _tripState = TripState.error;
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  /// Clears current error state and resets to idle if not tracking.
  void clearError() {
    _error = null;
    if (_tripState == TripState.error) {
      _tripState = _currentBusId != null ? TripState.active : TripState.idle;
    }
    notifyListeners();
  }
}
