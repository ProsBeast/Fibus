import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:fibus/services/geocoding_service.dart';

void main() {
  group('PhotonGeocodingService', () {
    test('parses GeoJSON features into suggestions (lon/lat order)', () async {
      late Uri requested;
      final service = PhotonGeocodingService(
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'geometry': {
                    'coordinates': [78.4483, 17.4374],
                  },
                  'properties': {
                    'name': 'Ameerpet',
                    'city': 'Hyderabad',
                    'state': 'Telangana',
                  },
                },
                {
                  // No coordinates: skipped.
                  'properties': {'name': 'Broken'},
                },
              ],
            }),
            200,
          );
        }),
      );

      final results = await service.search(
        'ameerpet',
        near: const LatLng(17.3850, 78.4867),
      );

      expect(requested.queryParameters['q'], 'ameerpet');
      expect(requested.queryParameters['lat'], '17.38500');
      expect(results, hasLength(1));
      expect(results.first.title, 'Ameerpet');
      expect(results.first.subtitle, 'Hyderabad, Telangana');
      expect(results.first.location.latitude, 17.4374);
      expect(results.first.location.longitude, 78.4483);
    });

    test('limits search to Telangana and drops other states', () async {
      late Uri requested;
      final service = PhotonGeocodingService(
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'geometry': {'coordinates': [78.4867, 17.3850]},
                  'properties': {'name': 'Abids', 'state': 'Telangana'},
                },
                {
                  // Inside the bounding box but across the border.
                  'geometry': {'coordinates': [80.6480, 16.5062]},
                  'properties': {'name': 'Vijayawada', 'state': 'Andhra Pradesh'},
                },
              ],
            }),
            200,
          );
        }),
      );

      final results = await service.search('abids');

      expect(requested.queryParameters['bbox'], '77.2,15.8,81.4,19.95');
      expect(results.map((r) => r.title), ['Abids']);
    });

    test('blank query makes no request', () async {
      var called = false;
      final service = PhotonGeocodingService(
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      expect(await service.search('   '), isEmpty);
      expect(called, isFalse);
    });

    test('HTTP errors are surfaced as exceptions', () async {
      final service = PhotonGeocodingService(
        client: MockClient((_) async => http.Response('busy', 503)),
      );

      expect(service.search('rk beach'), throwsException);
    });
  });
}
