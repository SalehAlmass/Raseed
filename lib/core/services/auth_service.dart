import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'database_helper.dart';
import 'subscription_service.dart';

class AuthService extends ChangeNotifier {
  final SubscriptionService _subscriptionService;
  final GoogleSignIn _googleSignIn;
  final SharedPreferences _prefs;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  AppUser? _currentUser; 
  late Future<void> initialization;
  
  AuthService(this._subscriptionService, this._googleSignIn, this._prefs) {
    initialization = _tryAutoLogin();
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
    // Return true if a staff is logged in locally
    return _currentUser != null;
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
    await _googleSignIn.signOut();
    notifyListeners();
  }

  // --- Firebase / Cloud Methods (from previous implementation) ---

  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      return googleUser;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      return null;
    }
  }

  // --- Google Drive Support ---
  GoogleSignIn get googleSignIn => _googleSignIn;
  GoogleSignInAccount? get googleUser => _googleSignIn.currentUser;

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
