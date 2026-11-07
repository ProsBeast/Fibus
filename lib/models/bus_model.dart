import 'package:cloud_firestore/cloud_firestore.dart';

/// Bus entity representing a physical bus tracked in the Fibus system.
class BusModel {
  const BusModel({
    required this.id,
    required this.displayName,
    this.routeIds = const [],
    this.isActive = true,
    this.operatorUids = const [],
    this.trackerReminderTime = '07:15',
    this.serviceDays = const [1, 2, 3, 4, 5],
    this.timeZone = 'Asia/Kolkata',
    this.createdAt,
    this.updatedAt,
  });

  /// Unique identifier of the bus document in Firestore.
  final String id;

  /// Human-readable label (e.g. 'Campus Express #4', 'Bus 42').
  final String displayName;

  /// IDs of routes this bus is assigned to.
  final List<String> routeIds;

  /// Whether this bus is currently active in the fleet.
  final bool isActive;

  /// UIDs of operators allowed to track this bus.
  final List<String> operatorUids;

  /// Configured local time string (HH:mm) when operators receive tracking reminders.
  final String trackerReminderTime;

  /// Days of the week the bus operates (1 = Monday, 7 = Sunday).
  final List<int> serviceDays;

  /// Local IANA time zone identifier (defaults to 'Asia/Kolkata').
  final String timeZone;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last modification timestamp.
  final DateTime? updatedAt;

  /// Creates a [BusModel] instance from a Firestore document snapshot.
  factory BusModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return BusModel.fromMap(data, snapshot.id);
  }

  /// Creates a [BusModel] from a raw map and optional ID.
  factory BusModel.fromMap(Map<String, dynamic> map, [String id = '']) {
    return BusModel(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      displayName: map['displayName'] as String? ?? 'Bus',
      routeIds: List<String>.from(map['routeIds'] as List? ?? []),
      isActive: map['isActive'] as bool? ?? true,
      operatorUids: List<String>.from(map['operatorUids'] as List? ?? []),
      trackerReminderTime: map['trackerReminderTime'] as String? ?? '07:15',
      // ISO weekdays (Mon = 1 … Sun = 7); ignore any non-numeric entries.
      serviceDays: (map['serviceDays'] as List?)
              ?.whereType<num>()
              .map((d) => d.toInt())
              .toList() ??
          const [1, 2, 3, 4, 5],
      timeZone: map['timeZone'] as String? ?? 'Asia/Kolkata',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Converts this [BusModel] to a Firestore map representation.
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'routeIds': routeIds,
      'isActive': isActive,
      'operatorUids': operatorUids,
      'trackerReminderTime': trackerReminderTime,
      'serviceDays': serviceDays,
      'timeZone': timeZone,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Returns a copy of this [BusModel] with given fields updated.
  BusModel copyWith({
    String? id,
    String? displayName,
    List<String>? routeIds,
    bool? isActive,
    List<String>? operatorUids,
    String? trackerReminderTime,
    List<int>? serviceDays,
    String? timeZone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      routeIds: routeIds ?? this.routeIds,
      isActive: isActive ?? this.isActive,
      operatorUids: operatorUids ?? this.operatorUids,
      trackerReminderTime: trackerReminderTime ?? this.trackerReminderTime,
      serviceDays: serviceDays ?? this.serviceDays,
      timeZone: timeZone ?? this.timeZone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
