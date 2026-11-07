import 'dart:developer' as developer;
import 'package:firebase_database/firebase_database.dart';
import 'package:fibus/core/constants/firebase_paths.dart';
import 'package:fibus/models/live_bus.dart';

/// Realtime Database service handling live bus telemetry feeds.
class RtdbService {
  RtdbService._internal();
  static final RtdbService instance = RtdbService._internal();
  factory RtdbService() => instance;

  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  /// Streams real-time updates for a specific bus ID from `/liveBuses/{busId}`.
  Stream<LiveBus?> streamLiveBus(String busId) {
    if (busId.isEmpty) {
      return Stream.value(null);
    }

    final ref = _rtdb.ref(FirebasePaths.liveBus(busId));

    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) {
        return LiveBus(busId: busId);
      }
      if (value is Map) {
        return LiveBus.fromRtdb(busId, value);
      }
      return LiveBus(busId: busId);
    }).handleError((error, stackTrace) {
      developer.log('RTDB stream error for bus $busId',
          error: error, stackTrace: stackTrace);
      return LiveBus(busId: busId);
    });
  }

  /// One-time fetch of current live bus state.
  Future<LiveBus?> getLiveBus(String busId) async {
    if (busId.isEmpty) return null;

    try {
      final snapshot = await _rtdb.ref(FirebasePaths.liveBus(busId)).get();
      if (!snapshot.exists || snapshot.value == null) {
        return LiveBus(busId: busId);
      }
      if (snapshot.value is Map) {
        return LiveBus.fromRtdb(busId, snapshot.value as Map);
      }
      return LiveBus(busId: busId);
    } catch (e, stack) {
      developer.log('RTDB getLiveBus error for bus $busId',
          error: e, stackTrace: stack);
      return null;
    }
  }
}
