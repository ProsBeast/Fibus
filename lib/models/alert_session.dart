import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertSessionStatus {
  inactive,
  monitoring,
  advanceSent,
  leaveNowSent,
  completed,
  cancelled;

  String toValue() {
    switch (this) {
      case AlertSessionStatus.inactive:
        return 'inactive';
      case AlertSessionStatus.monitoring:
        return 'monitoring';
      case AlertSessionStatus.advanceSent:
        return 'advance_sent';
      case AlertSessionStatus.leaveNowSent:
        return 'leave_now_sent';
      case AlertSessionStatus.completed:
        return 'completed';
      case AlertSessionStatus.cancelled:
        return 'cancelled';
    }
  }

  static AlertSessionStatus fromValue(String value) {
    switch (value) {
      case 'monitoring':
        return AlertSessionStatus.monitoring;
      case 'advance_sent':
        return AlertSessionStatus.advanceSent;
      case 'leave_now_sent':
        return AlertSessionStatus.leaveNowSent;
      case 'completed':
        return AlertSessionStatus.completed;
      case 'cancelled':
        return AlertSessionStatus.cancelled;
      default:
        return AlertSessionStatus.inactive;
    }
  }
}

/// Represents an active commuter alert monitoring session for a given service day.
class AlertSession {
  const AlertSession({
    required this.id,
    required this.commuterUid,
    required this.preferenceId,
    required this.serviceDate,
    required this.busId,
    required this.routeId,
    required this.boardingStopId,
    this.status = AlertSessionStatus.monitoring,
    this.recommendationVersion = 1,
    this.scheduledArrival,
    this.busEta,
    this.scooterDurationSeconds = 600, // 10 min default
    this.safetyMarginSeconds = 120, // 2 min default
    this.recommendedLeaveBy,
    this.advanceNotificationStatus = 'pending',
    this.leaveNowStatus = 'pending',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String commuterUid;
  final String preferenceId;
  final String serviceDate;
  final String busId;
  final String routeId;
  final String boardingStopId;
  final AlertSessionStatus status;
  final int recommendationVersion;
  final DateTime? scheduledArrival;
  final DateTime? busEta;
  final int scooterDurationSeconds;
  final int safetyMarginSeconds;
  final DateTime? recommendedLeaveBy;
  final String advanceNotificationStatus;
  final String leaveNowStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive =>
      status == AlertSessionStatus.monitoring ||
      status == AlertSessionStatus.advanceSent ||
      status == AlertSessionStatus.leaveNowSent;

  factory AlertSession.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return AlertSession.fromMap(data, snapshot.id);
  }

  factory AlertSession.fromMap(Map<String, dynamic> map, [String id = '']) {
    return AlertSession(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      commuterUid: map['commuterUid'] as String? ?? '',
      preferenceId: map['preferenceId'] as String? ?? '',
      serviceDate: map['serviceDate'] as String? ?? '',
      busId: map['busId'] as String? ?? '',
      routeId: map['routeId'] as String? ?? '',
      boardingStopId: map['boardingStopId'] as String? ?? '',
      status: AlertSessionStatus.fromValue(map['status'] as String? ?? 'inactive'),
      recommendationVersion: (map['recommendationVersion'] as num?)?.toInt() ?? 1,
      scheduledArrival: (map['scheduledArrival'] as Timestamp?)?.toDate(),
      busEta: (map['busEta'] as Timestamp?)?.toDate(),
      scooterDurationSeconds: (map['scooterDurationSeconds'] as num?)?.toInt() ?? 600,
      safetyMarginSeconds: (map['safetyMarginSeconds'] as num?)?.toInt() ?? 120,
      recommendedLeaveBy: (map['recommendedLeaveBy'] as Timestamp?)?.toDate(),
      advanceNotificationStatus:
          map['advanceNotificationStatus'] as String? ?? 'pending',
      leaveNowStatus: map['leaveNowStatus'] as String? ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'commuterUid': commuterUid,
      'preferenceId': preferenceId,
      'serviceDate': serviceDate,
      'busId': busId,
      'routeId': routeId,
      'boardingStopId': boardingStopId,
      'status': status.toValue(),
      'recommendationVersion': recommendationVersion,
      'scheduledArrival': scheduledArrival != null
          ? Timestamp.fromDate(scheduledArrival!)
          : null,
      'busEta': busEta != null ? Timestamp.fromDate(busEta!) : null,
      'scooterDurationSeconds': scooterDurationSeconds,
      'safetyMarginSeconds': safetyMarginSeconds,
      'recommendedLeaveBy': recommendedLeaveBy != null
          ? Timestamp.fromDate(recommendedLeaveBy!)
          : null,
      'advanceNotificationStatus': advanceNotificationStatus,
      'leaveNowStatus': leaveNowStatus,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AlertSession copyWith({
    String? id,
    String? commuterUid,
    String? preferenceId,
    String? serviceDate,
    String? busId,
    String? routeId,
    String? boardingStopId,
    AlertSessionStatus? status,
    int? recommendationVersion,
    DateTime? scheduledArrival,
    DateTime? busEta,
    int? scooterDurationSeconds,
    int? safetyMarginSeconds,
    DateTime? recommendedLeaveBy,
    String? advanceNotificationStatus,
    String? leaveNowStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AlertSession(
      id: id ?? this.id,
      commuterUid: commuterUid ?? this.commuterUid,
      preferenceId: preferenceId ?? this.preferenceId,
      serviceDate: serviceDate ?? this.serviceDate,
      busId: busId ?? this.busId,
      routeId: routeId ?? this.routeId,
      boardingStopId: boardingStopId ?? this.boardingStopId,
      status: status ?? this.status,
      recommendationVersion:
          recommendationVersion ?? this.recommendationVersion,
      scheduledArrival: scheduledArrival ?? this.scheduledArrival,
      busEta: busEta ?? this.busEta,
      scooterDurationSeconds:
          scooterDurationSeconds ?? this.scooterDurationSeconds,
      safetyMarginSeconds: safetyMarginSeconds ?? this.safetyMarginSeconds,
      recommendedLeaveBy: recommendedLeaveBy ?? this.recommendedLeaveBy,
      advanceNotificationStatus:
          advanceNotificationStatus ?? this.advanceNotificationStatus,
      leaveNowStatus: leaveNowStatus ?? this.leaveNowStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
