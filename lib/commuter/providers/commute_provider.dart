import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:fibus/models/bus_model.dart';
import 'package:fibus/models/commute_preference.dart';
import 'package:fibus/models/live_bus.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/models/stop_model.dart';
import 'package:fibus/services/bus_eta_estimator.dart';
import 'package:fibus/services/firestore_service.dart';
import 'package:fibus/services/rtdb_service.dart';
import 'package:fibus/services/route_service.dart';

/// Provider managing the commuter's saved preferences, live bus stream subscription,
/// scooter travel estimation, and real-time departure countdown.
class CommuteProvider extends ChangeNotifier {
  CommuteProvider({
    FirestoreService? firestoreService,
    RtdbService? rtdbService,
    RouteService? routeService,
  })  : _firestore = firestoreService ?? FirestoreService.instance,
        _rtdb = rtdbService ?? RtdbService.instance,
        _routeService = routeService ?? RouteService.instance;

  final FirestoreService _firestore;
  final RtdbService _rtdb;
  final RouteService _routeService;

  CommutePreference? _currentPreference;
  RouteModel? _currentRoute;
  BusModel? _currentBus;
  StopModel? _currentStop;
  LiveBus? _liveBus;
  DepartureRecommendation? _departureRecommendation;
  List<StopModel> _routeStops = const [];
  BusEtaEstimator? _etaEstimator;
  BusEtaEstimate _etaEstimate = BusEtaEstimate.noTracker;

  bool _isLoading = false;
  String? _errorMessage;
  int _scooterDurationSeconds = 600; // 10 minutes fallback

  StreamSubscription<LiveBus?>? _liveBusSubscription;
  Timer? _countdownTicker;
  String? _activeUserId;

  // Getters
  CommutePreference? get currentPreference => _currentPreference;
  RouteModel? get currentRoute => _currentRoute;
  BusModel? get currentBus => _currentBus;
  StopModel? get currentStop => _currentStop;
  LiveBus? get liveBus => _liveBus;
  DepartureRecommendation? get departureRecommendation => _departureRecommendation;
  List<StopModel> get routeStops => _routeStops;

  /// Live ETA quality and prediction for the boarding stop.
  BusEtaEstimate get etaEstimate => _etaEstimate;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get scooterDurationSeconds => _scooterDurationSeconds;

  /// Effective bus ETA at the selected boarding stop (live prediction or scheduled fallback).
  DateTime? get busEta => _departureRecommendation?.busEta;

  /// Whether user has configured their home pin.
  bool get hasHomePin => _currentPreference?.hasHomePin ?? false;

  /// Whether user has selected a route, bus, and boarding stop.
  bool get isCommuteSelected =>
      _currentPreference != null && _currentPreference!.isFullyConfigured;

  /// Initializes the provider for the authenticated commuter UID.
  Future<void> initForUser(String uid) async {
    if (_activeUserId == uid && _currentPreference != null) return;
    _activeUserId = uid;
    await loadCommuteData();
  }

