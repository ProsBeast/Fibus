import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Projection result of snapping a point onto a polyline.
class PolylineProjectionResult {
  /// The snapped point coordinates on the polyline.
  final LatLng nearestPoint;

  /// Perpendicular or shortest distance in meters from the query point to the polyline.
  final double distanceMeters;

  /// Index of the polyline segment vertex where the projection fell ([segmentIndex] to [segmentIndex] + 1).
  final int segmentIndex;

  /// Cumulative distance in meters from the polyline start to [nearestPoint].
  final double distanceAlongPolylineMeters;

  const PolylineProjectionResult({
    required this.nearestPoint,
    required this.distanceMeters,
    required this.segmentIndex,
    required this.distanceAlongPolylineMeters,
  });
}

/// Comprehensive geographic utility functions for distance, bearing,
/// polyline encoding/decoding, snapping, and interpolation.
abstract final class GeoUtils {
  /// Mean Earth radius in meters (WGS84 spherical approximation).
  static const double earthRadiusMeters = 6371000.0;

  /// Computes the great-circle distance between two [LatLng] points using the Haversine formula.
  ///
  /// Returns distance in meters.
  static double haversineDistance(LatLng p1, LatLng p2) {
    final double lat1Rad = p1.latitude * (math.pi / 180.0);
    final double lat2Rad = p2.latitude * (math.pi / 180.0);
    final double deltaLatRad = (p2.latitude - p1.latitude) * (math.pi / 180.0);
    final double deltaLonRad = (p2.longitude - p1.longitude) * (math.pi / 180.0);

    final double a = math.sin(deltaLatRad / 2.0) * math.sin(deltaLatRad / 2.0) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLonRad / 2.0) *
            math.sin(deltaLonRad / 2.0);

