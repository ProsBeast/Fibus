import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:fibus/core/constants/app_constants.dart';
import 'package:fibus/core/utils/geo_utils.dart';
import 'package:fibus/models/live_bus.dart';
import 'package:fibus/models/stop_model.dart';

/// Quality of the live ETA, mirroring the PRD's status labels (FR-19).
enum LiveEtaStatus {
  /// No tracker has started this bus (or the trip ended): schedule only.
  noTracker,

  /// Tracking started but too few accepted fixes to trust progress yet.
  warmingUp,

  /// Fresh, route-matched fixes: [BusEtaEstimate.eta] is a live prediction.
  live,

  /// No fresh fix for the stale threshold (60 s): schedule fallback.
  stale,

  /// The latest fix is too far from the approved route polyline.
  offRoute,

  /// The bus is already past the commuter's boarding stop.
  passedStop,
}

/// Result of one ETA evaluation for the commuter's boarding stop.
class BusEtaEstimate {
  const BusEtaEstimate({
    required this.status,
    this.eta,
    this.remainingMeters,
    this.lastFixAt,
    this.speedMps,
  });

  final LiveEtaStatus status;

  /// Predicted arrival at the boarding stop. Only set when [status] is live.
  final DateTime? eta;

  /// Distance along the route from the bus to the stop.
  final double? remainingMeters;

  /// Server time of the latest accepted GPS fix.
  final DateTime? lastFixAt;

  /// Smoothed observed progress speed along the route, when known.
  final double? speedMps;

  bool get isLive => status == LiveEtaStatus.live;

  static const noTracker = BusEtaEstimate(status: LiveEtaStatus.noTracker);
}

class _Fix {
  const _Fix(this.atMs, this.along);
  final int atMs;
  final double along;
}

/// Rule-based bus ETA along the approved route polyline (PRD §9.2–9.3).
///
/// Each accepted fix is projected onto the polyline to get route progress
/// (metres from the start). Remaining time to the boarding stop blends two
/// estimates:
///  * a timetable prior — the scheduled time between the bus's current
///    progress and the stop, interpolated between stops by distance, and
///  * observed progress speed over the last ~3 minutes of fixes.
/// The observed pace (progress versus timetable) is applied to the prior.
/// The observed share grows with how much recent history exists, capped at
/// 50 %, and is clamped so a bus waiting at a signal cannot blow the ETA up.
class BusEtaEstimator {
  BusEtaEstimator({
    required List<LatLng> polyline,
    required List<StopModel> orderedStops,
    this.offRouteMeters = 250,
    this.passedStopToleranceMeters = 75,
    this.minFixesForLive = 3,
    this.smoothingWindow = AppConstants.smoothingWindow,
  })  : _polyline = polyline.length >= 2
            ? polyline
            : orderedStops.map((s) => s.location).toList(),
        _stops = orderedStops {
    _cumulative = [0];
    for (var i = 1; i < _polyline.length; i++) {
      _cumulative.add(_cumulative[i - 1] +
          GeoUtils.haversineDistance(_polyline[i - 1], _polyline[i]));
    }
    // Stop progress must be non-decreasing in stop order.
    var last = 0.0;
    for (final stop in _stops) {
      final along = _project(stop.location).distanceAlongPolylineMeters;
      last = math.max(last, along);
      _stopAlong.add(last);
      _stopMinutes.add(_parseMinutes(stop.scheduledArrivalLocalTime));
    }
  }

  final List<LatLng> _polyline;
  final List<StopModel> _stops;
  late final List<double> _cumulative;
  final List<double> _stopAlong = [];
  final List<int?> _stopMinutes = [];

  final double offRouteMeters;
  final double passedStopToleranceMeters;
  final int minFixesForLive;
  final Duration smoothingWindow;

  final List<_Fix> _fixes = [];
  int _sessionGeneration = -1;
  double _lastOffsetMeters = 0;

  /// Default bus speed for route sections without timetable data (≈22 km/h).
  static const double _fallbackSpeedMps = 6.0;

  /// Faster than this between fixes is treated as a GPS spike (≈110 km/h).
  static const double _maxPlausibleSpeedMps = 30.0;

  /// Backwards movement smaller than this is jitter and is ignored.
  static const double _backwardsToleranceMeters = 100.0;

  double get routeLengthMeters => _cumulative.last;

  /// Progress (metres along the route) of the stop with [stopId].
  double? stopProgress(String stopId) {
    final i = _stops.indexWhere((s) => s.id == stopId);
    return i < 0 ? null : _stopAlong[i];
  }

  /// Feeds a new RTDB snapshot. Duplicate or older fixes are ignored, and a
  /// new tracker session generation resets the history.
  void ingest(LiveBus bus) {
    if (bus.sessionGeneration != _sessionGeneration) {
      _fixes.clear();
      _sessionGeneration = bus.sessionGeneration;
    }
    final atMs = bus.lastLocationAtServer;
    if (atMs == null || !bus.hasValidLocation || bus.status != 'active') return;
    if (_fixes.isNotEmpty && atMs <= _fixes.last.atMs) return;

    final accuracy = bus.accuracyM;
    if (accuracy != null && accuracy > AppConstants.maxEtaFixAccuracyMeters) {
      return;
    }

    final projection = _project(bus.location);
    _lastOffsetMeters = projection.distanceMeters;
    var along = projection.distanceAlongPolylineMeters;

    if (_fixes.isNotEmpty) {
      final prev = _fixes.last;
      final dtSec = (atMs - prev.atMs) / 1000.0;
      final delta = along - prev.along;
      if (delta > 0 && dtSec > 0 && delta / dtSec > _maxPlausibleSpeedMps &&
          delta > 500) {
        return; // single-point spike
      }
      if (delta < 0 && -delta < _backwardsToleranceMeters) {
        along = prev.along; // jitter: never move backwards
      }
    }

    _fixes.add(_Fix(atMs, along));
    final cutoff = atMs - smoothingWindow.inMilliseconds;
    while (_fixes.length > 2 && _fixes.first.atMs < cutoff) {
      _fixes.removeAt(0);
    }
  }

