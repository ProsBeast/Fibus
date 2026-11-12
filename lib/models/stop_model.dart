import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Bus stop model representing an official boarding/alighting location.
class StopModel {
  const StopModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.sequenceIndex = 0,
    this.scheduledArrivalLocalTime = '07:50',
    this.isActive = true,
  });

  /// Unique stop identifier.
  final String id;

  /// Human-readable name of the stop (e.g. 'Main Gate', 'Cyber Towers').
  final String name;

  /// Geographic latitude.
  final double latitude;

  /// Geographic longitude.
  final double longitude;

  /// Relative sequence position along a given route.
  final int sequenceIndex;

  /// Published timetable arrival time (HH:mm format).
  final String scheduledArrivalLocalTime;

  /// Whether this stop is actively serviced.
  final bool isActive;

  /// Convenience LatLng coordinate.
  LatLng get location => LatLng(latitude, longitude);

  /// Factory constructor for Firestore documents.
  factory StopModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return StopModel.fromMap(data, snapshot.id);
  }

  /// Parses stop from raw map and optional ID.
  factory StopModel.fromMap(Map<String, dynamic> map, [String id = '']) {
    return StopModel(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? 'Bus Stop',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 17.3850,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 78.4867,
      sequenceIndex: (map['sequenceIndex'] as num?)?.toInt() ?? 0,
      scheduledArrivalLocalTime:
          map['scheduledArrivalLocalTime'] as String? ?? '07:50',
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  /// Converts this stop to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'sequenceIndex': sequenceIndex,
      'scheduledArrivalLocalTime': scheduledArrivalLocalTime,
      'isActive': isActive,
    };
  }

  StopModel copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    int? sequenceIndex,
    String? scheduledArrivalLocalTime,
    bool? isActive,
  }) {
    return StopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      sequenceIndex: sequenceIndex ?? this.sequenceIndex,
      scheduledArrivalLocalTime:
          scheduledArrivalLocalTime ?? this.scheduledArrivalLocalTime,
      isActive: isActive ?? this.isActive,
    );
  }
}
