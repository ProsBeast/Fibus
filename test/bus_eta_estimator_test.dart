import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:fibus/models/live_bus.dart';
import 'package:fibus/models/stop_model.dart';
import 'package:fibus/services/bus_eta_estimator.dart';

// A straight east-west route ~10.6 km long with three timed stops:
// A 07:30 at 78.00, B 07:45 at 78.05, C 08:00 at 78.10.
const _lat = 17.0;
final _polyline = [for (var i = 0; i <= 100; i++) LatLng(_lat, 78.0 + i * 0.001)];
const _stops = [
  StopModel(id: 'a', name: 'A', latitude: _lat, longitude: 78.00, scheduledArrivalLocalTime: '07:30'),
  StopModel(id: 'b', name: 'B', latitude: _lat, longitude: 78.05, scheduledArrivalLocalTime: '07:45'),
  StopModel(id: 'c', name: 'C', latitude: _lat, longitude: 78.10, scheduledArrivalLocalTime: '08:00'),
];

final _t0 = DateTime(2026, 11, 5, 7, 30);

LiveBus _fix(double lng, Duration at, {double lat = _lat, int gen = 1, double acc = 10}) =>
    LiveBus(
      busId: 'bus',
      status: 'active',
      sessionGeneration: gen,
      latitude: lat,
      longitude: lng,
      accuracyM: acc,
      lastLocationAtServer: _t0.add(at).millisecondsSinceEpoch,
    );

BusEtaEstimator _estimator() =>
    BusEtaEstimator(polyline: _polyline, orderedStops: _stops);

/// Feeds fixes every 5 s moving east at [lngPerSec] degrees/s from [start].
LiveBus _drive(BusEtaEstimator e, double start, double lngPerSec, int seconds) {
  late LiveBus last;
  for (var s = 0; s <= seconds; s += 5) {
    last = _fix(start + lngPerSec * s, Duration(seconds: s));
    e.ingest(last);
  }
  return last;
}

void main() {
  test('no tracker when the bus has not started or has ended', () {
    final e = _estimator();
    expect(e.estimate(null, 'b', _t0).status, LiveEtaStatus.noTracker);
    expect(
      e.estimate(const LiveBus(busId: 'bus', status: 'ended'), 'b', _t0).status,
      LiveEtaStatus.noTracker,
    );
  });

  test('warming up until enough fixes arrive', () {
    final e = _estimator();
    final bus = _fix(78.01, Duration.zero);
    e.ingest(bus);
    expect(e.estimate(bus, 'b', _t0).status, LiveEtaStatus.warmingUp);
  });

  test('live ETA follows the timetable when the bus keeps schedule', () {
    final e = _estimator();
    // Schedule speed A->B: 0.05 deg in 15 min = 0.05/900 deg/s.
    final bus = _drive(e, 78.0, 0.05 / 900, 180);
    final now = _t0.add(const Duration(seconds: 180));
    final est = e.estimate(bus, 'b', now);
    expect(est.status, LiveEtaStatus.live);
    // On schedule the bus reaches B at 07:45.
    final expected = DateTime(2026, 11, 5, 7, 45);
    expect(est.eta!.difference(expected).inSeconds.abs(), lessThan(20));
  });

  test('a faster bus gets an earlier ETA than the timetable', () {
    final e = _estimator();
    final bus = _drive(e, 78.0, 2 * 0.05 / 900, 180); // twice schedule speed
    final est = e.estimate(bus, 'b', _t0.add(const Duration(seconds: 180)));
    final onTime = DateTime(2026, 11, 5, 7, 45);
    expect(est.status, LiveEtaStatus.live);
    expect(est.eta!.isBefore(onTime.subtract(const Duration(minutes: 3))), isTrue);
  });

  test('a bus stuck in traffic slips later as time passes', () {
    final e = _estimator();
    late LiveBus bus;
    for (var s = 0; s <= 300; s += 5) {
      bus = _fix(78.02, Duration(seconds: s)); // not moving
      e.ingest(bus);
    }
    final est = e.estimate(bus, 'b', _t0.add(const Duration(seconds: 300)));
    // Prior alone: 0.03 deg of 0.05 in 15 min = 9 min after the fix (07:44).
    expect(est.status, LiveEtaStatus.live);
    expect(est.eta!.isAfter(DateTime(2026, 11, 5, 7, 43)), isTrue);
  });

  test('stale after 60 s without a fix', () {
    final e = _estimator();
    final bus = _drive(e, 78.0, 0.00005, 60);
    final est = e.estimate(bus, 'b', _t0.add(const Duration(seconds: 60 + 61)));
    expect(est.status, LiveEtaStatus.stale);
    expect(est.eta, isNull);
  });

  test('passed stop once the bus is beyond it', () {
    final e = _estimator();
    final bus = _drive(e, 78.06, 0.00005, 30);
    expect(
      e.estimate(bus, 'b', _t0.add(const Duration(seconds: 30))).status,
      LiveEtaStatus.passedStop,
    );
  });

  test('off route when the fix is far from the polyline', () {
    final e = _estimator();
    late LiveBus bus;
    for (var s = 0; s <= 20; s += 5) {
      bus = _fix(78.02, Duration(seconds: s), lat: 17.01); // ~1.1 km north
      e.ingest(bus);
    }
    expect(
      e.estimate(bus, 'b', _t0.add(const Duration(seconds: 20))).status,
      LiveEtaStatus.offRoute,
    );
  });

  test('small backwards GPS jitter does not move the bus backwards', () {
    final e = _estimator();
    e.ingest(_fix(78.020, Duration.zero));
    e.ingest(_fix(78.021, const Duration(seconds: 5)));
    final jitter = _fix(78.0205, const Duration(seconds: 10)); // ~50 m back
    e.ingest(jitter);
    final est = e.estimate(jitter, 'b', _t0.add(const Duration(seconds: 10)));
    final atLatest = e.stopProgress('b')! - est.remainingMeters!;
    final expectedAlong = 0.021 * 111320 * 0.9563; // metres per degree at 17°N
    expect((atLatest - expectedAlong).abs(), lessThan(30));
  });

  test('poor-accuracy fixes are ignored', () {
    final e = _estimator();
    for (var s = 0; s <= 20; s += 5) {
      e.ingest(_fix(78.01, Duration(seconds: s), acc: 500));
    }
    final bus = _fix(78.01, const Duration(seconds: 20), acc: 500);
    expect(e.estimate(bus, 'b', _t0.add(const Duration(seconds: 20))).status,
        LiveEtaStatus.warmingUp);
  });

  test('a new tracker session resets progress history', () {
    final e = _estimator();
    _drive(e, 78.0, 0.00005, 30);
    final fresh = _fix(78.01, const Duration(seconds: 40), gen: 2);
    e.ingest(fresh);
    expect(e.estimate(fresh, 'b', _t0.add(const Duration(seconds: 40))).status,
        LiveEtaStatus.warmingUp);
  });
}