    final double c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a));
    return earthRadiusMeters * c;
  }

  /// Calculates initial compass bearing (azimuth) from [start] to [end] in degrees [0, 360).
  static double calculateBearing(LatLng start, LatLng end) {
    final double lat1 = start.latitude * (math.pi / 180.0);
    final double lat2 = end.latitude * (math.pi / 180.0);
    final double deltaLng = (end.longitude - start.longitude) * (math.pi / 180.0);

    final double y = math.sin(deltaLng) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);

    final double bearingRad = math.atan2(y, x);
    final double bearingDeg = (bearingRad * (180.0 / math.pi) + 360.0) % 360.0;
    return bearingDeg;
  }

  /// Decodes an Encoded Polyline string (Google Polyline Algorithm format, 1e5 precision)
  /// into a list of [LatLng] coordinates.
  static List<LatLng> decodePolyline(String encoded) {
    final List<LatLng> polyline = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return polyline;
  }

  /// Encodes a list of [LatLng] points into a Google Polyline Algorithm string (1e5 precision).
  static String encodePolyline(List<LatLng> points) {
    final StringBuffer str = StringBuffer();

    void encodeValue(int value) {
      int v = value < 0 ? ~(value << 1) : (value << 1);
      while (v >= 0x20) {
        str.writeCharCode((0x20 | (v & 0x1f)) + 63);
        v >>= 5;
      }
      str.writeCharCode(v + 63);
    }

    int lastLat = 0;
    int lastLng = 0;

    for (final LatLng point in points) {
      final int lat = (point.latitude * 1e5).round();
      final int lng = (point.longitude * 1e5).round();
      encodeValue(lat - lastLat);
      encodeValue(lng - lastLng);
      lastLat = lat;
      lastLng = lng;
    }

    return str.toString();
  }

  /// Projects point [p] onto segment [[a], [b]].
  ///
  /// Returns the nearest point on the segment and the parametric fraction `t` in [0, 1].
  static ({LatLng point, double t}) projectPointToSegment(
    LatLng p,
    LatLng a,
    LatLng b,
  ) {
    final double avgLatRad = (a.latitude + b.latitude) / 2.0 * (math.pi / 180.0);
    final double cosLat = math.cos(avgLatRad);

    final double dx = (b.longitude - a.longitude) * cosLat;
    final double dy = b.latitude - a.latitude;
    final double lenSq = dx * dx + dy * dy;

    if (lenSq == 0.0) {
      return (point: a, t: 0.0);
    }

    final double px = (p.longitude - a.longitude) * cosLat;
    final double py = p.latitude - a.latitude;
    final double dot = px * dx + py * dy;

    final double t = (dot / lenSq).clamp(0.0, 1.0);
    final double projLat = a.latitude + t * (b.latitude - a.latitude);
    final double projLng = a.longitude + t * (b.longitude - a.longitude);

    return (point: LatLng(projLat, projLng), t: t);
  }

  /// Snaps a query [point] onto the nearest segment of [polyline].
  ///
  /// Returns a [PolylineProjectionResult] containing the closest point on the line,
  /// the perpendicular distance, segment index, and total distance along the route.
  static PolylineProjectionResult projectPointToPolyline(
    LatLng point,
    List<LatLng> polyline,
  ) {
    if (polyline.isEmpty) {
      return PolylineProjectionResult(
        nearestPoint: point,
        distanceMeters: 0.0,
        segmentIndex: 0,
        distanceAlongPolylineMeters: 0.0,
      );
    }

    if (polyline.length == 1) {
      final d = haversineDistance(point, polyline.first);
      return PolylineProjectionResult(
        nearestPoint: polyline.first,
        distanceMeters: d,
        segmentIndex: 0,
        distanceAlongPolylineMeters: 0.0,
      );
    }

    double minDistance = double.infinity;
    LatLng bestPoint = polyline.first;
    int bestSegmentIndex = 0;
    double bestDistanceAlong = 0.0;
    double cumulativeDistance = 0.0;

    for (int i = 0; i < polyline.length - 1; i++) {
      final LatLng a = polyline[i];
      final LatLng b = polyline[i + 1];
      final segLength = haversineDistance(a, b);

      final projection = projectPointToSegment(point, a, b);
      final distToProjection = haversineDistance(point, projection.point);

      if (distToProjection < minDistance) {
        minDistance = distToProjection;
        bestPoint = projection.point;
        bestSegmentIndex = i;
        bestDistanceAlong = cumulativeDistance + (projection.t * segLength);
      }

      cumulativeDistance += segLength;
    }

    return PolylineProjectionResult(
      nearestPoint: bestPoint,
      distanceMeters: minDistance,
      segmentIndex: bestSegmentIndex,
      distanceAlongPolylineMeters: bestDistanceAlong,
    );
  }

  /// Computes the total cumulative distance in meters along an entire [polyline].
  static double totalPolylineDistance(List<LatLng> polyline) {
    if (polyline.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < polyline.length - 1; i++) {
      total += haversineDistance(polyline[i], polyline[i + 1]);
    }
    return total;
  }

  /// Interpolates a [LatLng] position along [polyline] at a given [distanceMeters] from start.
  ///
  /// Clamps to the start or end if [distanceMeters] falls outside the polyline length.
  static LatLng interpolateAlongPolyline(
    List<LatLng> polyline,
    double distanceMeters,
  ) {
    if (polyline.isEmpty) {
      return const LatLng(0.0, 0.0);
    }
    if (polyline.length == 1 || distanceMeters <= 0.0) {
      return polyline.first;
    }

    double traveled = 0.0;
    for (int i = 0; i < polyline.length - 1; i++) {
      final LatLng a = polyline[i];
      final LatLng b = polyline[i + 1];
      final double segDist = haversineDistance(a, b);

      if (traveled + segDist >= distanceMeters) {
        final double remaining = distanceMeters - traveled;
        final double t = (segDist > 0.0) ? (remaining / segDist).clamp(0.0, 1.0) : 0.0;
        final double lat = a.latitude + t * (b.latitude - a.latitude);
        final double lng = a.longitude + t * (b.longitude - a.longitude);
        return LatLng(lat, lng);
      }

      traveled += segDist;
    }

    return polyline.last;
  }
}
