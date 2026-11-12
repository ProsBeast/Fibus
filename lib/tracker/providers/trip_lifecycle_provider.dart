import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:fibus/core/constants/app_constants.dart';
import 'package:fibus/services/auth_service.dart';
import 'package:fibus/services/location_service.dart';
import 'package:fibus/services/realtime_db_service.dart';
import 'package:fibus/tracker/providers/tracking_provider.dart';

/// States in the tracker operator's trip lifecycle.
enum TripState { idle, starting, active, stopping, error }

/// Turns a failure while starting or ending a trip into a sentence the
/// operator can act on. Kept pure so it can be unit-tested.
String tripErrorMessage(Object error) {
  if (error is LocationSetupException) return error.message;
  if (error is TimeoutException) {
    return 'No connection. Check mobile data and try again';
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'This bus is being tracked from another phone, or you are not '
        'assigned to it';
  }
  return 'Could not start the trip. Try again';
}

/// State machine for a bus trip: claim the session in the Realtime Database
/// (the security rules decide who may), then run GPS via [TrackingProvider].
///
/// Order matters. Location is checked before anything is written, and a
/// start that fails after the claim is rolled back, so riders never see a
/// "tracking" bus that is not sending positions.
class TripLifecycleProvider extends ChangeNotifier {
  TripLifecycleProvider({
    RealtimeDbService? rtdbService,
    AuthService? authService,
    TrackingProvider? trackingProvider,
  }) : _rtdbService = rtdbService ?? RealtimeDbService(),
       _authService = authService ?? AuthService.instance,
       _trackingProvider = trackingProvider;

  final RealtimeDbService _rtdbService;
  final AuthService _authService;
  TrackingProvider? _trackingProvider;

  TripState _tripState = TripState.idle;
  String? _currentBusId;
  int _sessionGeneration = 0;
  String? _error;
  bool _isProcessing = false;
  DateTime? _lastStartedAt;
  Timer? _autoEndTimer;
  bool _autoEnded = false;

  TripState get tripState => _tripState;
  String? get currentBusId => _currentBusId;
  int get sessionGeneration => _sessionGeneration;
  String? get error => _error;
  bool get isProcessing => _isProcessing;
  bool get isActive => _tripState == TripState.active;
  DateTime? get lastStartedAt => _lastStartedAt;

  /// True when the last trip was ended automatically after
  /// [AppConstants.maxTripDuration].
  bool get autoEnded => _autoEnded;

  void updateTrackingProvider(TrackingProvider provider) {
    _trackingProvider = provider;
  }

  /// Starts (or resumes) tracking [busId] as a new session.
  Future<bool> startTrip(String busId) => _begin(busId);

  /// Takes over [busId] from a phone whose feed has gone quiet.
  Future<bool> takeoverTrip(String busId) => _begin(busId);

  Future<bool> _begin(String busId) async {
    if (_isProcessing) return false;
    _isProcessing = true;
    _error = null;
    _autoEnded = false;
    _tripState = TripState.starting;
    notifyListeners();

    var claimed = false;
    try {
      final user = _authService.currentUser;
      final tracker = _trackingProvider;
      if (user == null || tracker == null) {
        throw StateError('not signed in');
      }

      // 1. Location must work before anything is announced to riders.
      await tracker.ensureReady();
      await tracker.stopTracking();

      // 2. Claim a newer session. The database rules reject the claim when
      //    another phone is live or this operator is not assigned.
      final newGen =
          await _rtdbService
              .getSessionGeneration(busId)
              .timeout(AppConstants.saveTimeout) +
          1;
      await _rtdbService
          .createSession(
            busId: busId,
            operatorUid: user.uid,
            generation: newGen,
          )
          .timeout(AppConstants.saveTimeout);
      claimed = true;

      // 3. Start GPS.
      await tracker.startTracking(busId, newGen);

      _currentBusId = busId;
      _sessionGeneration = newGen;
      _lastStartedAt = DateTime.now();
      _tripState = TripState.active;
      _autoEndTimer?.cancel();
      _autoEndTimer = Timer(
        AppConstants.maxTripDuration,
        () => _autoEnd(busId),
      );
      return true;
    } catch (e) {
      debugPrint('TripLifecycleProvider: start failed: $e');
      if (e is TimeoutException) {
        // Do not let the queued claim turn into a ghost trip later.
        await _rtdbService.purgePendingWrites();
      } else if (claimed) {
        // GPS failed after the claim: tell riders the trip is not running.
        unawaited(_rtdbService.endSession(busId).catchError((_) {}));
      }
      _error = tripErrorMessage(e);
      _tripState = TripState.error;
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _autoEnd(String busId) async {
    if (_tripState != TripState.active || _currentBusId != busId) return;
    _autoEnded = true;
    await stopTrip(busId);
  }

  /// Ends the trip: stops GPS, then marks the session ended for riders.
  ///
  /// Always returns the phone to idle. Offline, the "ended" write stays
  /// queued and is delivered when the network returns.
  Future<bool> stopTrip(String busId) async {
    if (_isProcessing) return false;
    _isProcessing = true;
    _error = null;
    _tripState = TripState.stopping;
    notifyListeners();

    _autoEndTimer?.cancel();
    _autoEndTimer = null;
    final superseded = _trackingProvider?.superseded ?? false;
    try {
      await _trackingProvider?.stopTracking();
      // After a takeover the session belongs to the other phone; leave it.
      if (!superseded) {
        await _rtdbService.endSession(busId).timeout(AppConstants.saveTimeout);
      }
    } catch (e) {
      debugPrint('TripLifecycleProvider: end not confirmed yet: $e');
    } finally {
      _tripState = TripState.idle;
      _currentBusId = null;
      _isProcessing = false;
      notifyListeners();
    }
    return true;
  }

  /// Clears the last error.
  void clearError() {
    _error = null;
    if (_tripState == TripState.error) {
      _tripState = _currentBusId != null ? TripState.active : TripState.idle;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _autoEndTimer?.cancel();
    super.dispose();
  }
}
