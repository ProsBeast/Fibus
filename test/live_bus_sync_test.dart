import 'package:flutter_test/flutter_test.dart';
import 'package:fibus/models/live_bus.dart';

/// The Commuter app must understand exactly what the Tracker app writes to
/// `liveBuses/{busId}` (see RealtimeDbService.createSession/publishLocation).
void main() {
  Map<String, dynamic> trackerPayload({required int heartbeatAgeMs, String status = 'tracking'}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'busId': 'bus_1',
      'operatorUid': 'op_1',
      'sessionGeneration': 3,
      'status': status,
      'latitude': 17.4374,
      'longitude': 78.4483,
      'speed': 8.5,
      'heading': 90.0,
      'accuracy': 12.0,
      'timestamp': now - heartbeatAgeMs,
      'lastServerHeartbeat': now - heartbeatAgeMs,
    };
  }

  test('a fresh Tracker fix reads as live on the Commuter side', () {
    final bus = LiveBus.fromRtdb('bus_1', trackerPayload(heartbeatAgeMs: 5000));

    expect(bus.isLive, isTrue);
    expect(bus.isStale, isFalse);
    expect(bus.trackerUid, 'op_1');
    expect(bus.latitude, 17.4374);
    expect(bus.accuracyM, 12.0);
    expect(bus.speedMps, 8.5);
  });

  test('no fix for over 60 seconds reads as stale, not live', () {
    final bus = LiveBus.fromRtdb('bus_1', trackerPayload(heartbeatAgeMs: 61000));

    expect(bus.isLive, isFalse);
    expect(bus.isStale, isTrue);
  });

  test('an ended trip is neither live nor stale', () {
    final bus = LiveBus.fromRtdb(
      'bus_1',
      trackerPayload(heartbeatAgeMs: 1000, status: 'ended'),
    );

    expect(bus.isLive, isFalse);
    expect(bus.isStale, isFalse);
    expect(bus.isOffline, isTrue);
  });
}
