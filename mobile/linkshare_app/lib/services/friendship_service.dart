import '../models/friendship.dart';
import 'api_client.dart';

class FriendshipService {
  final ApiClient _apiClient;

  FriendshipService(this._apiClient);

  Future<Friendship> sendFriendRequest(int userId) async {
    final response = await _apiClient.post('/friends/request/$userId');
    return Friendship.fromJson(response.data);
  }

  Future<List<Friendship>> getFriendRequests() async {
    final response = await _apiClient.get('/friends/requests');
    return (response.data as List)
        .map((json) => Friendship.fromJson(json))
        .toList();
  }

  Future<Friendship> acceptFriendRequest(int requestId) async {
    final response = await _apiClient.put('/friends/requests/$requestId/accept');
    return Friendship.fromJson(response.data);
  }

  Future<void> declineFriendRequest(int requestId) async {
    await _apiClient.delete('/friends/requests/$requestId');
  }

  Future<List<Friendship>> getFriends() async {
    final response = await _apiClient.get('/friends');
    return (response.data as List)
        .map((json) => Friendship.fromJson(json))
        .toList();
  }

  Future<void> removeFriend(int friendId) async {
    await _apiClient.delete('/friends/$friendId');
  }
}
