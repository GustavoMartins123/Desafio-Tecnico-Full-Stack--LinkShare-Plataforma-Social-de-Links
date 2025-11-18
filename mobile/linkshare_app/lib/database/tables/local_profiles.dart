import 'package:drift/drift.dart';

class LocalProfiles extends Table {
  IntColumn get id => integer()();
  IntColumn get userId => integer()();
  TextColumn get displayName => text()();
  TextColumn get bio => text().withDefault(const Constant(''))();
  TextColumn get profilePictureUrl => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
