import 'package:drift/drift.dart';

@DataClassName('HiddenCategoryRow')
class HiddenCategoriesTable extends Table {
  @override
  String get tableName => 'hidden_categories';

  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get colorHex => text().withLength(min: 6, max: 6)();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
