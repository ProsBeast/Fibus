import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:fibus/core/constants/firebase_paths.dart';
import 'package:fibus/models/live_bus_model.dart';

/// Service managing real-time bus telemetry, active tracking sessions,
/// and live ETA streams via Firebase Realtime Database.
class RealtimeDbService {
  final FirebaseDatabase _db;

  /// Singleton instance.
  static final RealtimeDbService _instance = RealtimeDbService._internal();

  /// Factory accessor returning the singleton or injected instance.
  factory RealtimeDbService({FirebaseDatabase? database}) {
    if (database != null) {
      return RealtimeDbService._internal(database: database);
    }
    return _instance;
  }

  RealtimeDbService._internal({FirebaseDatabase? database})
    : _db = database ?? FirebaseDatabase.instance;

  // ---------------------------------------------------------------------------
  // GPS Telemetry Publishing
  // ---------------------------------------------------------------------------

  /// Publishes a live GPS telemetry fix for the specified bus.
  ///
  /// Updates the `liveBuses/{busId}` node with coordinates, velocity, accuracy,
  /// session generation, and current device/server timestamps.
  Future<void> publishLocation({
    required String busId,
    required double lat,
    required double lng,
    required double speed,
    required double heading,
    required double accuracy,
    required int sessionGeneration,
  }) async {
    try {
      final busRef = _db.ref(FirebasePaths.liveBus(busId));

      final Map<String, dynamic> locationData = {
        'latitude': lat,
        'longitude': lng,
        'speed': speed,
        'heading': heading,
        'accuracy': accuracy,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'sessionGeneration': sessionGeneration,
        'status': 'tracking',
        'lastServerHeartbeat': ServerValue.timestamp,
      };

      await busRef.update(locationData);
    } catch (e) {
      debugPrint('RealtimeDbService.publishLocation error for $busId: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Real-time Streams
  // ---------------------------------------------------------------------------

  /// Streams real-time telemetry updates for a specific bus.
  ///
  /// Emits `null` if the bus record does not exist or has been cleared.
  Stream<LiveBusModel?> streamLiveBus(String busId) {
    return _db.ref(FirebasePaths.liveBus(busId)).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      try {
        return LiveBusModel.fromRtdb(data, busId: busId);
      } catch (e) {
        debugPrint('Error parsing LiveBusModel for $busId: $e');
        return null;
      }
    });
  }

  /// Streams all live buses currently registered in the `liveBuses` path.
  Stream<List<LiveBusModel>> streamAllLiveBuses() {
    return _db.ref(FirebasePaths.liveBusesPath).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <LiveBusModel>[];

      final List<LiveBusModel> buses = [];
      data.forEach((key, value) {
        if (value != null && value is Map) {
          try {
            buses.add(LiveBusModel.fromRtdb(value, busId: key.toString()));
          } catch (e) {
            debugPrint(
              'Error parsing LiveBus in streamAllLiveBuses ($key): $e',
            );
          }
        }
      });

      return buses;
    });
  }

  /// Fetches a one-time snapshot of a live bus.
  Future<LiveBusModel?> getLiveBus(String busId) async {
    try {
      final snapshot = await _db.ref(FirebasePaths.liveBus(busId)).get();
      if (!snapshot.exists || snapshot.value == null) return null;
      return LiveBusModel.fromRtdb(snapshot.value, busId: busId);
    } catch (e) {
      debugPrint('RealtimeDbService.getLiveBus error for $busId: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // ETA & Predictions
  // ---------------------------------------------------------------------------

  /// Updates dynamic estimated time of arrival (in seconds) for each stop on the bus route.
  Future<void> updateBusEta(String busId, Map<String, int> etaByStop) async {
    try {
      final batchUpdates = <String, dynamic>{
        'busEta': etaByStop,
        'lastProcessedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _db.ref(FirebasePaths.liveBus(busId)).update(batchUpdates);
    } catch (e) {
      debugPrint('RealtimeDbService.updateBusEta error for $busId: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Session Lifecycle & Takeover Management
  // ---------------------------------------------------------------------------

  /// Creates and authoritatively claims an active tracking session for a bus.
  ///
  /// Increments or sets the [generation] number so stale sessions are rejected.
  Future<void> createSession({
    required String busId,
    required String operatorUid,
    required int generation,
  }) async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final sessionData = {
        'busId': busId,
        'operatorUid': operatorUid,
        'sessionGeneration': generation,
        'status': 'active',
        'startedAt': nowMs,
        'startedAtServer': ServerValue.timestamp,
      };

      final busData = {
        'busId': busId,
        'operatorUid': operatorUid,
        'sessionGeneration': generation,
        'status': 'tracking',
        'timestamp': nowMs,
      };

      // liveBuses is the rule-checked claim; only record the session once
      // that claim was accepted, so a rejected start leaves nothing behind.
      await _db.ref(FirebasePaths.liveBus(busId)).update(busData);
      await _db.ref(FirebasePaths.activeSession(busId)).set(sessionData);
    } catch (e) {
      debugPrint('RealtimeDbService.createSession error for $busId: $e');
      rethrow;
    }
  }

  /// Drops writes still waiting for a connection, so a start that timed out
  /// offline cannot turn into a ghost trip when the network returns.
  Future<void> purgePendingWrites() async {
    try {
      await _db.purgeOutstandingWrites();
    } catch (e) {
      debugPrint('RealtimeDbService.purgePendingWrites error: $e');
    }
  }

  /// Concludes and tears down an active tracking session for a bus.
  Future<void> endSession(String busId) async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final sessionUpdates = {
        'status': 'ended',
        'endedAt': nowMs,
        'endedAtServer': ServerValue.timestamp,
      };

      final busUpdates = {'status': 'ended', 'timestamp': nowMs};

      await Future.wait([
        _db.ref(FirebasePaths.activeSession(busId)).update(sessionUpdates),
        _db.ref(FirebasePaths.liveBus(busId)).update(busUpdates),
      ]);
    } catch (e) {
      debugPrint('RealtimeDbService.endSession error for $busId: $e');
      rethrow;
    }
  }

  /// Reads the current session generation number for a bus to determine
  /// whether a takeover increment is required.
  Future<int> getSessionGeneration(String busId) async {
    try {
      final snapshot = await _db
          .ref('${FirebasePaths.liveBus(busId)}/sessionGeneration')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final val = snapshot.value;
        if (val is num) return val.toInt();
        return int.tryParse(val.toString()) ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('RealtimeDbService.getSessionGeneration error for $busId: $e');
      return 0;
    }
  }
}
