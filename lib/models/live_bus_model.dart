import 'package:latlong2/latlong.dart';
import 'package:fibus/core/constants/app_constants.dart';

/// Real-time bus telemetry and dynamic arrival predictions.
///
/// Stored in Firebase Realtime Database at `liveBuses/{busId}`.
class LiveBusModel {
  /// Bus identifier (matches RTDB key).
  final String busId;

  /// Current GPS latitude coordinate.
  final double latitude;

  /// Current GPS longitude coordinate.
  final double longitude;

  /// Instantaneous GPS ground speed in meters per second (m/s).
  final double speed;

  /// Heading / compass bearing in degrees [0, 360).
  final double heading;

  /// GPS fix accuracy radius in meters.
  final double accuracy;

  /// Timestamp when GPS fix was recorded on device (milliseconds since epoch).
  final int timestamp;

  /// Monotonically increasing tracking session generation counter.
  final int sessionGeneration;

  /// UID of the operator transmitting this tracking session.
  final String operatorUid;

  /// Current tracking status ('tracking', 'ended', 'stale').
  final String status;

  /// Dynamic arrival times in seconds from current bus location to downstream stops.
  /// Map of `stopId` -> ETA seconds.
  final Map<String, int> busEta;

  /// Milliseconds epoch timestamp when backend ETA algorithm last processed this fix.
  final int? lastProcessedAt;

  /// Exponentially smoothed or sliding-window average speed in m/s.
  final double? smoothedSpeed;

  /// Server timestamp (ms since epoch) of the last accepted location write.
  final int? lastLocationAtServer;

  const LiveBusModel({
    required this.busId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
    required this.accuracy,
    required this.timestamp,
    required this.sessionGeneration,
    required this.operatorUid,
    required this.status,
    this.busEta = const {},
    this.lastProcessedAt,
    this.smoothedSpeed,
    this.lastLocationAtServer,
  });

  /// Geographic coordinates as a [LatLng] instance.
  LatLng get latLng => LatLng(latitude, longitude);

  /// Speed converted to kilometers per hour (km/h).
  double get speedKmh => speed * 3.6;

  /// Smoothed speed in km/h if available, otherwise instantaneous speed in km/h.
  double get effectiveSpeedKmh => (smoothedSpeed ?? speed) * 3.6;

  /// Date and time when the telemetry was recorded.
  DateTime get recordedAt => DateTime.fromMillisecondsSinceEpoch(timestamp);

  /// Checks if this telemetry is stale based on elapsed time or explicit status.
  bool get isStale {
    if (status == 'stale' || status == 'ended') return true;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return (nowMs - timestamp) > (AppConstants.staleThresholdSeconds * 1000);
  }

  /// Whether the bus is currently broadcasting active tracking.
  bool get isLive => status == 'tracking' && !isStale;

  /// Whether no trip is broadcasting (never started or explicitly ended).
  bool get isOffline => status == 'ended' || timestamp == 0;

  /// Creates a [LiveBusModel] from an RTDB map snapshot.
  factory LiveBusModel.fromRtdb(dynamic data, {String? busId}) {
    if (data is! Map) {
      throw StateError('Cannot create LiveBusModel from non-map RTDB payload: $data');
    }

    final rawEta = data['busEta'];
    final Map<String, int> parsedEta = {};
    if (rawEta is Map) {
      rawEta.forEach((key, value) {
        if (key != null && value != null) {
          final int? sec = (value is num) ? value.toInt() : int.tryParse(value.toString());
          if (sec != null) {
            parsedEta[key.toString()] = sec;
          }
        }
      });
    }

    return LiveBusModel(
      busId: busId ?? (data['busId']?.toString() ?? ''),
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      speed: (data['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (data['heading'] as num?)?.toDouble() ?? 0.0,
      accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as num?)?.toInt() ?? 0,
      sessionGeneration: (data['sessionGeneration'] as num?)?.toInt() ?? 0,
      operatorUid: data['operatorUid']?.toString() ?? '',
      status: data['status']?.toString() ?? 'ended',
      busEta: parsedEta,
      lastProcessedAt: (data['lastProcessedAt'] as num?)?.toInt(),
      smoothedSpeed: (data['smoothedSpeed'] as num?)?.toDouble(),
      lastLocationAtServer: (data['lastServerHeartbeat'] as num?)?.toInt(),
    );
  }

  /// Serializes the model into an RTDB-compatible JSON map.
  Map<String, dynamic> toRtdb() {
    return {
      'busId': busId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'heading': heading,
      'accuracy': accuracy,
      'timestamp': timestamp,
      'sessionGeneration': sessionGeneration,
      'operatorUid': operatorUid,
      'status': status,
      'busEta': busEta,
      'lastProcessedAt': lastProcessedAt,
      'smoothedSpeed': smoothedSpeed,
    };
  }

  /// Returns a copy of this [LiveBusModel] with updated properties.
  LiveBusModel copyWith({
    String? busId,
    double? latitude,
    double? longitude,
    double? speed,
    double? heading,
    double? accuracy,
    int? timestamp,
    int? sessionGeneration,
    String? operatorUid,
    String? status,
    Map<String, int>? busEta,
    int? lastProcessedAt,
    double? smoothedSpeed,
    int? lastLocationAtServer,
  }) {
    return LiveBusModel(
      busId: busId ?? this.busId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      sessionGeneration: sessionGeneration ?? this.sessionGeneration,
      operatorUid: operatorUid ?? this.operatorUid,
      status: status ?? this.status,
      busEta: busEta ?? this.busEta,
      lastProcessedAt: lastProcessedAt ?? this.lastProcessedAt,
      smoothedSpeed: smoothedSpeed ?? this.smoothedSpeed,
      lastLocationAtServer: lastLocationAtServer ?? this.lastLocationAtServer,
    );
  }
}
