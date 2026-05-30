import 'package:drift/drift.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:memovault/features/hidden/data/tables/hidden_notes_table.dart';

part 'hidden_notes_dao.g.dart';

@DriftAccessor(tables: [HiddenNotesTable])
class HiddenNotesDao extends DatabaseAccessor<HiddenVaultDatabase> with _$HiddenNotesDaoMixin {
  HiddenNotesDao(super.db);

  Stream<List<HiddenNoteRow>> watchAllNotes() {
    return (select(hiddenNotesTable)
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<HiddenNoteRow?> getNoteById(String id) {
    return (select(hiddenNotesTable)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertNote(HiddenNotesTableCompanion companion) {
    return into(hiddenNotesTable).insert(companion);
  }

  Future<bool> updateNote(HiddenNotesTableCompanion companion) {
    return update(hiddenNotesTable).replace(companion);
  }

  Future<int> deleteNote(String id) {
    return (delete(hiddenNotesTable)..where((t) => t.id.equals(id))).go();
  }
}
