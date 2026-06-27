import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';

/// Wraps [FirebaseAuth] and [FirebaseFirestore] operations for authentication.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Emits [User] whenever auth state changes (login / logout).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently signed-in Firebase user (nullable).
  User? get currentUser => _auth.currentUser;

  /// Real-time stream of all other registered users.
  Stream<List<UserModel>> get otherUsersStream {
    final myUid = currentUser?.uid;
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .where((user) => user.uid != myUid)
          .toList();
    });
  }

  // ── Online Status Presence ──────────────────────────────────────────────────

  /// Updates the currently logged-in user's online status in Firestore.
  Future<void> updateOnlineStatus(bool isOnline) async {
    final uid = currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': isOnline,
      });
    }
  }

  // ── Sign Up ────────────────────────────────────────────────────────────────

  /// Creates a new account with email + password.
  ///
  /// On success, stores the user's [displayName] and [uid] in Firestore under
  /// `users/{uid}`.
  ///
  /// Throws a [FirebaseAuthException] on failure (caller should handle).
  Future<UserModel> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    // 1. Create Firebase Auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user!;

    // 2. Update Firebase Auth profile displayName
    await user.updateDisplayName(displayName.trim());

    // 3. Persist user record in Firestore `users` collection
    final userModel = UserModel(
      uid: user.uid,
      displayName: displayName.trim(),
      isOnline: true,
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(userModel.toMap());

    return userModel;
  }

  // ── Sign In ────────────────────────────────────────────────────────────────

  /// Signs in with email + password.
  ///
  /// Throws a [FirebaseAuthException] on failure (caller should handle).
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user!;

    // Update online status
    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': true,
    });

    // Fetch user record from Firestore
    final doc =
        await _firestore.collection('users').doc(user.uid).get();

    if (doc.exists) {
      return UserModel.fromMap(user.uid, doc.data()!);
    }

    // Fallback: construct from Auth profile if Firestore doc is missing
    return UserModel(
      uid: user.uid,
      displayName: user.displayName ?? email.trim(),
      isOnline: true,
    );
  }

  /// Signs in with Google.
  Future<UserModel> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(code: 'ERROR_ABORTED_BY_USER', message: 'Sign in aborted by user');
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;

    final doc = await _firestore.collection('users').doc(user.uid).get();

    UserModel userModel;
    if (doc.exists) {
      userModel = UserModel.fromMap(user.uid, doc.data()!);
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': true,
      });
    } else {
      userModel = UserModel(
        uid: user.uid,
        displayName: user.displayName ?? 'Google User',
        isOnline: true,
      );
      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
    }

    return userModel;
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await updateOnlineStatus(false);
    await _auth.signOut();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns a human-readable error message for common [FirebaseAuthException]
  /// error codes.
  static String friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'An unexpected error occurred.';
    }
  }
}
