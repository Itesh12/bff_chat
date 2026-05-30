import 'package:drift/drift.dart';

@DataClassName('CategoryRow')
class CategoriesTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get colorHex => text().withLength(min: 6, max: 6)();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
