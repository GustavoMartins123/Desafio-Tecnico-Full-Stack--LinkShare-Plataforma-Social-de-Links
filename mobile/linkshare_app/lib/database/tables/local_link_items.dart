import 'package:drift/drift.dart';

class LocalLinkItems extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get url => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get collectionId => integer()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isPending => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
