import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // Tokens
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _prefs.setString(_accessTokenKey, accessToken);
    await _prefs.setString(_refreshTokenKey, refreshToken);
  }

  String? getAccessToken() {
    return _prefs.getString(_accessTokenKey);
  }

  String? getRefreshToken() {
    return _prefs.getString(_refreshTokenKey);
  }

  Future<void> deleteTokens() async {
    await _prefs.remove(_accessTokenKey);
    await _prefs.remove(_refreshTokenKey);
  }

  // Backward compatibility (deprecated)
  @Deprecated('Use getAccessToken() instead')
  String? getToken() => getAccessToken();

  @Deprecated('Use saveTokens() instead')
  Future<void> saveToken(String token) async {
    await _prefs.setString(_accessTokenKey, token);
  }

  @Deprecated('Use deleteTokens() instead')
  Future<void> deleteToken() async {
    await deleteTokens();
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

  bool get isLoggedIn => getAccessToken() != null;
}
