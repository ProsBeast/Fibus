import 'package:latlong2/latlong.dart';
import 'package:fibus/core/constants/app_constants.dart';

/// Realtime Database model for live telemetry, location fixes, and ETA calculation
/// of an active bus under `/liveBuses/{busId}`.
class LiveBus {
  const LiveBus({
    required this.busId,
    this.status = 'not_started',
    this.activeTripId = '',
    this.sessionGeneration = 0,
    this.trackerUid = '',
    this.startedAtServer,
    this.lastLocationAtServer,
    this.lastHeartbeatAtServer,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.accuracyM,
    this.speedMps,
    this.headingDeg,
    this.deviceTimestamp,
    this.serverTimestamp,
    this.stopEtas = const {},
    this.confidenceLabel = 'unavailable',
    this.sourceStatus = 'schedule_fallback',
    this.delayMinutes = 0,
  });

  final String busId;
  final String status; // 'not_started', 'active', 'stale', 'ended'
  final String activeTripId;
  final int sessionGeneration;
  final String trackerUid;
  final int? startedAtServer;
  final int? lastLocationAtServer;
  final int? lastHeartbeatAtServer;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final double? speedMps;
  final double? headingDeg;
  final int? deviceTimestamp;
  final int? serverTimestamp;

  /// Map of stopId -> remaining seconds until arrival, or unix seconds.
  final Map<String, int> stopEtas;
  final String
  confidenceLabel; // 'high', 'medium', 'low', 'warming_up', 'unavailable'
  final String sourceStatus; // 'live_gps', 'schedule_fallback', 'stale'
  final int delayMinutes;

  /// Returns geographic coordinate as LatLng.
  LatLng get location => LatLng(latitude, longitude);

  /// Checks if location coordinates are valid.
  bool get hasValidLocation => latitude != 0.0 && longitude != 0.0;

  /// Computed check whether the feed is live and fresh (< 60s old).
  bool get isLive {
    if (status != 'active') return false;
    if (lastLocationAtServer == null) return false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final ageMs = nowMs - lastLocationAtServer!;
    return ageMs <= AppConstants.staleThresholdSeconds * 1000;
  }

  /// Computed check whether the feed is stale (active but no update > 60s).
  bool get isStale {
    if (status == 'stale') return true;
    if (status == 'active' && lastLocationAtServer != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final ageMs = nowMs - lastLocationAtServer!;
      return ageMs > AppConstants.staleThresholdSeconds * 1000;
    }
    return false;
  }

  /// Computed check whether the feed is offline or not tracking.
  bool get isOffline => !isLive && !isStale;

  /// Duration since the last received GPS fix.
  Duration? get ageSinceLastUpdate {
    if (lastLocationAtServer == null) return null;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return Duration(milliseconds: nowMs - lastLocationAtServer!);
  }