  /// Loads preference from Firestore, resolves route/bus/stop models, and starts streams.
  Future<void> loadCommuteData() async {
    if (_activeUserId == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentPreference = await _firestore.getCommutePreference(_activeUserId!);

      if (_currentPreference != null && _currentPreference!.isFullyConfigured) {
        await _resolveCommuteEntities(_currentPreference!);
        _subscribeToLiveBus(_currentPreference!.busId);
        await _estimateScooterTravelTime();
        _recomputeRecommendation();
      }

      _startTicker();
      _isLoading = false;
      notifyListeners();
    } catch (e, stack) {
      developer.log('Failed to load commute data', error: e, stackTrace: stack);
      _errorMessage = 'Could not load your commute preference.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Resolves the RouteModel, BusModel, and StopModel based on preference IDs.
  Future<void> _resolveCommuteEntities(CommutePreference pref) async {
    try {
      final routes = await _firestore.getActiveRoutes();
      _currentRoute = routes.firstWhere(
        (r) => r.id == pref.routeId,
        orElse: () => RouteModel(id: pref.routeId, name: pref.routeName),
      );

      final buses = await _firestore.getBusesForRoute(pref.routeId);
      _currentBus = buses.firstWhere(
        (b) => b.id == pref.busId,
        orElse: () => BusModel(id: pref.busId, displayName: pref.busName),
      );

      final stops = await _firestore.getStopsForRoute(_currentRoute!);
      _setRouteGeometry(_currentRoute!, stops);
      _currentStop = stops.firstWhere(
        (s) => s.id == pref.boardingStopId,
        orElse: () => StopModel(
          id: pref.boardingStopId,
          name: pref.boardingStopName,
          latitude: pref.homeLatitude,
          longitude: pref.homeLongitude,
        ),
      );
    } catch (e) {
      developer.log('Error resolving commute entities', error: e);
    }
  }

  /// Rebuilds the route-progress ETA model for [route] and its ordered stops.
  void _setRouteGeometry(RouteModel route, List<StopModel> stops) {
    _routeStops = stops;
    _etaEstimator = stops.isEmpty
        ? null
        : BusEtaEstimator(polyline: route.polylinePoints, orderedStops: stops);
    if (_liveBus != null) _etaEstimator?.ingest(_liveBus!);
  }

  /// Subscribes to live RTDB updates for the assigned bus.
  void _subscribeToLiveBus(String busId) {
    _liveBusSubscription?.cancel();

    _liveBusSubscription = _rtdb.streamLiveBus(busId).listen(
      (busUpdate) {
        _liveBus = busUpdate;
        if (busUpdate != null) _etaEstimator?.ingest(busUpdate);
        _recomputeRecommendation();
        notifyListeners();
      },
      onError: (err) {
        developer.log('RTDB live bus stream error', error: err);
      },
    );
  }

  /// Estimates scooter travel time between home coordinate and boarding stop.
  Future<void> _estimateScooterTravelTime() async {
    if (_currentPreference == null || _currentStop == null) return;
    if (!_currentPreference!.hasHomePin) return;

    final home = _currentPreference!.homeLocation;
    final stop = _currentStop!.location;

    try {
      final duration = await _routeService.estimateScooterDurationSeconds(home, stop);
      _scooterDurationSeconds = duration;
    } catch (e) {
      developer.log('Scooter travel estimation error', error: e);
    }
  }

  /// Recomputes departure recommendation using live ETA or timetable fallback.
  ///
  /// The live ETA comes from the bus's progress along the route polyline
  /// ([BusEtaEstimator]); whenever it is not trustworthy (warming up, stale,
  /// off route, no tracker) the published timetable is used instead (FR-27).
  void _recomputeRecommendation() {
    if (_currentPreference == null) return;

    final now = DateTime.now();
    DateTime? scheduledArrival;
    if (_currentStop != null) {
      scheduledArrival = _parseTodayScheduleTime(_currentStop!.scheduledArrivalLocalTime);
    }

    _etaEstimate = _currentStop == null
        ? BusEtaEstimate.noTracker
        : (_etaEstimator?.estimate(_liveBus, _currentStop!.id, now) ??
            BusEtaEstimate.noTracker);

    final effectiveEta = _etaEstimate.eta ??
        scheduledArrival ??
        now.add(const Duration(minutes: 30));

    _departureRecommendation = _routeService.computeDeparture(
      busEta: effectiveEta,
      scooterDurationSeconds: _scooterDurationSeconds,
      scheduledArrival: scheduledArrival,
    );
  }

  /// Converts a timetable string (e.g. '07:50') to a DateTime for today.
  DateTime _parseTodayScheduleTime(String timeString) {
    final now = DateTime.now();
    try {
      final parts = timeString.split(':');
      final hour = int.parse(parts[0].trim());
      final minute = int.parse(parts[1].trim());
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return DateTime(now.year, now.month, now.day, 7, 50);
    }
  }

  /// Timer ticking every second to refresh UI countdown smoothly.
  void _startTicker() {
    _countdownTicker?.cancel();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_departureRecommendation != null) {
        // Re-evaluate so live -> stale transitions happen without new data.
        _recomputeRecommendation();
        notifyListeners();
      }
    });
  }

  /// Saves or updates the commuter's home pin location.
  Future<void> updateHomeLocation(double latitude, double longitude) async {
    if (_activeUserId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _firestore.saveHomePin(_activeUserId!, latitude, longitude);

      if (_currentPreference != null) {
        _currentPreference = _currentPreference!.copyWith(
          homeLatitude: latitude,
          homeLongitude: longitude,
        );
      } else {
        _currentPreference = CommutePreference(
          id: 'primary',
          userId: _activeUserId!,
          homeLatitude: latitude,
          homeLongitude: longitude,
          busId: '',
          routeId: '',
          boardingStopId: '',
        );
      }

      await _estimateScooterTravelTime();
      _recomputeRecommendation();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to save home location.';
      notifyListeners();
      rethrow;
    }
  }

  /// Saves the full commute preference after choosing route, bus, and stop.
  Future<void> saveCommutePreference({
    required RouteModel route,
    required BusModel bus,
    required StopModel stop,
    required int advanceWarningMinutes,
  }) async {
    if (_activeUserId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final pref = CommutePreference(
        id: 'primary',
        userId: _activeUserId!,
        homeLatitude: _currentPreference?.homeLatitude ?? 0.0,
        homeLongitude: _currentPreference?.homeLongitude ?? 0.0,
        busId: bus.id,
        busName: bus.displayName,
        routeId: route.id,
        routeName: route.name,
        boardingStopId: stop.id,
        boardingStopName: stop.name,
        advanceWarningMinutes: advanceWarningMinutes,
        isEnabled: true,
      );

      await _firestore.saveCommutePreference(pref);
      _currentPreference = pref;
      _currentRoute = route;
      _currentBus = bus;
      _currentStop = stop;
      _setRouteGeometry(route, await _firestore.getStopsForRoute(route));

      _subscribeToLiveBus(bus.id);
      await _estimateScooterTravelTime();
      _recomputeRecommendation();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to save commute selection.';
      notifyListeners();
      rethrow;
    }
  }

  /// Updates advance warning time lead.
  Future<void> updateAdvanceWarningMinutes(int minutes) async {
    if (_currentPreference == null || _activeUserId == null) return;

    final updated = _currentPreference!.copyWith(advanceWarningMinutes: minutes);
    try {
      await _firestore.saveCommutePreference(updated);
      _currentPreference = updated;
      notifyListeners();
    } catch (e) {
      developer.log('Failed to update advance warning minutes', error: e);
    }
  }

  /// Refreshes all commute data.
  Future<void> refresh() async {
    await loadCommuteData();
  }

  @override
  void dispose() {
    _liveBusSubscription?.cancel();
    _countdownTicker?.cancel();
    super.dispose();
  }
}
