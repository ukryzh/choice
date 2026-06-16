import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthProvider { google, none }

class AuthResult {
  const AuthResult({
    required this.provider,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.userId,
  });

  final AuthProvider provider;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? userId;
}

class AuthService {
  AuthService({
    GoogleSignIn? googleSignIn,
    FirebaseAuth? firebaseAuth,
  })  : _googleSignIn = googleSignIn ?? GoogleSignIn(
          scopes: ['email', 'profile'],
        ),
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn;
  final FirebaseAuth _firebaseAuth;

  /// Get current Firebase user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Get current user ID from Firebase
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  Future<AuthResult?> signInWithGoogle() async {
    try {
      // Step 1: Sign in with Google
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // Step 2: Get authentication details from Google
      final googleAuth = await googleUser.authentication;

      // Step 3: Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 4: Sign in to Firebase with Google credential
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Firebase authentication failed');
      }

      final email = firebaseUser.email;
      final displayName = firebaseUser.displayName ?? '';
      
      if (email == null || email.isEmpty) {
        throw Exception('Email not available from Firebase account');
      }

      return AuthResult(
        provider: AuthProvider.google,
        email: email,
        displayName: displayName,
        photoUrl: firebaseUser.photoURL,
        userId: firebaseUser.uid,
      );
    } catch (e) {
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  Future<void> signOut() async {
    try {
      // Sign out from Firebase
      await _firebaseAuth.signOut();
      // Sign out from Google
      await _googleSignIn.signOut();
    } catch (e) {
      // Ignore errors during sign out
    }
  }

  Future<bool> isSignedIn() async {
    try {
      // Check Firebase authentication status
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        return true;
      }
      
      // Fallback: check Google Sign In status
      final account = await _googleSignIn.signInSilently();
      return account != null;
    } catch (e) {
      return false;
    }
  }

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
}









