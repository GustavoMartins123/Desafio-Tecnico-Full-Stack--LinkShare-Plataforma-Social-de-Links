import '../models/collection.dart';
import '../models/link_item.dart';
import '../models/collection_share.dart';
import '../models/shared_collection.dart';
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

  // Collection Sharing
  Future<CollectionShare> shareCollection({
    required int collectionId,
    required int sharedWithUserId,
    bool canEdit = false,
  }) async {
    final response = await _apiClient.post(
      '/collections/$collectionId/share',
      data: {
        'sharedWithUserId': sharedWithUserId,
        'canEdit': canEdit,
      },
    );
    return CollectionShare.fromJson(response.data);
  }

  Future<List<CollectionShare>> getCollectionShares(int collectionId) async {
    final response = await _apiClient.get('/collections/$collectionId/shares');
    return (response.data as List)
        .map((json) => CollectionShare.fromJson(json))
        .toList();
  }

  Future<List<SharedCollection>> getSharedWithMe() async {
    final response = await _apiClient.get('/collections/shared-with-me');
    return (response.data as List)
        .map((json) => SharedCollection.fromJson(json))
        .toList();
  }

  Future<CollectionShare> updateSharePermissions({
    required int collectionId,
    required int shareId,
    required bool canEdit,
  }) async {
    final response = await _apiClient.put(
      '/collections/$collectionId/share/$shareId',
      data: {
        'sharedWithUserId': 0, // Not used in backend for update
        'canEdit': canEdit,
      },
    );
    return CollectionShare.fromJson(response.data);
  }

  Future<void> removeShare({
    required int collectionId,
    required int shareId,
  }) async {
    await _apiClient.delete('/collections/$collectionId/share/$shareId');
  }
}
