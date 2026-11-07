import 'package:cloud_firestore/cloud_firestore.dart';

/// Scheduled arrival and departure timetable record for a stop along a route.
///
/// Stored in Firestore at `stopTimes/{stopTimeId}`.
class StopTimeModel {
  /// Unique identifier of the timetable record (matches document ID).
  final String stopTimeId;

  /// ID of the bus stop.
  final String stopId;

  /// Associated route ID.
  final String routeId;

  /// Scheduled arrival time in 24-hour format (e.g. "08:15", "14:30").
  final String scheduledArrival;

  /// Scheduled departure time in 24-hour format (e.g. "08:17", "14:32").
  final String? scheduledDeparture;

  /// Trip direction indicator: typically 'up' (outbound) or 'down' (inbound).
  final String tripDirection;

  const StopTimeModel({
    required this.stopTimeId,
    required this.stopId,
    required this.routeId,
    required this.scheduledArrival,
    this.scheduledDeparture,
    this.tripDirection = 'up',
  });

  /// Creates a [StopTimeModel] from a Firestore document snapshot.
  factory StopTimeModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Cannot create StopTimeModel from empty document snapshot');
    }
    return StopTimeModel.fromMap(data, id: snapshot.id);
  }

  /// Creates a [StopTimeModel] from a key-value map and document ID.
  factory StopTimeModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return StopTimeModel(
      stopTimeId: id ?? (map['stopTimeId'] as String? ?? ''),
      stopId: map['stopId'] as String? ?? '',
      routeId: map['routeId'] as String? ?? '',
      scheduledArrival: map['scheduledArrival'] as String? ?? '00:00',
      scheduledDeparture: map['scheduledDeparture'] as String?,
      tripDirection: map['tripDirection'] as String? ?? 'up',
    );
  }

  /// Serializes the model for Firestore persistence.
  Map<String, dynamic> toFirestore() {
    return {
      'stopTimeId': stopTimeId,
      'stopId': stopId,
      'routeId': routeId,
      'scheduledArrival': scheduledArrival,
      'scheduledDeparture': scheduledDeparture,
      'tripDirection': tripDirection,
    };
  }

  /// Serializes the model into a standard JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'stopTimeId': stopTimeId,
      'stopId': stopId,
      'routeId': routeId,
      'scheduledArrival': scheduledArrival,
      'scheduledDeparture': scheduledDeparture,
      'tripDirection': tripDirection,
    };
  }

  /// Returns a copy of this [StopTimeModel] with updated properties.
  StopTimeModel copyWith({
    String? stopTimeId,
    String? stopId,
    String? routeId,
    String? scheduledArrival,
    String? scheduledDeparture,
    String? tripDirection,
  }) {
    return StopTimeModel(
      stopTimeId: stopTimeId ?? this.stopTimeId,
      stopId: stopId ?? this.stopId,
      routeId: routeId ?? this.routeId,
      scheduledArrival: scheduledArrival ?? this.scheduledArrival,
      scheduledDeparture: scheduledDeparture ?? this.scheduledDeparture,
      tripDirection: tripDirection ?? this.tripDirection,
    );
  }
}
