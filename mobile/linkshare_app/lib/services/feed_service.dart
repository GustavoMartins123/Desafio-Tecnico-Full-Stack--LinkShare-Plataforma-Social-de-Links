import '../models/activity.dart';
import 'api_client.dart';

class FeedService {
  final ApiClient _apiClient;

  FeedService(this._apiClient);

  Future<List<Activity>> getFeedActivities({int limit = 50}) async {
    final response = await _apiClient.get(
      '/feed/activities',
      queryParameters: {'limit': limit},
    );
    return (response.data as List)
        .map((json) => Activity.fromJson(json))
        .toList();
  }
}
