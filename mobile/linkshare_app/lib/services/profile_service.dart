import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
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

  Future<Profile> uploadProfilePicture(File imageFile) async {
    // Get file extension
    final extension = imageFile.path.split('.').last.toLowerCase();

    // Determine MIME type
    String mimeType;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        mimeType = 'image/jpeg';
        break;
      case 'png':
        mimeType = 'image/png';
        break;
      case 'gif':
        mimeType = 'image/gif';
        break;
      case 'webp':
        mimeType = 'image/webp';
        break;
      default:
        mimeType = 'image/jpeg';
    }

    // Create multipart file
    final fileName = imageFile.path.split('/').last;
    final multipartFile = await MultipartFile.fromFile(
      imageFile.path,
      filename: fileName,
      contentType: MediaType.parse(mimeType),
    );

    // Create FormData
    final formData = FormData.fromMap({
      'file': multipartFile,
    });

    // Upload
    final response = await _apiClient.post('/profiles/me/picture', data: formData);
    return Profile.fromJson(response.data);
  }

  Future<Profile> deleteProfilePicture() async {
    final response = await _apiClient.delete('/profiles/me/picture');
    return Profile.fromJson(response.data);
  }

  /// Register device for push notifications
  Future<void> registerDevice({
    required String fcmToken,
    required String deviceName,
    required String platform,
  }) async {
    await _apiClient.post('/profiles/me/device', data: {
      'fcmToken': fcmToken,
      'deviceName': deviceName,
      'platform': platform,
    });
  }

  /// Unregister device (remove FCM token)
  Future<void> unregisterDevice(String fcmToken) async {
    await _apiClient.delete('/profiles/me/device', queryParameters: {
      'fcmToken': fcmToken,
    });
  }
}
