import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import '../database/app_database.dart';
import '../models/collection.dart' as model;
import '../models/link_item.dart' as model;
import '../services/api_client.dart';

class CollectionRepository {
  final AppDatabase _database;
  final ApiClient _apiClient;

  CollectionRepository(this._database, this._apiClient);

  /// Get all collections - Source of Truth pattern
  /// 1. Return cached data immediately
  /// 2. Fetch from API in background
  /// 3. Update cache when API responds
  Stream<List<model.Collection>> watchMyCollections() {
    // Immediately return data from local database
    final stream = _database.getAllCollections().asStream();

    // Fetch from API in background
    _syncCollectionsFromApi();

    return stream.map((localCollections) {
      return localCollections.map((local) {
        return model.Collection(
          id: local.id,
          title: local.title,
          description: local.description,
          ownerId: local.ownerId,
          ownerUsername: local.ownerUsername,
          isPublic: local.isPublic,
          createdAt: local.createdAt,
          linkItemsCount: local.linkItemsCount,
        );
      }).toList();
    });
  }

  /// Sync collections from API to local database
  Future<void> _syncCollectionsFromApi() async {
    try {
      final response = await _apiClient.get('/collections/me');
      final collections = (response.data as List)
          .map((json) => model.Collection.fromJson(json))
          .toList();

      // Clear old data and insert new data
      await _database.clearCollections();

      for (final collection in collections) {
        await _database.insertCollection(
          LocalCollectionsCompanion.insert(
            id: drift.Value(collection.id),
            title: collection.title,
            description: collection.description,
            ownerId: collection.ownerId,
            ownerUsername: collection.ownerUsername,
            isPublic: collection.isPublic,
            createdAt: collection.createdAt,
            linkItemsCount: collection.linkItemsCount,
            lastSyncedAt: drift.Value(DateTime.now()),
          ),
        );
      }
    } catch (e) {
      // If API call fails (offline), do nothing
      // UI will continue showing cached data
      print('Failed to sync collections: $e');
    }
  }

  /// Create a new collection
  Future<model.Collection?> createCollection({
    required String title,
    required String description,
    required bool isPublic,
  }) async {
    try {
      final response = await _apiClient.post('/collections', data: {
        'title': title,
        'description': description,
        'isPublic': isPublic,
      });

      final collection = model.Collection.fromJson(response.data);

      // Add to local database
      await _database.insertCollection(
        LocalCollectionsCompanion.insert(
          id: drift.Value(collection.id),
          title: collection.title,
          description: collection.description,
          ownerId: collection.ownerId,
          ownerUsername: collection.ownerUsername,
          isPublic: collection.isPublic,
          createdAt: collection.createdAt,
          linkItemsCount: collection.linkItemsCount,
          lastSyncedAt: drift.Value(DateTime.now()),
        ),
      );

      return collection;
    } catch (e) {
      // If offline, save to pending actions
      await _database.insertPendingAction(
        PendingActionsCompanion.insert(
          action: 'create_collection',
          payload: jsonEncode({
            'title': title,
            'description': description,
            'isPublic': isPublic,
          }),
          createdAt: DateTime.now(),
        ),
      );

      // Return null to indicate pending
      return null;
    }
  }

  /// Get collection details with links
  Future<model.Collection?> getCollectionById(int collectionId) async {
    try {
      final response = await _apiClient.get('/collections/$collectionId');
      final json = response.data as Map<String, dynamic>;

      // Parse collection
      final collection = model.Collection(
        id: json['id'] as int,
        title: json['title'] as String,
        description: json['description'] as String,
        ownerId: json['ownerId'] as int,
        ownerUsername: json['ownerUsername'] as String,
        isPublic: json['isPublic'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        linkItemsCount: (json['linkItems'] as List?)?.length ?? 0,
        linkItems: (json['linkItems'] as List?)
            ?.map((item) => model.LinkItem.fromJson(item))
            .toList(),
      );

      // Update local cache
      final localCollection = await _database.getCollectionById(collectionId);
      if (localCollection != null) {
        await _database.updateCollection(
          localCollection.copyWith(
            title: collection.title,
            description: collection.description,
            isPublic: collection.isPublic,
            linkItemsCount: collection.linkItemsCount,
            lastSyncedAt: drift.Value(DateTime.now()),
          ),
        );
      }

      // Cache link items
      if (collection.linkItems != null) {
        // Clear old links for this collection
        await _database.deleteLinkItemsByCollectionId(collectionId);

        // Insert new links
        for (final link in collection.linkItems!) {
          await _database.insertLinkItem(
            LocalLinkItemsCompanion.insert(
              id: drift.Value(link.id),
              title: link.title,
              url: link.url,
              description: link.description,
              collectionId: link.collectionId,
              createdAt: link.createdAt,
              lastSyncedAt: drift.Value(DateTime.now()),
            ),
          );
        }
      }

      return collection;
    } catch (e) {
      // If offline, try to return from cache
      final localCollection = await _database.getCollectionById(collectionId);
      if (localCollection != null) {
        final localLinks = await _database.getLinkItemsByCollectionId(collectionId);

        return model.Collection(
          id: localCollection.id,
          title: localCollection.title,
          description: localCollection.description,
          ownerId: localCollection.ownerId,
          ownerUsername: localCollection.ownerUsername,
          isPublic: localCollection.isPublic,
          createdAt: localCollection.createdAt,
          linkItemsCount: localCollection.linkItemsCount,
          linkItems: localLinks.map((local) {
            return model.LinkItem(
              id: local.id,
              title: local.title,
              url: local.url,
              description: local.description,
              collectionId: local.collectionId,
              createdAt: local.createdAt,
            );
          }).toList(),
        );
      }

      return null;
    }
  }

  /// Add a link item to a collection
  Future<model.LinkItem?> addLinkItem({
    required int collectionId,
    required String title,
    required String url,
    required String description,
  }) async {
    try {
      final response = await _apiClient.post(
        '/collections/$collectionId/items',
        data: {
          'title': title,
          'url': url,
          'description': description,
        },
      );

      final linkItem = model.LinkItem.fromJson(response.data);

      // Add to local database
      await _database.insertLinkItem(
        LocalLinkItemsCompanion.insert(
          id: drift.Value(linkItem.id),
          title: linkItem.title,
          url: linkItem.url,
          description: linkItem.description,
          collectionId: linkItem.collectionId,
          createdAt: linkItem.createdAt,
          lastSyncedAt: drift.Value(DateTime.now()),
        ),
      );

      return linkItem;
    } catch (e) {
      // If offline, save to pending actions
      await _database.insertPendingAction(
        PendingActionsCompanion.insert(
          action: 'create_link',
          payload: jsonEncode({
            'collectionId': collectionId,
            'title': title,
            'url': url,
            'description': description,
          }),
          createdAt: DateTime.now(),
        ),
      );

      // Also add to local database with pending flag
      final tempId = DateTime.now().millisecondsSinceEpoch;
      await _database.insertLinkItem(
        LocalLinkItemsCompanion.insert(
          id: drift.Value(tempId),
          title: title,
          url: url,
          description: description,
          collectionId: collectionId,
          createdAt: DateTime.now(),
          isPending: const drift.Value(true),
        ),
      );

      // Return a temporary link item
      return model.LinkItem(
        id: tempId,
        title: title,
        url: url,
        description: description,
        collectionId: collectionId,
        createdAt: DateTime.now(),
      );
    }
  }
}
