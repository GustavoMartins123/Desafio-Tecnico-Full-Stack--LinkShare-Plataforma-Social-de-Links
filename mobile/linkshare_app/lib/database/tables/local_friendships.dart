import 'package:drift/drift.dart';

class LocalFriendships extends Table {
  IntColumn get id => integer()();
  IntColumn get requesterId => integer()();
  TextColumn get requesterUsername => text()();
  TextColumn get requesterDisplayName => text()();
  IntColumn get addresseeId => integer()();
  TextColumn get addresseeUsername => text()();
  TextColumn get addresseeDisplayName => text()();
  TextColumn get status => text()(); // Pending, Accepted, Declined, Blocked
  IntColumn get friendId => integer()(); // ID do amigo (não do usuário logado)
  TextColumn get friendUsername => text()();
  TextColumn get friendDisplayName => text()();
  DateTimeColumn get requestedAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
