import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fibus/services/location_service.dart';
import 'package:fibus/services/service_calendar.dart';
import 'package:fibus/tracker/providers/trip_lifecycle_provider.dart';

void main() {
  group('nextServiceArrival', () {
    // 2026-11-11 is a Wednesday.
    const monToSat = [1, 2, 3, 4, 5, 6];
    DateTime at(int day, int h, int m) => DateTime(2026, 11, day, h, m);

    test('before the bus: today', () {
      expect(
        nextServiceArrival(hhmm: '07:59', serviceDays: monToSat, now: at(11, 6, 30)),
        at(11, 7, 59),
      );
    });

    test('a little late still counts as today (bus may be running late)', () {
      expect(
        nextServiceArrival(hhmm: '07:59', serviceDays: monToSat, now: at(11, 8, 20)),
        at(11, 7, 59),
      );
    });

    test('well past the time: tomorrow, not "13 hours late"', () {
      expect(
        nextServiceArrival(hhmm: '07:59', serviceDays: monToSat, now: at(11, 21, 0)),
        at(12, 7, 59),
      );
    });

    test('bus seen passing the stop: next day at once', () {
      expect(
        nextServiceArrival(
            hhmm: '07:59', serviceDays: monToSat, now: at(11, 8, 0), skipToday: true),
        at(12, 7, 59),
      );
    });

    test('Saturday evening skips Sunday to Monday', () {
      // 14 Nov 2026 is a Saturday, 16 Nov a Monday.
      expect(
        nextServiceArrival(hhmm: '07:59', serviceDays: monToSat, now: at(14, 20, 0)),
        at(16, 7, 59),
      );
    });

    test('Sunday morning is not a service day', () {
      expect(
        nextServiceArrival(hhmm: '07:59', serviceDays: monToSat, now: at(15, 6, 0)),
        at(16, 7, 59),
      );
    });

    test('no service days listed means every day', () {
      expect(
        nextServiceArrival(hhmm: '07:59', serviceDays: const [], now: at(15, 6, 0)),
        at(15, 7, 59),
      );
    });

    test('a malformed time gives null instead of a made-up one', () {
      expect(
        nextServiceArrival(hhmm: 'soon', serviceDays: monToSat, now: at(11, 6, 0)),
        isNull,
      );
    });
  });

  group('relativeDayLabel and serviceDateKey', () {
    final now = DateTime(2026, 11, 11, 21, 0); // Wednesday
    test('today, tomorrow, weekday', () {
      expect(relativeDayLabel(DateTime(2026, 11, 11, 23, 0), now), '');
      expect(relativeDayLabel(DateTime(2026, 11, 12, 7, 41), now), 'tomorrow');
      expect(relativeDayLabel(DateTime(2026, 11, 16, 7, 41), now), 'Monday');
    });
    test('date key is zero padded', () {
      expect(serviceDateKey(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
    });
  });

  group('shouldPublishFix (bus standing still must not look lost)', () {
    test('first fix always uploads', () {
      expect(shouldPublishFix(movedMeters: 0, sinceLastPublish: null), isTrue);
    });
    test('moving uploads at once', () {
      expect(
        shouldPublishFix(movedMeters: 12, sinceLastPublish: const Duration(seconds: 5)),
        isTrue,
      );
    });
    test('standing still is throttled, then sends a heartbeat', () {
      expect(
        shouldPublishFix(movedMeters: 0.4, sinceLastPublish: const Duration(seconds: 5)),
        isFalse,
      );
      expect(
        shouldPublishFix(movedMeters: 0.4, sinceLastPublish: const Duration(seconds: 15)),
        isTrue,
      );
    });
  });

  group('tripErrorMessage', () {
    test('location problems pass their own message through', () {
      expect(
        tripErrorMessage(const LocationSetupException('Location is turned off')),
        'Location is turned off',
      );
    });
    test('offline', () {
      expect(tripErrorMessage(TimeoutException('x')), contains('No connection'));
    });
    test('rejected by the database rules', () {
      expect(
        tripErrorMessage(
            FirebaseException(plugin: 'firebase_database', code: 'permission-denied')),
        contains('another phone'),
      );
    });
    test('anything else never leaks a raw error', () {
      final msg = tripErrorMessage(StateError('[internal] boom'));
      expect(msg, isNot(contains('boom')));
    });
  });
}
