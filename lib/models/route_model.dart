import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Represents a designated bus route with ordered stops and path geometry.
class RouteModel {
  const RouteModel({
    required this.id,
    required this.name,
    this.direction = 'Outbound',
    this.timeZone = 'Asia/Kolkata',
    this.isActive = true,
    this.orderedStopIds = const [],
    this.geometryVersion = 1,
    this.polylinePoints = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Unique route identifier.
  final String id;

  /// Route display name (e.g. 'Route 1 - Gachibowli to Hitech City').
  final String name;

  /// Travel direction (e.g. 'Morning Commute', 'Inbound', 'Outbound').
  final String direction;

  /// IANA time zone identifier.
  final String timeZone;

  /// Whether the route is currently active.
  final bool isActive;

  /// Ordered stop IDs that define the route traversal sequence.
  final List<String> orderedStopIds;

  /// Revision number of the approved road geometry polyline.
  final int geometryVersion;

  /// Coordinate vertices defining the map path for this route.
  final List<LatLng> polylinePoints;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// Factory constructor to parse a Firestore document snapshot.
  factory RouteModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return RouteModel.fromMap(data, snapshot.id);
  }

  /// Parses from map data.
  factory RouteModel.fromMap(Map<String, dynamic> map, [String id = '']) {
    final rawPoints = map['polylinePoints'] as List? ?? [];
    final points = <LatLng>[];
    for (final item in rawPoints) {
      if (item is Map) {
        final lat = (item['lat'] ?? item['latitude']) as num?;
        final lng = (item['lng'] ?? item['longitude']) as num?;
        if (lat != null && lng != null) {
          points.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      }
    }

    return RouteModel(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? 'Bus Route',
      direction: map['direction'] as String? ?? 'Outbound',
      timeZone: map['timeZone'] as String? ?? 'Asia/Kolkata',
      isActive: map['isActive'] as bool? ?? true,
      orderedStopIds: List<String>.from(map['orderedStopIds'] as List? ?? []),
      geometryVersion: (map['geometryVersion'] as num?)?.toInt() ?? 1,
      polylinePoints: points,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Serializes to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'direction': direction,
      'timeZone': timeZone,
      'isActive': isActive,
      'orderedStopIds': orderedStopIds,
      'geometryVersion': geometryVersion,
      'polylinePoints': polylinePoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  RouteModel copyWith({
    String? id,
    String? name,
    String? direction,
    String? timeZone,
    bool? isActive,
    List<String>? orderedStopIds,
    int? geometryVersion,
    List<LatLng>? polylinePoints,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RouteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      direction: direction ?? this.direction,
      timeZone: timeZone ?? this.timeZone,
      isActive: isActive ?? this.isActive,
      orderedStopIds: orderedStopIds ?? this.orderedStopIds,
      geometryVersion: geometryVersion ?? this.geometryVersion,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
