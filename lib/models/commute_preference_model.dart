import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fibus/core/constants/app_constants.dart';

/// Commuter's saved daily route and boarding stop preferences.
///
/// Stored in Firestore at `commutePreferences/{prefId}`.
class CommutePreferenceModel {
  /// Unique preference record ID (matches document ID).
  final String prefId;

  /// User UID who owns this preference.
  final String uid;

  /// Selected route ID for daily commute.
  final String routeId;

  /// Boarding stop ID along the route.
  final String stopId;

  /// Optional specific bus ID to track (if empty or null, tracks any active bus on the route).
  final String? busId;

  /// Advance warning alert threshold in minutes (e.g. 15 minutes before leave time).
  final int advanceWarningMinutes;

  /// Whether departure alerts and tracking are actively enabled for this preference.
  final bool isActive;

  /// Creation timestamp.
  final DateTime createdAt;

  const CommutePreferenceModel({
    required this.prefId,
    required this.uid,
    required this.routeId,
    required this.stopId,
    this.busId,
    this.advanceWarningMinutes = AppConstants.defaultAdvanceWarningMinutes,
    this.isActive = true,
    required this.createdAt,
  });

  /// Creates a [CommutePreferenceModel] from a Firestore document snapshot.
  factory CommutePreferenceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Cannot create CommutePreferenceModel from empty document snapshot');
    }
    return CommutePreferenceModel.fromMap(data, id: snapshot.id);
  }

  /// Creates a [CommutePreferenceModel] from a key-value map and document ID.
  factory CommutePreferenceModel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parsedCreated;
    if (map['createdAt'] is Timestamp) {
      parsedCreated = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreated = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    } else {
      parsedCreated = DateTime.now();
    }

    return CommutePreferenceModel(
      prefId: id ?? (map['prefId'] as String? ?? ''),
      uid: map['uid'] as String? ?? '',
      routeId: map['routeId'] as String? ?? '',
      stopId: map['stopId'] as String? ?? '',
      busId: map['busId'] as String?,
      advanceWarningMinutes: (map['advanceWarningMinutes'] as num?)?.toInt() ??
          AppConstants.defaultAdvanceWarningMinutes,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: parsedCreated,
    );
  }

  /// Serializes the model for Firestore persistence.
  Map<String, dynamic> toFirestore() {
    return {
      'prefId': prefId,
      'uid': uid,
      'routeId': routeId,
      'stopId': stopId,
      'busId': busId,
      'advanceWarningMinutes': advanceWarningMinutes,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Serializes the model into a standard JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'prefId': prefId,
      'uid': uid,
      'routeId': routeId,
      'stopId': stopId,
      'busId': busId,
      'advanceWarningMinutes': advanceWarningMinutes,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Returns a copy of this [CommutePreferenceModel] with updated properties.
  CommutePreferenceModel copyWith({
    String? prefId,
    String? uid,
    String? routeId,
    String? stopId,
    String? busId,
    int? advanceWarningMinutes,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return CommutePreferenceModel(
      prefId: prefId ?? this.prefId,
      uid: uid ?? this.uid,
      routeId: routeId ?? this.routeId,
      stopId: stopId ?? this.stopId,
      busId: busId ?? this.busId,
      advanceWarningMinutes:
          advanceWarningMinutes ?? this.advanceWarningMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