  /// Creates a [LiveBus] instance from an RTDB map.
  factory LiveBus.fromRtdb(String busId, Map<dynamic, dynamic>? data) {
    if (data == null) {
      return LiveBus(busId: busId);
    }

    final latestLoc = (data['latestLocation'] is Map)
        ? data['latestLocation'] as Map
        : null;

    final busEtaMap = (data['busEta'] is Map) ? data['busEta'] as Map : null;

    final stopEtasParsed = <String, int>{};
    if (busEtaMap != null) {
      busEtaMap.forEach((key, value) {
        if (value is num) {
          stopEtasParsed[key.toString()] = value.toInt();
        }
      });
    }

    // The Tracker app (RealtimeDbService.publishLocation) writes a flat node:
    // status 'tracking', lastServerHeartbeat, accuracy, speed, heading and
    // operatorUid. Map those onto this model alongside the PRD field names.
    final rawStatus = (data['status'] as String?) ?? 'not_started';
    final lastFixAtServer =
        (data['lastLocationAtServer'] as num?)?.toInt() ??
        (data['lastServerHeartbeat'] as num?)?.toInt();

    return LiveBus(
      busId: busId,
      status: rawStatus == 'tracking' ? 'active' : rawStatus,
      activeTripId: (data['activeTripId'] as String?) ?? '',
      sessionGeneration: (data['sessionGeneration'] as num?)?.toInt() ?? 0,
      trackerUid:
          (data['trackerUid'] as String?) ??
          (data['operatorUid'] as String?) ??
          '',
      startedAtServer: (data['startedAtServer'] as num?)?.toInt(),
      lastLocationAtServer: lastFixAtServer,
      lastHeartbeatAtServer:
          (data['lastHeartbeatAtServer'] as num?)?.toInt() ?? lastFixAtServer,
      latitude: latestLoc != null
          ? (latestLoc['lat'] as num?)?.toDouble() ?? 0.0
          : (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: latestLoc != null
          ? (latestLoc['lng'] as num?)?.toDouble() ?? 0.0
          : (data['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracyM: latestLoc != null
          ? (latestLoc['accuracyM'] as num?)?.toDouble()
          : (data['accuracyM'] as num?)?.toDouble() ??
                (data['accuracy'] as num?)?.toDouble(),
      speedMps: latestLoc != null
          ? (latestLoc['speedMps'] as num?)?.toDouble()
          : (data['speedMps'] as num?)?.toDouble() ??
                (data['speed'] as num?)?.toDouble(),
      headingDeg: latestLoc != null
          ? (latestLoc['headingDeg'] as num?)?.toDouble()
          : (data['headingDeg'] as num?)?.toDouble() ??
                (data['heading'] as num?)?.toDouble(),
      deviceTimestamp: latestLoc != null
          ? (latestLoc['deviceTimestamp'] as num?)?.toInt()
          : null,
      serverTimestamp: latestLoc != null
          ? (latestLoc['serverTimestamp'] as num?)?.toInt()
          : null,
      stopEtas: stopEtasParsed,
      confidenceLabel: busEtaMap != null
          ? (busEtaMap['confidenceLabel'] as String?) ?? 'unavailable'
          : 'unavailable',
      sourceStatus: busEtaMap != null
          ? (busEtaMap['sourceStatus'] as String?) ?? 'schedule_fallback'
          : 'schedule_fallback',
      delayMinutes: busEtaMap != null
          ? (busEtaMap['delayMinutes'] as num?)?.toInt() ?? 0
          : 0,
    );
  }

  /// Converts this instance to an RTDB-compatible map.
  Map<String, dynamic> toRtdb() {
    return {
      'status': status,
      'activeTripId': activeTripId,
      'sessionGeneration': sessionGeneration,
      'trackerUid': trackerUid,
      'startedAtServer': startedAtServer,
      'lastLocationAtServer': lastLocationAtServer,
      'lastHeartbeatAtServer': lastHeartbeatAtServer,
      'latestLocation': {
        'lat': latitude,
        'lng': longitude,
        'accuracyM': accuracyM,
        'speedMps': speedMps,
        'headingDeg': headingDeg,
        'deviceTimestamp': deviceTimestamp,
        'serverTimestamp': serverTimestamp,
      },
      'busEta': {
        ...stopEtas,
        'confidenceLabel': confidenceLabel,
        'sourceStatus': sourceStatus,
        'delayMinutes': delayMinutes,
      },
    };
  }

  LiveBus copyWith({
    String? busId,
    String? status,
    String? activeTripId,
    int? sessionGeneration,
    String? trackerUid,
    int? startedAtServer,
    int? lastLocationAtServer,
    int? lastHeartbeatAtServer,
    double? latitude,
    double? longitude,
    double? accuracyM,
    double? speedMps,
    double? headingDeg,
    int? deviceTimestamp,
    int? serverTimestamp,
    Map<String, int>? stopEtas,
    String? confidenceLabel,
    String? sourceStatus,
    int? delayMinutes,
  }) {
    return LiveBus(
      busId: busId ?? this.busId,
      status: status ?? this.status,
      activeTripId: activeTripId ?? this.activeTripId,
      sessionGeneration: sessionGeneration ?? this.sessionGeneration,
      trackerUid: trackerUid ?? this.trackerUid,
      startedAtServer: startedAtServer ?? this.startedAtServer,
      lastLocationAtServer: lastLocationAtServer ?? this.lastLocationAtServer,
      lastHeartbeatAtServer:
          lastHeartbeatAtServer ?? this.lastHeartbeatAtServer,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyM: accuracyM ?? this.accuracyM,
      speedMps: speedMps ?? this.speedMps,
      headingDeg: headingDeg ?? this.headingDeg,
      deviceTimestamp: deviceTimestamp ?? this.deviceTimestamp,
      serverTimestamp: serverTimestamp ?? this.serverTimestamp,
      stopEtas: stopEtas ?? this.stopEtas,
      confidenceLabel: confidenceLabel ?? this.confidenceLabel,
      sourceStatus: sourceStatus ?? this.sourceStatus,
      delayMinutes: delayMinutes ?? this.delayMinutes,
    );
  }
}
