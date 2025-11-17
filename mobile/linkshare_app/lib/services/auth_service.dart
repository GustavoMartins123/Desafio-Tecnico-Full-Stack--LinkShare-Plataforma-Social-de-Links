import '../models/auth_response.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'storage_service.dart';

class AuthService {
  final ApiClient _apiClient;
  final StorageService _storage;

  AuthService(this._apiClient, this._storage);

  Future<AuthResponse> register({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post('/auth/register', data: {
        'email': email,
        'username': username,
        'password': password,
      });

      final authResponse = AuthResponse.fromJson(response.data);

      // Save credentials
      await _storage.saveToken(authResponse.token);
      await _storage.saveUserData(
        userId: authResponse.userId,
        username: authResponse.username,
        email: authResponse.email,
      );

      return authResponse;
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final authResponse = AuthResponse.fromJson(response.data);

      // Save credentials
      await _storage.saveToken(authResponse.token);
      await _storage.saveUserData(
        userId: authResponse.userId,
        username: authResponse.username,
        email: authResponse.email,
      );

      return authResponse;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }

  User? getCurrentUser() {
    final userId = _storage.getUserId();
    final username = _storage.getUsername();
    final email = _storage.getEmail();

    if (userId != null && username != null && email != null) {
      return User(id: userId, username: username, email: email);
    }
    return null;
  }

  bool get isLoggedIn => _storage.isLoggedIn;
}
