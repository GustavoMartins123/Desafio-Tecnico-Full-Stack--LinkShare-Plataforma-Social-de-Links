import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // Token
  Future<void> saveToken(String token) async {
    await _prefs.setString(_tokenKey, token);
  }

  String? getToken() {
    return _prefs.getString(_tokenKey);
  }

  Future<void> deleteToken() async {
    await _prefs.remove(_tokenKey);
  }

  // User Data
  Future<void> saveUserData({
    required int userId,
    required String username,
    required String email,
  }) async {
    await _prefs.setInt(_userIdKey, userId);
    await _prefs.setString(_usernameKey, username);
    await _prefs.setString(_emailKey, email);
  }

  int? getUserId() {
    return _prefs.getInt(_userIdKey);
  }

  String? getUsername() {
    return _prefs.getString(_usernameKey);
  }

  String? getEmail() {
    return _prefs.getString(_emailKey);
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }

  bool get isLoggedIn => getToken() != null;
}
