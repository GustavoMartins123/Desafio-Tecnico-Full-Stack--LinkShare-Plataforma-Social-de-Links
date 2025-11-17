import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/collection.dart';
import 'service_providers.dart';

// My Collections Provider
final myCollectionsProvider = FutureProvider<List<Collection>>((ref) async {
  final collectionService = ref.watch(collectionServiceProvider);
  return await collectionService.getMyCollections();
});

// Collection Detail Provider (by ID)
final collectionDetailProvider = FutureProvider.family<Collection, int>((ref, collectionId) async {
  final collectionService = ref.watch(collectionServiceProvider);
  return await collectionService.getCollectionById(collectionId);
});
