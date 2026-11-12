import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:fibus/core/constants/app_constants.dart';
import 'package:fibus/core/constants/firebase_paths.dart';
import 'package:fibus/models/alert_session.dart';
import 'package:fibus/models/bus_model.dart';
import 'package:fibus/models/commute_preference.dart';
import 'package:fibus/models/operator_assignment_model.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/models/stop_model.dart';
import 'package:fibus/models/stop_time_model.dart';
import 'package:fibus/models/user_model.dart';

/// Comprehensive Cloud Firestore CRUD service for the Fibus ecosystem.
///
/// Encapsulates all query operations and document persistence for:
/// - Users (`users`)
/// - Buses (`buses`)
/// - Routes (`routes`)
/// - Stops (`stops`)
/// - Stop Times / Timetables (`stopTimes`)
/// - Commute Preferences (`commutePreferences`)
/// - Alert Sessions (`alertSessions`)
/// - Operator Assignments (`operatorAssignments`)
class FirestoreService {
  final FirebaseFirestore _firestore;

  /// Singleton instance.
  static final FirestoreService _instance = FirestoreService._internal();

  /// Shared singleton accessor.
  static FirestoreService get instance => _instance;

  /// Factory constructor returning the singleton or injected instance.
  factory FirestoreService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      return FirestoreService._internal(firestore: firestore);
    }
    return _instance;
  }

  FirestoreService._internal({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Waits for a write to reach the server, but not forever.
  ///
  /// Firestore applies a write to its on-device cache at once and only
  /// completes the future when the server confirms it, which never happens
  /// while offline. After [AppConstants.saveTimeout] the write is treated as
  /// saved: it is in the cache and syncs when the network returns. A real
  /// rejection (for example by the security rules) still throws.
  Future<void> _commit(Future<void> write) => write.timeout(
        AppConstants.saveTimeout,
        onTimeout: () => debugPrint('Firestore write queued for sync'),
      );

  // ---------------------------------------------------------------------------
  // User Profile CRUD
  // ---------------------------------------------------------------------------

  /// Retrieves a user document by Firebase Auth UID.
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.doc(FirebasePaths.user(uid)).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('FirestoreService.getUser error ($uid): $e');
      rethrow;
    }
  }

  /// Creates or updates a full user record in `users/{uid}`.
  Future<void> saveUser(UserModel user) async {
    try {
      await _firestore.doc(FirebasePaths.user(user.uid)).set(
            user.toFirestore(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('FirestoreService.saveUser error (${user.uid}): $e');
      rethrow;
    }
  }

  /// Updates existing user profile fields (displayName, email, photoUrl, role).
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore.doc(FirebasePaths.user(user.uid)).update({
        'displayName': user.displayName,
        'email': user.email,
        'photoUrl': user.photoUrl,
        'role': user.role,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirestoreService.updateUserProfile error (${user.uid}): $e');
      rethrow;
    }
  }

  /// Updates the commuter's saved home pin coordinates.
  Future<void> updateHomeLocation(
    String uid,
    double latitude,
    double longitude,
  ) async {
    try {
      await _firestore.doc(FirebasePaths.user(uid)).set({
        'homeLocation': GeoPoint(latitude, longitude),
        'homeLat': latitude,
        'homeLng': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreService.updateHomeLocation error ($uid): $e');
      rethrow;
    }
  }

  /// Updates the device's FCM push notification token.
  Future<void> updateFcmToken(String uid, String token) async {
    try {
      await _firestore.doc(FirebasePaths.user(uid)).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreService.updateFcmToken error ($uid): $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Bus Queries
  // ---------------------------------------------------------------------------

  /// Retrieves a single bus by ID.
  Future<BusModel?> getBus(String busId) async {
    try {
      final doc = await _firestore.doc(FirebasePaths.bus(busId)).get();
      if (!doc.exists || doc.data() == null) return null;
      return BusModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('FirestoreService.getBus error ($busId): $e');
      rethrow;
    }
  }

  /// Fetches all active buses in the fleet.
  Future<List<BusModel>> getAllActiveBuses() async {
    try {
      final snapshot = await _firestore
          .collection(FirebasePaths.busesCollection)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => BusModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('FirestoreService.getAllActiveBuses error: $e');
      rethrow;
    }
  }

  /// Fetches buses assigned to a specific route ID.
  Future<List<BusModel>> getBusesByRoute(String routeId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebasePaths.busesCollection)
          .where('routeIds', arrayContains: routeId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => BusModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('FirestoreService.getBusesByRoute error ($routeId): $e');
      rethrow;
    }
  }

  /// Alias of [getBusesByRoute] used by the commuter app.
  Future<List<BusModel>> getBusesForRoute(String routeId) =>
      getBusesByRoute(routeId);

  /// Real-time stream of all active buses.
  Stream<List<BusModel>> streamActiveBuses() {
    return _firestore
        .collection(FirebasePaths.busesCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BusModel.fromFirestore(doc)).toList());
  }

  /// Real-time stream of all registered buses.
  Stream<List<BusModel>> streamAllBuses() {
    return _firestore
        .collection(FirebasePaths.busesCollection)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BusModel.fromFirestore(doc)).toList());
  }

  // ---------------------------------------------------------------------------
  // Route Queries
  // ---------------------------------------------------------------------------

  /// Retrieves a specific bus route by ID.
  Future<RouteModel?> getRoute(String routeId) async {
    try {
      final doc = await _firestore.doc(FirebasePaths.route(routeId)).get();
      if (!doc.exists || doc.data() == null) return null;
      return RouteModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('FirestoreService.getRoute error ($routeId): $e');
      rethrow;
    }
  }

  /// Fetches all registered bus routes.
  Future<List<RouteModel>> getAllRoutes() async {
    try {
      final snapshot =
          await _firestore.collection(FirebasePaths.routesCollection).get();

      return snapshot.docs
          .map((doc) => RouteModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('FirestoreService.getAllRoutes error: $e');
      rethrow;
    }
  }

  /// Fetches routes currently open for commuter selection.
  Future<List<RouteModel>> getActiveRoutes() async {
    try {
      final snapshot = await _firestore
          .collection(FirebasePaths.routesCollection)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => RouteModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('FirestoreService.getActiveRoutes error: $e');
      rethrow;
    }
  }

  /// Real-time stream of all routes.
  Stream<List<RouteModel>> streamRoutes() {
    return _firestore
        .collection(FirebasePaths.routesCollection)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList());
  }

  // ---------------------------------------------------------------------------
  // Stop Queries
  // ---------------------------------------------------------------------------

  /// Retrieves a specific stop by ID.
  Future<StopModel?> getStop(String stopId) async {
    try {
      final doc = await _firestore.doc(FirebasePaths.stop(stopId)).get();
      if (!doc.exists || doc.data() == null) return null;
      return StopModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('FirestoreService.getStop error ($stopId): $e');
      rethrow;
    }
  }

  /// Retrieves the stops of [route] in the order given by `orderedStopIds`.
  Future<List<StopModel>> getStopsForRoute(RouteModel route) async {
    try {
      final ids = route.orderedStopIds;
      if (ids.isEmpty) return [];

      // Firestore `whereIn` accepts at most 30 values per query.
      final byId = <String, StopModel>{};
      for (var i = 0; i < ids.length; i += 30) {
        final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
        final snapshot = await _firestore
            .collection(FirebasePaths.stopsCollection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          byId[doc.id] = StopModel.fromFirestore(doc);
        }
      }

      return [
        for (final id in ids)
          if (byId[id] != null) byId[id]!,
      ];
    } catch (e) {
      debugPrint('FirestoreService.getStopsForRoute error (${route.id}): $e');
      rethrow;
    }
  }

  /// Retrieves the ordered stops for the route with [routeId].
  Future<List<StopModel>> getStopsByRoute(String routeId) async {
    final route = await getRoute(routeId);
    if (route == null) return [];
    return getStopsForRoute(route);
  }

  /// Retrieves all bus stops across the entire network.
  Future<List<StopModel>> getAllStops() async {
    try {
      final snapshot =
          await _firestore.collection(FirebasePaths.stopsCollection).get();

      return snapshot.docs.map((doc) => StopModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('FirestoreService.getAllStops error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // StopTime Queries
  // ---------------------------------------------------------------------------

  /// Fetches scheduled stop times for a specific route.
  Future<List<StopTimeModel>> getStopTimesByRoute(String routeId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebasePaths.stopTimesCollection)
          .where('routeId', isEqualTo: routeId)
          .get();

      final list =
          snapshot.docs.map((doc) => StopTimeModel.fromFirestore(doc)).toList();
      list.sort((a, b) => a.scheduledArrival.compareTo(b.scheduledArrival));
      return list;
    } catch (e) {
      debugPrint('FirestoreService.getStopTimesByRoute error ($routeId): $e');
      rethrow;
    }
  }

  /// Fetches scheduled timetable for a specific stop across all routes.
  Future<List<StopTimeModel>> getStopTimesByStop(String stopId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebasePaths.stopTimesCollection)
          .where('stopId', isEqualTo: stopId)
          .get();

      final list =
          snapshot.docs.map((doc) => StopTimeModel.fromFirestore(doc)).toList();
      list.sort((a, b) => a.scheduledArrival.compareTo(b.scheduledArrival));
      return list;
    } catch (e) {
      debugPrint('FirestoreService.getStopTimesByStop error ($stopId): $e');
      rethrow;
    }
  }

  /// Retrieves the specific scheduled timetable record for a stop along a route.
  Future<StopTimeModel?> getStopTime(String routeId, String stopId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebasePaths.stopTimesCollection)
          .where('routeId', isEqualTo: routeId)
          .where('stopId', isEqualTo: stopId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return StopTimeModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint('FirestoreService.getStopTime error ($routeId, $stopId): $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Commute Preference CRUD
  // ---------------------------------------------------------------------------

  /// Retrieves the commuter's saved preference from
  /// `users/{uid}/commutePreferences/primary`.
  Future<CommutePreference?> getCommutePreference(String uid) async {
    try {
      final doc =
          await _firestore.doc(FirebasePaths.primaryCommutePreference(uid)).get();
      if (!doc.exists || doc.data() == null) return null;
      return CommutePreference.fromFirestore(doc);
    } catch (e) {
      debugPrint('FirestoreService.getCommutePreference error ($uid): $e');
      rethrow;
    }
  }

  /// Saves or updates the commuter's primary preference document.
  Future<void> saveCommutePreference(CommutePreference preference) async {
    try {
      await _commit(_firestore
          .doc(FirebasePaths.primaryCommutePreference(preference.userId))
          .set(preference.toFirestore(), SetOptions(merge: true)));
    } catch (e) {
      debugPrint('FirestoreService.saveCommutePreference error: $e');
      rethrow;
    }
  }

  /// Saves only the home pin onto the commuter's primary preference.
  Future<void> saveHomePin(String uid, double latitude, double longitude) async {
    try {
      await _commit(
          _firestore.doc(FirebasePaths.primaryCommutePreference(uid)).set({
        'userId': uid,
        'homeLatitude': latitude,
        'homeLongitude': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)));
    } catch (e) {
      debugPrint('FirestoreService.saveHomePin error ($uid): $e');
      rethrow;
    }
  }

  /// Deletes the commuter's saved preference (home pin and commute).
  Future<void> deleteCommutePreference(String uid) async {
    try {
      await _firestore.doc(FirebasePaths.primaryCommutePreference(uid)).delete();
    } catch (e) {
      debugPrint('FirestoreService.deleteCommutePreference error ($uid): $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Alert Session CRUD
  // ---------------------------------------------------------------------------

  /// Session states in which departure alerts are still pending.
  static const List<String> _activeAlertStates = [
    'monitoring',
    'advance_sent',
    'leave_now_sent',
  ];

  /// Creates a new departure alert session and returns the generated session ID.
  Future<String> createAlertSession(AlertSession session) async {
    try {
      final docRef = _firestore
          .collection(FirebasePaths.alertSessionsCollection)
          .doc(session.id.isNotEmpty ? session.id : null);
      await _commit(docRef.set(session.toFirestore()));
      return docRef.id;
    } catch (e) {
      debugPrint('FirestoreService.createAlertSession error: $e');
      rethrow;
    }
  }

  /// Marks an alert session as cancelled by the commuter.
  Future<void> cancelAlertSession(String sessionId) async {
    try {
      await _commit(
          _firestore.doc(FirebasePaths.alertSession(sessionId)).update({
        'status': AlertSessionStatus.cancelled.toValue(),
        'updatedAt': FieldValue.serverTimestamp(),
      }));
    } catch (e) {
      debugPrint('FirestoreService.cancelAlertSession error ($sessionId): $e');
      rethrow;
    }
  }

  /// Updates an alert session document.
  Future<void> updateAlertSession(AlertSession session) async {
    try {
      await _commit(_firestore
          .doc(FirebasePaths.alertSession(session.id))
          .set(session.toFirestore(), SetOptions(merge: true)));
    } catch (e) {
      debugPrint('FirestoreService.updateAlertSession error (${session.id}): $e');
      rethrow;
    }
  }

  /// Real-time stream of the commuter's active alert session for [serviceDate].
  Stream<AlertSession?> streamActiveAlertSession(String uid, String serviceDate) {
    return _firestore
        .collection(FirebasePaths.alertSessionsCollection)
        .where('commuterUid', isEqualTo: uid)
        .where('serviceDate', isEqualTo: serviceDate)
        .where('status', whereIn: _activeAlertStates)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return AlertSession.fromFirestore(snapshot.docs.first);
    });
  }

  // ---------------------------------------------------------------------------
  // Operator Assignment Queries
  // ---------------------------------------------------------------------------

  /// Fetches all active bus assignments for a given operator UID.
  Future<List<OperatorAssignmentModel>> getAssignmentsForOperator(
    String operatorUid,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(FirebasePaths.operatorAssignmentsCollection)
          .where('operatorUid', isEqualTo: operatorUid)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => OperatorAssignmentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint(
          'FirestoreService.getAssignmentsForOperator error ($operatorUid): $e');
      rethrow;
    }
  }

  /// Checks if a designated operator is authorized to track a given bus.
  Future<bool> isOperatorAssignedToBus(
    String operatorUid,
    String busId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(FirebasePaths.operatorAssignmentsCollection)
          .where('operatorUid', isEqualTo: operatorUid)
          .where('busId', isEqualTo: busId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) return true;

      // Fallback: Check bus document's operatorUids array
      final busDoc = await getBus(busId);
      if (busDoc != null && busDoc.operatorUids.contains(operatorUid)) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint(
          'FirestoreService.isOperatorAssignedToBus error ($operatorUid, $busId): $e');
      return false;
    }
  }

  /// Retrieves an assignment record for a specific bus and operator.
  Future<OperatorAssignmentModel?> getAssignment(
    String busId,
    String operatorUid,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(FirebasePaths.operatorAssignmentsCollection)
          .where('busId', isEqualTo: busId)
          .where('operatorUid', isEqualTo: operatorUid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return OperatorAssignmentModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint(
          'FirestoreService.getAssignment error ($busId, $operatorUid): $e');
      rethrow;
    }
  }

  /// Fetches all active assignments in the system.
  Future<List<OperatorAssignmentModel>> getAllActiveAssignments() async {
    try {
      final snapshot = await _firestore
          .collection(FirebasePaths.operatorAssignmentsCollection)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => OperatorAssignmentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('FirestoreService.getAllActiveAssignments error: $e');
      rethrow;
    }
  }
}
