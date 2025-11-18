import 'package:drift/drift.dart';

class LocalCollections extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get ownerId => integer()();
  TextColumn get ownerUsername => text()();
  BoolColumn get isPublic => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get linkItemsCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
