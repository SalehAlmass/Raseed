import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // MASTER PASSWORD PLACEHOLDER (You can change this later)
  static const String _masterPassword = '123456';
  static const String _authKey = 'is_authenticated';

  Future<bool> verifyPassword(String password) async {
    // Basic verification against the fixed password
    final isValid = password == _masterPassword;
    if (isValid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_authKey, true);
    }
    return isValid;
  }

  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authKey) ?? false;
  }
}
