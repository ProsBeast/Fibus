import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:fibus/core/constants/api_endpoints.dart';
import 'package:fibus/core/utils/geo_utils.dart';

/// Structured routing outcome returned by the OSRM routing engine.
class OsrmRouteResult {
  /// Ordered sequence of [LatLng] coordinates tracing the road geometry.
  final List<LatLng> geometry;

  /// Travel duration in seconds.
  final double durationSeconds;

  /// Road distance in meters.
  final double distanceMeters;

  /// Whether this result was computed via geometric fallback due to API unavailability.
  final bool isFallback;

  const OsrmRouteResult({
    required this.geometry,
    required this.durationSeconds,
    required this.distanceMeters,
    this.isFallback = false,
  });

  /// Duration converted to whole minutes.
  int get durationMinutes => (durationSeconds / 60.0).round();

  /// Distance converted to kilometers.
  double get distanceKm => distanceMeters / 1000.0;
}

class _CachedDurationEntry {
  final int durationSeconds;
  final DateTime expiresAt;

  _CachedDurationEntry({
    required this.durationSeconds,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Client for Open Source Routing Machine (OSRM) public HTTP API.
///
/// Computes road geometries, travel times (using driving profile as a scooter proxy),
/// and manages an in-memory cache with a 3-minute TTL to minimize redundant network calls.
class OsrmService {
  final http.Client _client;

  /// In-memory cache for origin->destination travel times.
  final Map<String, _CachedDurationEntry> _travelTimeCache = {};

  /// Cache TTL duration (3 minutes).
  static const Duration cacheTtl = Duration(minutes: 3);

  /// Network request timeout.
  static const Duration requestTimeout = Duration(seconds: 12);

  /// Assumed scooter velocity in urban corridors (25 km/h ≈ 6.94 m/s) used for fallbacks.
  static const double fallbackScooterSpeedMps = 6.94;

  /// Singleton instance.
  static final OsrmService _instance = OsrmService._internal();

  /// Factory constructor returning singleton or injected instance.
  factory OsrmService({http.Client? client}) {
    if (client != null) {
      return OsrmService._internal(client: client);
    }
    return _instance;
  }

  OsrmService._internal({http.Client? client})
      : _client = client ?? http.Client();

  // ---------------------------------------------------------------------------
  // Route Navigation & Geometry
  // ---------------------------------------------------------------------------

  /// Fetches the road-aligned route geometry, total travel duration, and distance
  /// through an ordered list of [waypoints].
  ///
  /// Uses OSRM 'driving' profile as a practical scooter proxy.
  Future<OsrmRouteResult> getRoute(
    List<LatLng> waypoints, {
    String profile = 'driving',
  }) async {
    if (waypoints.isEmpty) {
      return const OsrmRouteResult(
        geometry: [],
        durationSeconds: 0,
        distanceMeters: 0,
      );
    }

    if (waypoints.length == 1) {
      return OsrmRouteResult(
        geometry: [waypoints.first],
        durationSeconds: 0,
        distanceMeters: 0,
      );
    }

    // Coordinates in OSRM format: "lng1,lat1;lng2,lat2;..."
    final String coordString = waypoints
        .map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');

    final url = Uri.parse(
      ApiEndpoints.osrmRouteUrl(
        coordinates: coordString,
        profile: profile,
        overviewFull: true,
      ),
    );

    try {
      final response = await _client.get(url).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
          final firstRoute = data['routes'][0];
          final String encodedPolyline = firstRoute['geometry'] as String? ?? '';
          final double duration = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;
          final double distance = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;

          final List<LatLng> decodedGeometry = encodedPolyline.isNotEmpty
              ? GeoUtils.decodePolyline(encodedPolyline)
              : waypoints;

          return OsrmRouteResult(
            geometry: decodedGeometry,
            durationSeconds: duration,
            distanceMeters: distance,
            isFallback: false,
          );
        }
      }

      debugPrint('OSRM returned unexpected status or code: ${response.statusCode}');
      return _computeFallbackRoute(waypoints);
    } catch (e) {
      debugPrint('OSRM request error: $e');
      return _computeFallbackRoute(waypoints);
    }
  }

  // ---------------------------------------------------------------------------
  // Point-to-Point Travel Time (with 3-minute in-memory cache)
  // ---------------------------------------------------------------------------

  /// Calculates travel duration in seconds from [origin] to [destination].
  ///
  /// Caches responses in memory for 3 minutes to prevent duplicate requests
  /// during active countdowns and alert loops.
  Future<int> getTravelTime(
    LatLng origin,
    LatLng destination, {
    bool forceRefresh = false,
  }) async {
    final String cacheKey = _buildCacheKey(origin, destination);

    // 1. Check in-memory cache
    if (!forceRefresh && _travelTimeCache.containsKey(cacheKey)) {
      final entry = _travelTimeCache[cacheKey]!;
      if (!entry.isExpired) {
        return entry.durationSeconds;
      }
      _travelTimeCache.remove(cacheKey);
    }

    // 2. Query OSRM
    final route = await getRoute([origin, destination]);
    final durationSeconds = route.durationSeconds.round();

    // 3. Cache valid result
    _travelTimeCache[cacheKey] = _CachedDurationEntry(
      durationSeconds: durationSeconds,
      expiresAt: DateTime.now().add(cacheTtl),
    );

    _pruneExpiredCacheEntries();
    return durationSeconds;
  }

  // ---------------------------------------------------------------------------
  // Full Route Geometry Generation
  // ---------------------------------------------------------------------------

  /// Generates full stitched route polyline connecting all ordered [stops].
  ///
  /// If [stops] has fewer than 2 stops, returns [stops] as-is.
  Future<List<LatLng>> getRouteGeometry(List<LatLng> stops) async {
    if (stops.length < 2) return stops;
    final result = await getRoute(stops);
    return result.geometry;
  }

  // ---------------------------------------------------------------------------
  // Cache & Fallback Helpers
  // ---------------------------------------------------------------------------

  String _buildCacheKey(LatLng a, LatLng b) {
    return '${a.latitude.toStringAsFixed(4)},${a.longitude.toStringAsFixed(4)}->${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}';
  }

  void _pruneExpiredCacheEntries() {
    if (_travelTimeCache.length < 50) return;
    final now = DateTime.now();
    _travelTimeCache.removeWhere((_, entry) => now.isAfter(entry.expiresAt));
  }

  /// Clears in-memory route duration cache.
  void clearCache() {
    _travelTimeCache.clear();
  }

  /// Provides straight-line distance and constant-speed fallback if OSRM is offline.
  OsrmRouteResult _computeFallbackRoute(List<LatLng> waypoints) {
    double totalDistance = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      totalDistance += GeoUtils.haversineDistance(waypoints[i], waypoints[i + 1]);
    }

    final double estimatedDuration = totalDistance / fallbackScooterSpeedMps;

    return OsrmRouteResult(
      geometry: List<LatLng>.from(waypoints),
      durationSeconds: estimatedDuration,
      distanceMeters: totalDistance,
      isFallback: true,
    );
  }

  /// Disposes HTTP client if allocated locally.
  void dispose() {
    _client.close();
  }
}
