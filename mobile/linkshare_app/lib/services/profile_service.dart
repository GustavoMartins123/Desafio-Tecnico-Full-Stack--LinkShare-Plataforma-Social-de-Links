import '../models/profile.dart';
import 'api_client.dart';

class ProfileService {
  final ApiClient _apiClient;

  ProfileService(this._apiClient);

  Future<Profile> getMyProfile() async {
    final response = await _apiClient.get('/profiles/me');
    return Profile.fromJson(response.data);
  }

  Future<Profile> getProfileByUsername(String username) async {
    final response = await _apiClient.get('/profiles/$username');
    return Profile.fromJson(response.data);
  }

  Future<Profile> updateMyProfile({
    required String displayName,
    required String bio,
  }) async {
    final response = await _apiClient.put('/profiles/me', data: {
      'displayName': displayName,
      'bio': bio,
    });
    return Profile.fromJson(response.data);
  }

  Future<List<Profile>> searchProfiles(String query) async {
    final response = await _apiClient.get('/profiles/search', queryParameters: {
      'query': query,
    });
    return (response.data as List)
        .map((json) => Profile.fromJson(json))
        .toList();
  }
}