  /// Evaluates the ETA to [stopId] at time [now], given the latest [bus].
  BusEtaEstimate estimate(LiveBus? bus, String stopId, DateTime now) {
    if (bus == null || bus.status == 'ended' || bus.status == 'not_started') {
      return BusEtaEstimate.noTracker;
    }
    final lastFixAt = bus.lastLocationAtServer == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(bus.lastLocationAtServer!);
    if (bus.status == 'stale' ||
        lastFixAt == null ||
        now.difference(lastFixAt).inSeconds > AppConstants.staleThresholdSeconds) {
      return BusEtaEstimate(status: LiveEtaStatus.stale, lastFixAt: lastFixAt);
    }

    final stopIndex = _stops.indexWhere((s) => s.id == stopId);
    if (stopIndex < 0 || _fixes.isEmpty) {
      return BusEtaEstimate(status: LiveEtaStatus.warmingUp, lastFixAt: lastFixAt);
    }

    final latest = _fixes.last;
    final stopAlong = _stopAlong[stopIndex];
    final remaining = stopAlong - latest.along;

    if (remaining < -passedStopToleranceMeters) {
      return BusEtaEstimate(
        status: LiveEtaStatus.passedStop,
        remainingMeters: remaining,
        lastFixAt: lastFixAt,
      );
    }
    if (_lastOffsetMeters > offRouteMeters) {
      return BusEtaEstimate(status: LiveEtaStatus.offRoute, lastFixAt: lastFixAt);
    }
    if (_fixes.length < minFixesForLive) {
      return BusEtaEstimate(
        status: LiveEtaStatus.warmingUp,
        remainingMeters: math.max(0, remaining),
        lastFixAt: lastFixAt,
      );
    }

    final remainingMeters = math.max(0.0, remaining);
    final priorSec = _scheduledSecondsBetween(latest.along, stopAlong);

    double? observedSpeed;
    final first = _fixes.first;
    final spanSec = (latest.atMs - first.atMs) / 1000.0;
    if (spanSec >= 30) {
      observedSpeed = (latest.along - first.along) / spanSec;
    }

    var remainingSec = priorSec;
    if (observedSpeed != null && priorSec > 0) {
      // Pace = timetable seconds covered per real second over the window
      // (1 = on schedule, 2 = twice as fast). Comparing against the timetable
      // over the same stretch keeps slow and fast road sections comparable.
      final scheduledCovered =
          _scheduledSecondsBetween(first.along, latest.along);
      final pace = scheduledCovered / spanSec;
      final observedSec = pace <= 0.01
          ? priorSec * 2.0
          : (priorSec / pace).clamp(priorSec * 0.5, priorSec * 2.0);
      final weight = 0.5 * math.min(1.0, spanSec / smoothingWindow.inSeconds);
      remainingSec = weight * observedSec + (1 - weight) * priorSec;
    }

    final fixTime = DateTime.fromMillisecondsSinceEpoch(latest.atMs);
    return BusEtaEstimate(
      status: LiveEtaStatus.live,
      eta: fixTime.add(Duration(seconds: remainingSec.round())),
      remainingMeters: remainingMeters,
      lastFixAt: lastFixAt,
      speedMps: observedSpeed,
    );
  }

  /// Timetable time (seconds) to travel from progress [from] to [to].
  double _scheduledSecondsBetween(double from, double to) {
    if (to <= from) return 0;
    return math.max(0, _scheduledSecondsAt(to) - _scheduledSecondsAt(from));
  }

  /// Timetable "clock" at a route progress, in seconds since the first stop,
  /// interpolated linearly by distance between consecutive timed stops.
  /// Sections without usable times fall back to [_fallbackSpeedMps].
  double _scheduledSecondsAt(double along) {
    if (_stops.isEmpty) return along / _fallbackSpeedMps;
    final base = _stopMinutes.first;
    if (along <= _stopAlong.first || base == null) {
      return (along - _stopAlong.first) / _fallbackSpeedMps;
    }
    double clockAt(int i) {
      final m = _stopMinutes[i];
      if (m != null) return (m - base) * 60.0;
      return (_stopAlong[i] - _stopAlong.first) / _fallbackSpeedMps;
    }

    for (var i = 1; i < _stops.length; i++) {
      if (along <= _stopAlong[i]) {
        final a = _stopAlong[i - 1];
        final b = _stopAlong[i];
        final ta = clockAt(i - 1);
        final tb = clockAt(i);
        if (b - a < 1) return tb;
        return ta + (tb - ta) * (along - a) / (b - a);
      }
    }
    final lastIndex = _stops.length - 1;
    return clockAt(lastIndex) + (along - _stopAlong[lastIndex]) / _fallbackSpeedMps;
  }

  PolylineProjectionResult _project(LatLng p) =>
      GeoUtils.projectPointToPolyline(p, _polyline);

  static int? _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}
