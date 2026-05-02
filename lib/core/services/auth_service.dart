import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'database_helper.dart';
import 'subscription_service.dart';

class AuthService extends ChangeNotifier {
  final SubscriptionService _subscriptionService;
  final GoogleSignIn _googleSignIn;
  final SharedPreferences _prefs;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  AppUser? _currentUser; 
  User? _firebaseUser;   
  
  AuthService(this._subscriptionService, this._googleSignIn, this._prefs) {
    _firebaseAuth.authStateChanges().listen((User? user) {
      _firebaseUser = user;
      notifyListeners();
    });
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final userId = _prefs.getInt('logged_in_user_id');
    if (userId != null) {
      final db = await _dbHelper.database;
      final maps = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (maps.isNotEmpty) {
        _currentUser = AppUser.fromMap(maps.first);
        notifyListeners();
      }
    }
  }

  Future<bool> isAuthenticated() async {
    // Return true if either a staff is logged in locally or a firebase user is active
    return _currentUser != null || _firebaseUser != null;
  }

  // --- Local RBAC Methods ---
  
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isCashier => _currentUser?.role == UserRole.cashier;
  bool get isWarehouse => _currentUser?.role == UserRole.warehouse;

  Future<bool> login(String username, String password) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    if (maps.isNotEmpty) {
      _currentUser = AppUser.fromMap(maps.first);
      await _prefs.setInt('logged_in_user_id', _currentUser!.id!);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> verifyMasterPassword(String password) async {
    // For compatibility with old screens, check against 'admin' user
    return await login('admin', password);
  }

  Future<void> logout() async {
    _currentUser = null;
    await _prefs.remove('logged_in_user_id');
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
    notifyListeners();
  }

  // --- Firebase / Cloud Methods (from previous implementation) ---

  User? get firebaseUser => _firebaseUser;

  Future<UserCredential> loginWithEmail(String email, String password) async {
    return await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) async {
    return await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      return null;
    }
  }

  // --- Staff Management ---

  Future<List<AppUser>> getAllUsers() async {
    final db = await _dbHelper.database;
    final maps = await db.query('users');
    return maps.map((m) => AppUser.fromMap(m)).toList();
  }

  Future<int> addUser(AppUser user) async {
    final db = await _dbHelper.database;
    return await db.insert('users', user.toMap());
  }

  Future<int> deleteUser(int id) async {
    if (id == 1) return 0; // Protect super admin
    final db = await _dbHelper.database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}
