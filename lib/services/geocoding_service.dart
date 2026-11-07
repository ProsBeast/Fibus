import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:fibus/core/constants/api_endpoints.dart';
import 'package:fibus/core/constants/app_constants.dart';

/// A place returned by a location search.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.location,
  });

  /// Primary label, e.g. the place or street name.
  final String title;

  /// Secondary context, e.g. area, city and state.
  final String subtitle;

  /// Coordinates of the place.
  final LatLng location;
}

/// Location search used by the home pin screen.
///
/// Kept behind this interface so the provider can be swapped (for example to
/// Google Places) by replacing [GeocodingService.instance] only.
abstract class GeocodingService {
  /// Default implementation used across the app.
  static GeocodingService instance = PhotonGeocodingService();

  /// Searches for places matching [query], preferring results near [near].
  ///
  /// Returns an empty list when nothing matches. Throws on network failure.
  Future<List<PlaceSuggestion>> search(String query, {LatLng? near});
}

/// [GeocodingService] backed by the public Photon geocoder (OpenStreetMap data).
///
/// Photon supports search-as-you-type, unlike the public Nominatim server whose
/// usage policy forbids autocomplete. The public instance is fair-use only.
class PhotonGeocodingService implements GeocodingService {
  PhotonGeocodingService({
    http.Client? client,
    this.bbox = AppConstants.serviceRegionBbox,
    this.allowedState = AppConstants.serviceRegionState,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Search area as `minLon,minLat,maxLon,maxLat`; `null` searches worldwide.
  final String? bbox;

  /// Results outside this state are dropped (a bounding box alone also catches
  /// border areas of neighbouring states); `null` keeps every result.
  final String? allowedState;

  static const int _resultLimit = 6;

  @override
  Future<List<PlaceSuggestion>> search(String query, {LatLng? near}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final uri = Uri.parse(ApiEndpoints.photonSearchUrl).replace(
      queryParameters: {
        'q': trimmed,
        'limit': '$_resultLimit',
        'lang': 'en',
        'bbox': ?bbox,
        if (near != null) 'lat': near.latitude.toStringAsFixed(5),
        if (near != null) 'lon': near.longitude.toStringAsFixed(5),
      },
    );

    final response = await _client.get(
      uri,
      headers: {'User-Agent': '${AppConstants.commuterPackageName} (Fibus pilot)'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      developer.log('Photon search failed: HTTP ${response.statusCode}');
      throw Exception('Location search is unavailable (HTTP ${response.statusCode}).');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final features = data['features'] as List? ?? [];
    return [
      for (final feature in features)
        if (_parseFeature(feature) case final suggestion?) suggestion,
    ];
  }

  PlaceSuggestion? _parseFeature(dynamic feature) {
    if (feature is! Map) return null;
    final coords = (feature['geometry'] as Map?)?['coordinates'] as List?;
    if (coords == null || coords.length < 2) return null;

    final props = (feature['properties'] as Map?) ?? const {};
    String? field(String key) {
      final value = props[key]?.toString().trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    if (allowedState != null &&
        field('state')?.toLowerCase() != allowedState!.toLowerCase()) {
      return null;
    }

    final street = [field('housenumber'), field('street')].whereType<String>().join(' ');
    final title = field('name') ?? (street.isNotEmpty ? street : null) ?? field('city');
    if (title == null) return null;

    final context = <String>{
      if (street.isNotEmpty && street != title) street,
      ?field('district'),
      ?field('locality'),
      ?field('city'),
      ?field('state'),
      ?field('postcode'),
    }..remove(title);

    return PlaceSuggestion(
      title: title,
      subtitle: context.join(', '),
      // GeoJSON coordinates are [longitude, latitude].
      location: LatLng(
        (coords[1] as num).toDouble(),
        (coords[0] as num).toDouble(),
      ),
    );
  }
}
