import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:fibus/core/constants/app_constants.dart';

/// Computed recommendation output containing departure milestones.
class DepartureRecommendation {
  const DepartureRecommendation({
    required this.busEta,
    required this.targetStopArrival,
    required this.recommendedLeaveBy,
    required this.scooterDurationSeconds,
    required this.safetyMarginSeconds,
    required this.isDelaySignificant,
    required this.delayMinutes,
  });

  /// Predicted arrival time of the bus at the commuter's boarding stop.
  final DateTime busEta;

  /// Target arrival time at the stop (busEta - 5 minutes boarding buffer).
  final DateTime targetStopArrival;

  /// Time the commuter should leave home.
  final DateTime recommendedLeaveBy;

  /// Estimated scooter travel time in seconds.
  final int scooterDurationSeconds;

  /// Dynamic uncertainty safety margin in seconds.
  final int safetyMarginSeconds;

  /// Whether bus is delayed by 5+ minutes.
  final bool isDelaySignificant;

  /// Bus delay in minutes compared to scheduled timetable.
  final int delayMinutes;

  /// Whether current clock time has reached or passed recommended leave time.
  bool get isLeaveNow => DateTime.now().isAfter(recommendedLeaveBy);

  /// Remaining seconds until recommended leave time (negative if past).
  int get secondsUntilLeave =>
      recommendedLeaveBy.difference(DateTime.now()).inSeconds;

  /// Remaining minutes formatted for display.
  int get minutesUntilLeave =>
      (recommendedLeaveBy.difference(DateTime.now()).inSeconds / 60).ceil();
}

/// Service providing scooter travel estimation and departure recommendation calculations.
class RouteService {
  RouteService._internal();
  static final RouteService instance = RouteService._internal();
  factory RouteService() => instance;

  final http.Client _client = http.Client();

  /// Estimates two-wheeler / scooter travel duration in seconds between two points.
  /// Attempts OSRM routing API with haversine fallback on error or timeout.
  Future<int> estimateScooterDurationSeconds(LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=false',
      );

      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final duration = (routes.first['duration'] as num).toDouble();
          // Adjust driving duration to scooter speed with urban traffic penalty (1.1x)
          return (duration * 1.1).round();
        }
      }
    } catch (e) {
      developer.log(
        'OSRM routing request failed, falling back to calculation',
        error: e,
      );
    }

    // Fallback calculation: Haversine distance with average urban scooter speed (25 km/h = 6.94 m/s)
    return _calculateFallbackDuration(from, to);
  }

  /// Calculates straight-line distance based duration assuming 25 km/h urban speed.
  int _calculateFallbackDuration(LatLng from, LatLng to) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _deg2rad(to.latitude - from.latitude);
    final dLon = _deg2rad(to.longitude - from.longitude);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(from.latitude)) *
            cos(_deg2rad(to.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final straightDistanceMeters = earthRadiusMeters * c;

    // Road factor 1.35 accounts for urban road detours
    final roadDistanceMeters = straightDistanceMeters * 1.35;
    const averageSpeedMetersPerSec = 25.0 * 1000.0 / 3600.0; // 6.94 m/s

    final durationSeconds = (roadDistanceMeters / averageSpeedMetersPerSec)
        .round();
    return max(180, durationSeconds); // minimum 3 minutes
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);

  /// Computes the official Fibus departure recommendation based on:
  /// - `busEta`
  /// - `boardingBuffer`: 5 minutes
  /// - `scooterDuration`
  /// - `safetyMargin`: 2 min base + uncertainty premium
  DepartureRecommendation computeDeparture({
    required DateTime busEta,
    required int scooterDurationSeconds,
    DateTime? scheduledArrival,
  }) {
    // 1. Boarding buffer: 5 minutes
    final targetStopArrival = busEta.subtract(AppConstants.boardingBuffer);

    // 2. Dynamic Safety Margin: 2 min base + dynamic uncertainty
    const baseMarginSeconds = 120; // 2 minutes
    final dynamicUncertaintySeconds = min(
      300,
      (scooterDurationSeconds * 0.15).round(),
    ); // max 5 mins
    final safetyMarginSeconds = baseMarginSeconds + dynamicUncertaintySeconds;

    // 3. Recommended Leave By = targetArrival - scooterDuration - safetyMargin
    final totalOffsetSeconds = scooterDurationSeconds + safetyMarginSeconds;
    final recommendedLeaveBy = targetStopArrival.subtract(
      Duration(seconds: totalOffsetSeconds),
    );

    // 4. Delay calculations
    int delayMinutes = 0;
    bool isDelaySignificant = false;
    if (scheduledArrival != null) {
      delayMinutes = busEta.difference(scheduledArrival).inMinutes;
      isDelaySignificant = delayMinutes >= 5;
    }

    return DepartureRecommendation(
      busEta: busEta,
      targetStopArrival: targetStopArrival,
      recommendedLeaveBy: recommendedLeaveBy,
      scooterDurationSeconds: scooterDurationSeconds,
      safetyMarginSeconds: safetyMarginSeconds,
      isDelaySignificant: isDelaySignificant,
      delayMinutes: delayMinutes,
    );
  }
}
