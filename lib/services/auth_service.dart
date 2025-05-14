import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Stream of user authentication state
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors (e.g., user-not-found, wrong-password)
      print('Firebase Auth Exception (Sign In): ${e.code} - ${e.message}');
      throw e; // Re-throw to be caught by UI
    } catch (e) {
      print('Generic Exception (Sign In): $e');
      throw Exception('An unexpected error occurred during sign in.');
    }
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Optional: Send email verification
      // await userCredential.user?.sendEmailVerification();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors (e.g., email-already-in-use, weak-password)
      print('Firebase Auth Exception (Sign Up): ${e.code} - ${e.message}');
      throw e; // Re-throw to be caught by UI
    } catch (e) {
      print('Generic Exception (Sign Up): $e');
      throw Exception('An unexpected error occurred during sign up.');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      print('Exception (Sign Out): $e');
      throw Exception('An unexpected error occurred during sign out.');
    }
  }
}