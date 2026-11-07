import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:fibus/core/utils/geo_utils.dart';
import 'package:fibus/models/live_bus.dart';
import 'package:fibus/models/stop_model.dart';
import 'package:fibus/services/bus_eta_estimator.dart';

/// End-to-end ETA check on the real seeded Route 9 geometry (984 points,
/// 8 stops), driving a simulated bus on the timetable.
void main() {
  final data = jsonDecode(File('test/fixtures/route_9.json').readAsStringSync());
  final polyline = [
    for (final p in data['polyline'] as List) LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble())
  ];
  final stops = [
    for (final s in data['stops'] as List)
      StopModel(
        id: s['id'],
        name: s['name'],
        latitude: (s['latitude'] as num).toDouble(),
        longitude: (s['longitude'] as num).toDouble(),
        scheduledArrivalLocalTime: s['scheduledArrivalLocalTime'],
      )
  ];
  final day = DateTime(2026, 11, 5);
  DateTime sched(String hhmm) {
    final p = hhmm.split(':');
    return DateTime(day.year, day.month, day.day, int.parse(p[0]), int.parse(p[1]));
  }

  test('stops project onto the route in order', () {
    final e = BusEtaEstimator(polyline: polyline, orderedStops: stops);
    double last = -1;
    for (final s in stops) {
      final along = e.stopProgress(s.id)!;
      expect(along, greaterThanOrEqualTo(last), reason: s.id);
      last = along;
      final off = GeoUtils.projectPointToPolyline(s.location, polyline).distanceMeters;
      expect(off, lessThan(250), reason: '${s.id} is ${off.round()} m off the polyline');
    }
    expect(e.routeLengthMeters / 1000, closeTo(37, 1));
  });

  test('on-time bus from Isnapur predicts every later stop near its timetable', () {
    final e = BusEtaEstimator(polyline: polyline, orderedStops: stops);
    // Drive from Isnapur to Patancheru on schedule, fixes every 5 s.
    final aAlong = e.stopProgress('isnapur')!;
    final bAlong = e.stopProgress('patancheru')!;
    final start = sched('07:30');
    final segSec = sched('07:44').difference(start).inSeconds;
    late LiveBus bus;
    late DateTime now;
    for (var s = 0; s <= 300; s += 5) {
      final along = aAlong + (bAlong - aAlong) * s / segSec;
      final p = GeoUtils.interpolateAlongPolyline(polyline, along);
      now = start.add(Duration(seconds: s));
      bus = LiveBus(
        busId: 'bus_9',
        status: 'active',
        sessionGeneration: 1,
        latitude: p.latitude,
        longitude: p.longitude,
        accuracyM: 8,
        lastLocationAtServer: now.millisecondsSinceEpoch,
      );
      e.ingest(bus);
    }
    for (final stop in stops.skip(1)) {
      final est = e.estimate(bus, stop.id, now);
      expect(est.status, LiveEtaStatus.live, reason: stop.id);
      final err = est.eta!.difference(sched(stop.scheduledArrivalLocalTime)).inSeconds.abs();
      expect(err, lessThan(90), reason: '${stop.id} off by $err s');
    }
    expect(e.estimate(bus, 'isnapur', now).status, LiveEtaStatus.passedStop);
  });
}
