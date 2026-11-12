import 'package:cloud_firestore/cloud_firestore.dart';

/// Authorization record granting an operator permission to track and broadcast for a bus.
///
/// Stored in Firestore at `operatorAssignments/{assignmentId}`.
class OperatorAssignmentModel {
  /// Unique assignment record ID (matches document ID).
  final String assignmentId;

  /// Operator's Firebase Auth UID.
  final String operatorUid;

  /// Assigned bus ID that the operator is permitted to track.
  final String busId;

  /// Administrator or supervisor UID who issued this assignment.
  final String assignedBy;

  /// Assignment timestamp.
  final DateTime assignedAt;

  /// Whether this authorization assignment is currently valid and active.
  final bool isActive;

  const OperatorAssignmentModel({
    required this.assignmentId,
    required this.operatorUid,
    required this.busId,
    required this.assignedBy,
    required this.assignedAt,
    this.isActive = true,
  });

  /// Creates an [OperatorAssignmentModel] from a Firestore document snapshot.
  factory OperatorAssignmentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError(
        'Cannot create OperatorAssignmentModel from empty document snapshot',
      );
    }
    return OperatorAssignmentModel.fromMap(data, id: snapshot.id);
  }

  /// Creates an [OperatorAssignmentModel] from a key-value map and document ID.
  factory OperatorAssignmentModel.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    DateTime parsedAssigned;
    if (map['assignedAt'] is Timestamp) {
      parsedAssigned = (map['assignedAt'] as Timestamp).toDate();
    } else if (map['assignedAt'] is String) {
      parsedAssigned = DateTime.tryParse(map['assignedAt']) ?? DateTime.now();
    } else {
      parsedAssigned = DateTime.now();
    }

    return OperatorAssignmentModel(
      assignmentId: id ?? (map['assignmentId'] as String? ?? ''),
      operatorUid: map['operatorUid'] as String? ?? '',
      busId: map['busId'] as String? ?? '',
      assignedBy: map['assignedBy'] as String? ?? '',
      assignedAt: parsedAssigned,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  /// Serializes the model for Firestore persistence.
  Map<String, dynamic> toFirestore() {
    return {
      'assignmentId': assignmentId,
      'operatorUid': operatorUid,
      'busId': busId,
      'assignedBy': assignedBy,
      'assignedAt': Timestamp.fromDate(assignedAt),
      'isActive': isActive,
    };
  }

  /// Serializes the model into a standard JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignmentId,
      'operatorUid': operatorUid,
      'busId': busId,
      'assignedBy': assignedBy,
      'assignedAt': assignedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Returns a copy of this [OperatorAssignmentModel] with updated properties.
  OperatorAssignmentModel copyWith({
    String? assignmentId,
    String? operatorUid,
    String? busId,
    String? assignedBy,
    DateTime? assignedAt,
    bool? isActive,
  }) {
    return OperatorAssignmentModel(
      assignmentId: assignmentId ?? this.assignmentId,
      operatorUid: operatorUid ?? this.operatorUid,
      busId: busId ?? this.busId,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedAt: assignedAt ?? this.assignedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
