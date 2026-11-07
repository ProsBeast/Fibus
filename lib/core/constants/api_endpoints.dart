/// Centralized API endpoint registry for external routing (OSRM)
/// and the Fibus Vercel serverless backend.
abstract final class ApiEndpoints {
  // ---------------------------------------------------------------------------
  // Vercel Serverless Backend
  // ---------------------------------------------------------------------------
  /// Default Vercel backend base URL. Configurable at runtime if needed.
  static String vercelBaseUrl = 'https://fibus-backend.vercel.app/api';

  /// Allows dynamically overriding the backend URL (e.g., local dev or staging).
  static void configureBaseUrl(String url) {
    vercelBaseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  // Vercel Route Paths
  static String get calculateEta => '$vercelBaseUrl/eta/calculate';
  static String get scooterDuration => '$vercelBaseUrl/eta/scooter';
  static String get evaluateAlerts => '$vercelBaseUrl/alerts/evaluate';
  static String get triggerNotification => '$vercelBaseUrl/alerts/notify';
  static String get verifyOperator => '$vercelBaseUrl/operator/verify';
  static String get backendHealth => '$vercelBaseUrl/health';

  // ---------------------------------------------------------------------------
  // Photon geocoder (OpenStreetMap search-as-you-type)
  // ---------------------------------------------------------------------------
  static const String photonSearchUrl = 'https://photon.komoot.io/api/';

  // ---------------------------------------------------------------------------
  // OSRM (Open Source Routing Machine) Endpoints
  // ---------------------------------------------------------------------------
  static const String osrmBaseUrl = 'https://router.project-osrm.org';

  /// Builds an OSRM route URL for given coordinate string (`lng,lat;lng,lat`).
  ///
  /// Profile can be 'driving', 'bike', or 'foot'.
  static String osrmRouteUrl({
    required String coordinates,
    String profile = 'driving',
    bool overviewFull = true,
    bool steps = false,
  }) {
    final overviewParam = overviewFull ? 'overview=full' : 'overview=simplified';
    final stepsParam = steps ? '&steps=true' : '';
    return '$osrmBaseUrl/route/v1/$profile/$coordinates?geometries=polyline&$overviewParam$stepsParam';
  }

  /// Builds an OSRM route URL between two LatLng points.
  /// Note: OSRM expects coordinates in `longitude,latitude` order.
  static String osrmPointToPointUrl({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String profile = 'driving',
  }) {
    final coordinates = '$startLng,$startLat;$endLng,$endLat';
    return osrmRouteUrl(coordinates: coordinates, profile: profile);
  }

  /// Builds an OSRM route URL for scooter travel (using 'bike' or 'driving' profile).
  static String osrmScooterRouteUrl({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return osrmPointToPointUrl(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      profile: 'bike',
    );
  }
}
