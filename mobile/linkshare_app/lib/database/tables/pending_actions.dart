import 'package:drift/drift.dart';

class PendingActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get action => text()(); // 'create_link', 'update_collection', 'delete_link', etc
  TextColumn get payload => text()(); // JSON string with data
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}
