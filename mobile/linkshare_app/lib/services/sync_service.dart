import 'dart:convert';
import 'dart:async';
import 'package:drift/drift.dart' as drift;
import '../database/app_database.dart';
import 'api_client.dart';

class SyncService {
  final AppDatabase _database;
  final ApiClient _apiClient;
  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncService(this._database, this._apiClient);

  /// Start periodic sync (every 30 seconds)
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      processPendingActions();
    });
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Process all pending actions
  Future<void> processPendingActions() async {
    if (_isSyncing) return;

    _isSyncing = true;
    try {
      final pendingActions = await _database.getAllPendingActions();

      for (final action in pendingActions) {
        try {
          await _processAction(action);
          // If successful, delete the action
          await _database.deletePendingAction(action.id);
        } catch (e) {
          // Update retry count and error message
          final updatedAction = action.copyWith(
            retryCount: action.retryCount + 1,
            lastError: drift.Value(e.toString()),
          );
          await _database.updatePendingAction(updatedAction);

          // If too many retries, you might want to delete or mark as failed
          if (action.retryCount >= 5) {
            // Optionally delete after 5 failed attempts
            // await _database.deletePendingAction(action.id);
          }
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processAction(PendingAction action) async {
    final payload = jsonDecode(action.payload) as Map<String, dynamic>;

    switch (action.action) {
      case 'create_link':
        await _createLink(payload);
        break;
      case 'create_collection':
        await _createCollection(payload);
        break;
      case 'update_collection':
        await _updateCollection(payload);
        break;
      case 'delete_link':
        await _deleteLink(payload);
        break;
      case 'delete_collection':
        await _deleteCollection(payload);
        break;
      case 'send_friend_request':
        await _sendFriendRequest(payload);
        break;
      case 'accept_friend_request':
        await _acceptFriendRequest(payload);
        break;
      case 'update_profile':
        await _updateProfile(payload);
        break;
      default:
        throw Exception('Unknown action type: ${action.action}');
    }
  }

  Future<void> _createLink(Map<String, dynamic> payload) async {
    final collectionId = payload['collectionId'] as int;
    final title = payload['title'] as String;
    final url = payload['url'] as String;
    final description = payload['description'] as String;

    await _apiClient.post(
      '/collections/$collectionId/items',
      data: {
        'title': title,
        'url': url,
        'description': description,
      },
    );
  }

  Future<void> _createCollection(Map<String, dynamic> payload) async {
    final title = payload['title'] as String;
    final description = payload['description'] as String;
    final isPublic = payload['isPublic'] as bool;

    await _apiClient.post(
      '/collections',
      data: {
        'title': title,
        'description': description,
        'isPublic': isPublic,
      },
    );
  }

  Future<void> _updateCollection(Map<String, dynamic> payload) async {
    final collectionId = payload['collectionId'] as int;
    final title = payload['title'] as String;
    final description = payload['description'] as String;
    final isPublic = payload['isPublic'] as bool;

    await _apiClient.put(
      '/collections/$collectionId',
      data: {
        'title': title,
        'description': description,
        'isPublic': isPublic,
      },
    );
  }

  Future<void> _deleteLink(Map<String, dynamic> payload) async {
    final linkId = payload['linkId'] as int;
    await _apiClient.delete('/collections/items/$linkId');
  }

  Future<void> _deleteCollection(Map<String, dynamic> payload) async {
    final collectionId = payload['collectionId'] as int;
    await _apiClient.delete('/collections/$collectionId');
  }

  Future<void> _sendFriendRequest(Map<String, dynamic> payload) async {
    final userId = payload['userId'] as int;
    await _apiClient.post('/friends/request/$userId');
  }

  Future<void> _acceptFriendRequest(Map<String, dynamic> payload) async {
    final requestId = payload['requestId'] as int;
    await _apiClient.put('/friends/requests/$requestId/accept');
  }

  Future<void> _updateProfile(Map<String, dynamic> payload) async {
    final displayName = payload['displayName'] as String;
    final bio = payload['bio'] as String;

    await _apiClient.put(
      '/profiles/me',
      data: {
        'displayName': displayName,
        'bio': bio,
      },
    );
  }

  void dispose() {
    stopPeriodicSync();
  }
}
