
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn;
  final SubscriptionService _subService;
  
  static const String _authKey = 'is_authenticated';

  AuthService(this._subService, this._googleSignIn);

  // Getter for current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email & Password Registration
  Future<UserCredential> registerWithEmail(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _markAuthenticated();
    return credential;
  }

  // Email & Password Login
  Future<UserCredential> loginWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _markAuthenticated();
    return credential;
  }

  // Google Sign-In
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    await _markAuthenticated();
    return userCredential;
  }

  // Log Out
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authKey, false);
  }

  // Reset Password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> _markAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authKey, true);
    await _subService.initTrial();
  }

  Future<bool> isAuthenticated() async {
    if (_auth.currentUser != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authKey) ?? false;
  }


  // Legacy Master Password Check (Keep for fallback or if needed)
  Future<bool> verifyMasterPassword(String password) async {
    const master = '123456';
    final isValid = password == master;
    if (isValid) await _markAuthenticated();
    return isValid;
  }
}
