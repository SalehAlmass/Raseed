import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_service.dart';

class AuthService {
  // MASTER PASSWORD PLACEHOLDER (You can change this later)
  static const String _masterPassword = '123456';
  static const String _authKey = 'is_authenticated';

  final SubscriptionService _subService;

  AuthService(this._subService);

  Future<bool> verifyPassword(String password) async {
    // Basic verification against the fixed password
    final isValid = password == _masterPassword;
    if (isValid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_authKey, true);
      await _subService.initTrial();
    }
    return isValid;
  }

  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authKey) ?? false;
  }
}
