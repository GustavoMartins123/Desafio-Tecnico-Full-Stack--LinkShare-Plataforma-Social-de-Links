import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/local_collections.dart';
import 'tables/local_link_items.dart';
import 'tables/local_friendships.dart';
import 'tables/local_profiles.dart';
import 'tables/pending_actions.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  LocalCollections,
  LocalLinkItems,
  LocalFriendships,
  LocalProfiles,
  PendingActions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Collections queries
  Future<List<LocalCollection>> getAllCollections() =>
      select(localCollections).get();

  Future<LocalCollection?> getCollectionById(int id) =>
      (select(localCollections)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertCollection(LocalCollectionsCompanion collection) =>
      into(localCollections).insert(collection);

  Future<void> updateCollection(LocalCollection collection) =>
      update(localCollections).replace(collection);

  Future<void> deleteCollection(int id) =>
      (delete(localCollections)..where((t) => t.id.equals(id))).go();

  Future<void> clearCollections() => delete(localCollections).go();

  // LinkItems queries
  Future<List<LocalLinkItem>> getLinkItemsByCollectionId(int collectionId) =>
      (select(localLinkItems)..where((t) => t.collectionId.equals(collectionId))).get();

  Future<int> insertLinkItem(LocalLinkItemsCompanion linkItem) =>
      into(localLinkItems).insert(linkItem);

  Future<void> updateLinkItem(LocalLinkItem linkItem) =>
      update(localLinkItems).replace(linkItem);

  Future<void> deleteLinkItem(int id) =>
      (delete(localLinkItems)..where((t) => t.id.equals(id))).go();

  Future<void> deleteLinkItemsByCollectionId(int collectionId) =>
      (delete(localLinkItems)..where((t) => t.collectionId.equals(collectionId))).go();

  // Friendships queries
  Future<List<LocalFriendship>> getAllFriendships() =>
      select(localFriendships).get();

  Future<List<LocalFriendship>> getAcceptedFriendships() =>
      (select(localFriendships)..where((t) => t.status.equals('Accepted'))).get();

  Future<List<LocalFriendship>> getPendingFriendships() =>
      (select(localFriendships)..where((t) => t.status.equals('Pending'))).get();

  Future<int> insertFriendship(LocalFriendshipsCompanion friendship) =>
      into(localFriendships).insert(friendship);

  Future<void> updateFriendship(LocalFriendship friendship) =>
      update(localFriendships).replace(friendship);

  Future<void> deleteFriendship(int id) =>
      (delete(localFriendships)..where((t) => t.id.equals(id))).go();

  Future<void> clearFriendships() => delete(localFriendships).go();

  // Profiles queries
  Future<LocalProfile?> getProfileById(int id) =>
      (select(localProfiles)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertProfile(LocalProfilesCompanion profile) =>
      into(localProfiles).insert(profile);

  Future<void> updateProfile(LocalProfile profile) =>
      update(localProfiles).replace(profile);

  Future<void> deleteProfile(int id) =>
      (delete(localProfiles)..where((t) => t.id.equals(id))).go();

  // PendingActions queries
  Future<List<PendingAction>> getAllPendingActions() =>
      (select(pendingActions)..orderBy([(t) => OrderingTerm(expression: t.createdAt)])).get();

  Future<int> insertPendingAction(PendingActionsCompanion action) =>
      into(pendingActions).insert(action);

  Future<void> deletePendingAction(int id) =>
      (delete(pendingActions)..where((t) => t.id.equals(id))).go();

  Future<void> updatePendingAction(PendingAction action) =>
      update(pendingActions).replace(action);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'linkshare.db'));
    return NativeDatabase.createInBackground(file);
  });
}
