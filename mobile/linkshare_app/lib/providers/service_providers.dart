import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/friendship_service.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';

// SharedPreferences Provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

// Storage Service Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StorageService(prefs);
});

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiClient(storage);
});

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return AuthService(apiClient, storage);
});

// Profile Service Provider
final profileServiceProvider = Provider<ProfileService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProfileService(apiClient);
});

// Collection Service Provider
final collectionServiceProvider = Provider<CollectionService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CollectionService(apiClient);
});

// Friendship Service Provider
final friendshipServiceProvider = Provider<FriendshipService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FriendshipService(apiClient);
});
