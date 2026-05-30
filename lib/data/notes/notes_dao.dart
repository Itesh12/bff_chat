import 'package:drift/drift.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/core/storage/tables/notes_table.dart';
import 'package:memovault/domain/notes/note_sort_mode.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [NotesTable])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  // Helper to apply sorting modes dynamically to a select statement
  void _applySorting(SimpleSelectStatement<NotesTable, NoteRow> query, NoteSortMode sort) {
    switch (sort) {
      case NoteSortMode.updatedDesc:
        query.orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);
        break;
      case NoteSortMode.updatedAsc:
        query.orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.asc)]);
        break;
      case NoteSortMode.createdDesc:
        query.orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
        break;
      case NoteSortMode.createdAsc:
        query.orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]);
        break;
      case NoteSortMode.titleAZ:
        query.orderBy([(t) => OrderingTerm(expression: t.title, mode: OrderingMode.asc)]);
        break;
      case NoteSortMode.titleZA:
        query.orderBy([(t) => OrderingTerm(expression: t.title, mode: OrderingMode.desc)]);
        break;
    }
  }

  // watch all active notes (excludes archived and soft-deleted notes)
  Stream<List<NoteRow>> watchAllNotes({NoteSortMode sort = NoteSortMode.updatedDesc}) {
    final query = select(notesTable)
      ..where((t) => t.isDeleted.not() & t.isArchived.not());
    _applySorting(query, sort);
    return query.watch();
  }

  // watch favorite notes (excludes archived and soft-deleted notes)
  Stream<List<NoteRow>> watchFavoriteNotes({NoteSortMode sort = NoteSortMode.updatedDesc}) {
    final query = select(notesTable)
      ..where((t) => t.isDeleted.not() & t.isArchived.not() & t.isFavorite.equals(true));
    _applySorting(query, sort);
    return query.watch();
  }

  // get archived notes
  Future<List<NoteRow>> getArchivedNotes({NoteSortMode sort = NoteSortMode.updatedDesc}) {
    final query = select(notesTable)
      ..where((t) => t.isDeleted.not() & t.isArchived.equals(true));
    _applySorting(query, sort);
    return query.get();
  }

  // search notes by title/body (minimum characters rule should be validated in controller)
  Future<List<NoteRow>> searchNotes(String queryText, {NoteSortMode sort = NoteSortMode.updatedDesc}) {
    final cleanQuery = '%$queryText%';
    final query = select(notesTable)
      ..where((t) => t.isDeleted.not() & t.isArchived.not() & (t.title.like(cleanQuery) | t.body.like(cleanQuery)));
    _applySorting(query, sort);
    return query.get();
  }

  // CRUD base actions
  Future<NoteRow?> getNoteById(String id) {
    return (select(notesTable)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertNote(NotesTableCompanion companion) {
    return into(notesTable).insert(companion);
  }

  Future<bool> updateNote(NotesTableCompanion companion) {
    return update(notesTable).replace(companion);
  }

  Future<void> updateLastOpened(String id, DateTime time) async {
    await (update(notesTable)..where((t) => t.id.equals(id)))
        .write(NotesTableCompanion(lastOpenedAt: Value(time)));
  }

  Future<void> toggleFavorite(String id) async {
    final note = await getNoteById(id);
    if (note != null) {
      final now = DateTime.now().toUtc();
      await (update(notesTable)..where((t) => t.id.equals(id)))
          .write(NotesTableCompanion(
            isFavorite: Value(!note.isFavorite),
            updatedAt: Value(now),
          ));
    }
  }

  Future<void> archiveNote(String id) async {
    final now = DateTime.now().toUtc();
    await (update(notesTable)..where((t) => t.id.equals(id)))
        .write(NotesTableCompanion(
          isArchived: const Value(true),
          updatedAt: Value(now),
        ));
  }

  Future<void> restoreNote(String id) async {
    final now = DateTime.now().toUtc();
    await (update(notesTable)..where((t) => t.id.equals(id)))
        .write(NotesTableCompanion(
          isArchived: const Value(false),
          updatedAt: Value(now),
        ));
  }

  Future<void> softDeleteNote(String id) async {
    final now = DateTime.now().toUtc();
    await (update(notesTable)..where((t) => t.id.equals(id)))
        .write(NotesTableCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));
  }

  Future<int> deleteNotePermanently(String id) {
    return (delete(notesTable)..where((t) => t.id.equals(id))).go();
  }

  // Statistics
  Future<int> countNotes() async {
    final countExpr = notesTable.id.count();
    final query = selectOnly(notesTable)
      ..addColumns([countExpr])
      ..where(notesTable.isDeleted.not() & notesTable.isArchived.not());
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  Future<int> countFavorites() async {
    final countExpr = notesTable.id.count();
    final query = selectOnly(notesTable)
      ..addColumns([countExpr])
      ..where(notesTable.isDeleted.not() & notesTable.isArchived.not() & notesTable.isFavorite.equals(true));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  Future<int> countArchived() async {
    final countExpr = notesTable.id.count();
    final query = selectOnly(notesTable)
      ..addColumns([countExpr])
      ..where(notesTable.isDeleted.not() & notesTable.isArchived.equals(true));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }
}
