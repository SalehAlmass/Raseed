class AuthService {
  // MASTER PASSWORD PLACEHOLDER (You can change this later)
  static const String _masterPassword = '123456';

  Future<bool> verifyPassword(String password) async {
    // Basic verification against the fixed password
    return password == _masterPassword;
  }
}
