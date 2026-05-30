import 'package:drift/drift.dart';

@DataClassName('HiddenNoteRow')
class HiddenNotesTable extends Table {
  @override
  String get tableName => 'hidden_notes';

  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 0, max: 200)();
  TextColumn get body => text()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
