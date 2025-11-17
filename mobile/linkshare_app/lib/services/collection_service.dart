import '../models/collection.dart';
import '../models/link_item.dart';
import 'api_client.dart';

class CollectionService {
  final ApiClient _apiClient;

  CollectionService(this._apiClient);

  Future<Collection> createCollection({
    required String title,
    required String description,
    required bool isPublic,
  }) async {
    final response = await _apiClient.post('/collections', data: {
      'title': title,
      'description': description,
      'isPublic': isPublic,
    });
    return Collection.fromJson(response.data);
  }

  Future<List<Collection>> getMyCollections() async {
    final response = await _apiClient.get('/collections/me');
    return (response.data as List)
        .map((json) => Collection.fromJson(json))
        .toList();
  }

  Future<List<Collection>> getUserPublicCollections(String username) async {
    final response = await _apiClient.get('/collections/user/$username');
    return (response.data as List)
        .map((json) => Collection.fromJson(json))
        .toList();
  }

  Future<Collection> getCollectionById(int collectionId) async {
    final response = await _apiClient.get('/collections/$collectionId');
    return Collection.fromJson(response.data);
  }

  Future<LinkItem> addLinkItem({
    required int collectionId,
    required String title,
    required String url,
    required String description,
  }) async {
    final response = await _apiClient.post(
      '/collections/$collectionId/items',
      data: {
        'title': title,
        'url': url,
        'description': description,
      },
    );
    return LinkItem.fromJson(response.data);
  }

  Future<void> shareCollection({
    required int collectionId,
    required int friendId,
  }) async {
    await _apiClient.post('/collections/$collectionId/share/$friendId');
  }
}
