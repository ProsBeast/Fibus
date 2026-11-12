import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// User profile representation in Fibus.
///
/// Stored in Firestore at `users/{uid}`.
class UserModel {
  /// Firebase Auth UID matching the document ID.
  final String uid;

  /// User email address.
  final String email;

  /// Full display name.
  final String? displayName;

  /// Profile photo URL (from Google Auth or custom upload).
  final String? photoUrl;

  /// Application role: 'commuter', 'operator', or 'both'.
  final String role;

  /// Commuter's home coordinate used for scooter ETA and departure calculations.
  final LatLng? homeLatLng;

  /// Account creation timestamp.
  final DateTime createdAt;

  /// Profile last update timestamp.
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.role = 'commuter',
    this.homeLatLng,
    required this.createdAt,
    this.updatedAt,
  });

  /// Whether user has commuter permissions.
  bool get isCommuter => role == 'commuter' || role == 'both';

  /// Whether user has bus operator / tracker permissions.
  bool get isOperator => role == 'operator' || role == 'both';

  /// Creates a [UserModel] from a Firestore document snapshot.
  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Cannot create UserModel from empty document snapshot');
    }
    return UserModel.fromMap(data, id: snapshot.id);
  }

  /// Creates a [UserModel] from a key-value map and document ID.
  factory UserModel.fromMap(Map<String, dynamic> map, {String? id}) {
    LatLng? parsedHome;
    if (map['homeLocation'] is GeoPoint) {
      final gp = map['homeLocation'] as GeoPoint;
      parsedHome = LatLng(gp.latitude, gp.longitude);
    } else if (map['homeLocation'] is Map) {
      final locMap = map['homeLocation'] as Map;
      final lat = (locMap['latitude'] as num?)?.toDouble();
      final lng = (locMap['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        parsedHome = LatLng(lat, lng);
      }
    } else if (map['homeLat'] != null && map['homeLng'] != null) {
      final lat = (map['homeLat'] as num).toDouble();
      final lng = (map['homeLng'] as num).toDouble();
      parsedHome = LatLng(lat, lng);
    }

    DateTime parsedCreated;
    if (map['createdAt'] is Timestamp) {
      parsedCreated = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreated = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    } else {
      parsedCreated = DateTime.now();
    }

    DateTime? parsedUpdated;
    if (map['updatedAt'] is Timestamp) {
      parsedUpdated = (map['updatedAt'] as Timestamp).toDate();
    } else if (map['updatedAt'] is String) {
      parsedUpdated = DateTime.tryParse(map['updatedAt']);
    }

    return UserModel(
      uid: id ?? (map['uid'] as String? ?? ''),
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      role: map['role'] as String? ?? 'commuter',
      homeLatLng: parsedHome,
      createdAt: parsedCreated,
      updatedAt: parsedUpdated,
    );
  }

  /// Serializes the model for Firestore persistence.
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role,
      'homeLocation': homeLatLng != null
          ? GeoPoint(homeLatLng!.latitude, homeLatLng!.longitude)
          : null,
      'homeLat': homeLatLng?.latitude,
      'homeLng': homeLatLng?.longitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// Serializes the model into a standard JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role,
      'homeLat': homeLatLng?.latitude,
      'homeLng': homeLatLng?.longitude,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Returns a copy of this [UserModel] with updated properties.
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? role,
    LatLng? homeLatLng,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      homeLatLng: homeLatLng ?? this.homeLatLng,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
