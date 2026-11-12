import 'package:cloud_firestore/cloud_firestore.dart';

/// State of an active departure alert notification session for a commuter.
///
/// Tracks recommendation progression through:
/// `inactive` -> `monitoring` -> `advance_sent` -> `leave_now_sent` -> `completed` / `cancelled`.
///
/// Stored in Firestore at `alertSessions/{sessionId}`.
class AlertSessionModel {
  /// Unique session record ID (matches document ID).
  final String sessionId;

  /// Commuter's user UID.
  final String uid;

  /// Associated commute preference ID.
  final String prefId;

  /// Bus ID currently being monitored.
  final String busId;

  /// Boarding stop ID.
  final String stopId;

  /// Session state: 'inactive', 'monitoring', 'advance_sent', 'leave_now_sent', 'completed', 'cancelled'.
  final String state;

  /// Recommended timestamp when user should depart from home.
  final DateTime? recommendedLeaveBy;

  /// Estimated scooter travel time from user's home to the boarding stop in seconds.
  final int? scooterDurationSeconds;

  /// Real-time bus arrival ETA to the stop in seconds at time of evaluation.
  final int? busEtaSeconds;

  /// Session creation timestamp.
  final DateTime createdAt;

  /// Session last updated timestamp.
  final DateTime updatedAt;

  /// Monotonic version counter for idempotent push notification delivery.
  final int lastNotificationVersion;

  const AlertSessionModel({
    required this.sessionId,
    required this.uid,
    required this.prefId,
    required this.busId,
    required this.stopId,
    this.state = 'monitoring',
    this.recommendedLeaveBy,
    this.scooterDurationSeconds,
    this.busEtaSeconds,
    required this.createdAt,
    required this.updatedAt,
    this.lastNotificationVersion = 0,
  });

  /// Whether the session is actively monitoring live bus telemetry.
  bool get isMonitoring => state == 'monitoring';

  /// Whether the initial advance warning notification has been dispatched.
  bool get isAdvanceSent => state == 'advance_sent';

  /// Whether the urgent "Leave Now" notification has been dispatched.
  bool get isLeaveNowSent => state == 'leave_now_sent';

  /// Whether the session has concluded or been cancelled.
  bool get isFinished => state == 'completed' || state == 'cancelled';

  /// Creates an [AlertSessionModel] from a Firestore document snapshot.
  factory AlertSessionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError(
        'Cannot create AlertSessionModel from empty document snapshot',
      );
    }
    return AlertSessionModel.fromMap(data, id: snapshot.id);
  }

  /// Creates an [AlertSessionModel] from a key-value map and document ID.
  factory AlertSessionModel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? parsedLeaveBy;
    if (map['recommendedLeaveBy'] is Timestamp) {
      parsedLeaveBy = (map['recommendedLeaveBy'] as Timestamp).toDate();
    } else if (map['recommendedLeaveBy'] is String) {
      parsedLeaveBy = DateTime.tryParse(map['recommendedLeaveBy']);
    }

    DateTime parsedCreated;
    if (map['createdAt'] is Timestamp) {
      parsedCreated = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreated = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    } else {
      parsedCreated = DateTime.now();
    }

    DateTime parsedUpdated;
    if (map['updatedAt'] is Timestamp) {
      parsedUpdated = (map['updatedAt'] as Timestamp).toDate();
    } else if (map['updatedAt'] is String) {
      parsedUpdated = DateTime.tryParse(map['updatedAt']) ?? DateTime.now();
    } else {
      parsedUpdated = DateTime.now();
    }

    return AlertSessionModel(
      sessionId: id ?? (map['sessionId'] as String? ?? ''),
      uid: map['uid'] as String? ?? '',
      prefId: map['prefId'] as String? ?? '',
      busId: map['busId'] as String? ?? '',
      stopId: map['stopId'] as String? ?? '',
      state: map['state'] as String? ?? 'monitoring',
      recommendedLeaveBy: parsedLeaveBy,
      scooterDurationSeconds: (map['scooterDurationSeconds'] as num?)?.toInt(),
      busEtaSeconds: (map['busEtaSeconds'] as num?)?.toInt(),
      createdAt: parsedCreated,
      updatedAt: parsedUpdated,
      lastNotificationVersion:
          (map['lastNotificationVersion'] as num?)?.toInt() ?? 0,
    );
  }

  /// Serializes the model for Firestore persistence.
  Map<String, dynamic> toFirestore() {
    return {
      'sessionId': sessionId,
      'uid': uid,
      'prefId': prefId,
      'busId': busId,
      'stopId': stopId,
      'state': state,
      'recommendedLeaveBy': recommendedLeaveBy != null
          ? Timestamp.fromDate(recommendedLeaveBy!)
          : null,
      'scooterDurationSeconds': scooterDurationSeconds,
      'busEtaSeconds': busEtaSeconds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastNotificationVersion': lastNotificationVersion,
    };
  }

  /// Serializes the model into a standard JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'uid': uid,
      'prefId': prefId,
      'busId': busId,
      'stopId': stopId,
      'state': state,
      'recommendedLeaveBy': recommendedLeaveBy?.toIso8601String(),
      'scooterDurationSeconds': scooterDurationSeconds,
      'busEtaSeconds': busEtaSeconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastNotificationVersion': lastNotificationVersion,
    };
  }

  /// Returns a copy of this [AlertSessionModel] with updated properties.
  AlertSessionModel copyWith({
    String? sessionId,
    String? uid,
    String? prefId,
    String? busId,
    String? stopId,
    String? state,
    DateTime? recommendedLeaveBy,
    int? scooterDurationSeconds,
    int? busEtaSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? lastNotificationVersion,
  }) {
    return AlertSessionModel(
      sessionId: sessionId ?? this.sessionId,
      uid: uid ?? this.uid,
      prefId: prefId ?? this.prefId,
      busId: busId ?? this.busId,
      stopId: stopId ?? this.stopId,
      state: state ?? this.state,
      recommendedLeaveBy: recommendedLeaveBy ?? this.recommendedLeaveBy,
      scooterDurationSeconds:
          scooterDurationSeconds ?? this.scooterDurationSeconds,
      busEtaSeconds: busEtaSeconds ?? this.busEtaSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastNotificationVersion:
          lastNotificationVersion ?? this.lastNotificationVersion,
    );
  }
}
