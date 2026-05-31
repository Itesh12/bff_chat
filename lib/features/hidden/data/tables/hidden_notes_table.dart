import 'package:drift/drift.dart';
import 'package:memovault/features/hidden/data/tables/hidden_categories_table.dart';

@DataClassName('HiddenNoteRow')
class HiddenNotesTable extends Table {
  @override
  String get tableName => 'hidden_notes';

  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 0, max: 200)();
  TextColumn get body => text()();
  TextColumn get categoryId => text().nullable().references(HiddenCategoriesTable, #id, onDelete: KeyAction.setNull)();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
