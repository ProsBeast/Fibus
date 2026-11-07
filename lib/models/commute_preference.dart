import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// User's saved commute preferences (home location, chosen route, bus, boarding stop,
/// and advance alert lead time).
class CommutePreference {
  const CommutePreference({
    required this.id,
    required this.userId,
    required this.homeLatitude,
    required this.homeLongitude,
    required this.busId,
    required this.routeId,
    required this.boardingStopId,
    this.busName = '',
    this.routeName = '',
    this.boardingStopName = '',
    this.advanceWarningMinutes = 10,
    this.isEnabled = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Preference document ID.
  final String id;

  /// Firebase Auth UID of the commuter.
  final String userId;

  /// Commuter's pinned home latitude.
  final double homeLatitude;

  /// Commuter's pinned home longitude.
  final double homeLongitude;

  /// Selected bus ID.
  final String busId;

  /// Cached bus display name.
  final String busName;

  /// Selected route ID.
  final String routeId;

  /// Cached route display name.
  final String routeName;

  /// Selected boarding stop ID.
  final String boardingStopId;

  /// Cached boarding stop display name.
  final String boardingStopName;

  /// Advance warning lead time in minutes before recommended departure (5-30 min).
  final int advanceWarningMinutes;

  /// Whether active alerts are enabled for this preference.
  final bool isEnabled;

  /// Timestamp when saved.
  final DateTime? createdAt;

  /// Timestamp when last updated.
  final DateTime? updatedAt;

  /// Convenience LatLng for the home pin.
  LatLng get homeLocation => LatLng(homeLatitude, homeLongitude);

  /// Checks if home coordinates are set (non-zero).
  bool get hasHomePin => homeLatitude != 0.0 && homeLongitude != 0.0;

  /// Checks if all commute details (bus, route, stop) are configured.
  bool get isFullyConfigured =>
      hasHomePin &&
      busId.isNotEmpty &&
      routeId.isNotEmpty &&
      boardingStopId.isNotEmpty;

  /// Factory constructor for Firestore documents.
  factory CommutePreference.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return CommutePreference.fromMap(data, snapshot.id);
  }

  /// Parses from a map.
  factory CommutePreference.fromMap(Map<String, dynamic> map, [String id = '']) {
    return CommutePreference(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      userId: map['userId'] as String? ?? '',
      homeLatitude: (map['homeLatitude'] as num?)?.toDouble() ?? 0.0,
      homeLongitude: (map['homeLongitude'] as num?)?.toDouble() ?? 0.0,
      busId: map['busId'] as String? ?? '',
      busName: map['busName'] as String? ?? '',
      routeId: map['routeId'] as String? ?? '',
      routeName: map['routeName'] as String? ?? '',
      boardingStopId: map['boardingStopId'] as String? ?? '',
      boardingStopName: map['boardingStopName'] as String? ?? '',
      advanceWarningMinutes: (map['advanceWarningMinutes'] as num?)?.toInt() ?? 10,
      isEnabled: map['isEnabled'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Serializes to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'homeLatitude': homeLatitude,
      'homeLongitude': homeLongitude,
      'busId': busId,
      'busName': busName,
      'routeId': routeId,
      'routeName': routeName,
      'boardingStopId': boardingStopId,
      'boardingStopName': boardingStopName,
      'advanceWarningMinutes': advanceWarningMinutes,
      'isEnabled': isEnabled,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CommutePreference copyWith({
    String? id,
    String? userId,
    double? homeLatitude,
    double? homeLongitude,
    String? busId,
    String? busName,
    String? routeId,
    String? routeName,
    String? boardingStopId,
    String? boardingStopName,
    int? advanceWarningMinutes,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommutePreference(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      homeLatitude: homeLatitude ?? this.homeLatitude,
      homeLongitude: homeLongitude ?? this.homeLongitude,
      busId: busId ?? this.busId,
      busName: busName ?? this.busName,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      boardingStopId: boardingStopId ?? this.boardingStopId,
      boardingStopName: boardingStopName ?? this.boardingStopName,
      advanceWarningMinutes:
          advanceWarningMinutes ?? this.advanceWarningMinutes,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
