import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fibus/core/constants/firebase_paths.dart';
import 'package:fibus/models/user_model.dart';

/// Authentication and user identity management service for Fibus.
///
/// Wraps [FirebaseAuth] and [GoogleSignIn] to provide unified sign-in,
/// sign-out, state change broadcasting, and Firestore profile synchronization.
class AuthService extends ChangeNotifier {
  /// Web Client ID configured for Google Sign-In in Firebase console.
  static const String webClientId =
      '704014513974-dvcik8d2fqfqr828ij03l5bdarh82n15.apps.googleusercontent.com';

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  UserModel? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;

  /// Singleton instance.
  static final AuthService _instance = AuthService._internal();

  /// Shared singleton accessor.
  static AuthService get instance => _instance;

  /// Factory accessor returning the singleton or configured instance.
  factory AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  }) {
    if (auth != null || googleSignIn != null || firestore != null) {
      return AuthService._internal(
        auth: auth,
        googleSignIn: googleSignIn,
        firestore: firestore,
      );
    }
    return _instance;
  }

  AuthService._internal({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn =
           googleSignIn ??
           GoogleSignIn(
             serverClientId: webClientId,
             scopes: const ['email', 'profile'],
           ),
       _firestore = firestore ?? FirebaseFirestore.instance {
    _initAuthListener();
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// The currently signed-in Firebase [User], or `null` if unauthenticated.
  User? get currentUser => _auth.currentUser;

  /// Cached Firestore profile model for the current user.
  UserModel? get userProfile => _userProfile;

  /// Whether a user is currently authenticated.
  bool get isAuthenticated => currentUser != null;

  /// Whether an authentication or profile synchronization operation is ongoing.
  bool get isLoading => _isLoading;

  /// Most recent error message encountered during auth operations, if any.
  String? get errorMessage => _errorMessage;

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // Lifecycle & Listeners
  // ---------------------------------------------------------------------------

  void _initAuthListener() {
    _authSubscription = _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _loadUserProfile(user.uid);
      } else {
        _userProfile = null;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In Flow
  // ---------------------------------------------------------------------------

  /// Performs the full Google Sign-In flow using Web Client ID credentials.
  ///
  /// 1. Triggers Google sign-in dialog.
  /// 2. Obtains authentication tokens (ID token & access token).
  /// 3. Signs into [FirebaseAuth] with Google credentials.
  /// 4. Synchronizes the user profile in Cloud Firestore.
  ///
  /// Returns the signed-in [UserModel], or `null` if the user aborted the flow.
  Future<UserModel?> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      // Step 1: Trigger Google Sign-In prompt
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the prompt
        _setLoading(false);
        return null;
      }

      // Step 2: Retrieve authentication tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 3: Sign in to Firebase Auth
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw FirebaseAuthException(
          code: 'USER_NULL',
          message:
              'Firebase user was null after successful credential sign-in.',
        );
      }

      // Step 4: Create or update Firestore profile
      final UserModel profile = await createOrUpdateUserProfile(firebaseUser);
      _userProfile = profile;
      _setLoading(false);
      notifyListeners();
      return profile;
    } on FirebaseAuthException catch (e) {
      _setError('Firebase Auth error: ${e.message ?? e.code}');
      _setLoading(false);
      return null;
    } catch (e) {
      _setError('Unexpected error during Google sign-in: $e');
      _setLoading(false);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Sign Out Flow
  // ---------------------------------------------------------------------------

  /// Signs the user out of both Firebase Auth and Google Sign-In sessions.
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      await Future.wait([_googleSignIn.signOut(), _auth.signOut()]);
      _userProfile = null;
    } catch (e) {
      _setError('Failed to sign out cleanly: $e');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Firestore User Profile Sync
  // ---------------------------------------------------------------------------

  /// Ensures a Firestore user document exists at `users/{uid}` and updates
  /// mutable identity metadata (display name, email, photoUrl, lastSeenAt).
  ///
  /// Preserves existing role and home coordinates if already configured.
  Future<UserModel> createOrUpdateUserProfile(User user) async {
    final userDocRef = _firestore.doc(FirebasePaths.user(user.uid));

    final docSnapshot = await userDocRef.get();

    if (docSnapshot.exists && docSnapshot.data() != null) {
      // Existing profile: update identity fields and last seen timestamp
      final existingData = docSnapshot.data()!;
      final existingModel = UserModel.fromMap(existingData, id: user.uid);

      final updatedModel = existingModel.copyWith(
        displayName: user.displayName ?? existingModel.displayName,
        email: user.email ?? existingModel.email,
        photoUrl: user.photoURL ?? existingModel.photoUrl,
        updatedAt: DateTime.now(),
      );

      await userDocRef.set({
        'displayName': updatedModel.displayName,
        'email': updatedModel.email,
        'photoUrl': updatedModel.photoUrl,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _userProfile = updatedModel;
      return updatedModel;
    } else {
      // New profile: create default record with 'commuter' role
      final newModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoUrl: user.photoURL,
        role: 'commuter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await userDocRef.set({
        ...newModel.toFirestore(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });

      _userProfile = newModel;
      return newModel;
    }
  }

  /// Refreshes the local cached profile from Firestore.
  Future<UserModel?> refreshUserProfile() async {
    final user = currentUser;
    if (user == null) {
      _userProfile = null;
      notifyListeners();
      return null;
    }
    return _loadUserProfile(user.uid);
  }

  Future<UserModel?> _loadUserProfile(String uid) async {
    try {
      final doc = await _firestore.doc(FirebasePaths.user(uid)).get();
      if (doc.exists && doc.data() != null) {
        _userProfile = UserModel.fromFirestore(doc);
      } else if (currentUser != null) {
        _userProfile = await createOrUpdateUserProfile(currentUser!);
      }
      notifyListeners();
      return _userProfile;
    } catch (e) {
      debugPrint('Error loading user profile for $uid: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // State Helpers
  // ---------------------------------------------------------------------------

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
