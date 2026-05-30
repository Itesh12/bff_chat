import 'package:drift/drift.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:memovault/features/hidden/data/tables/hidden_notes_table.dart';

part 'hidden_notes_dao.g.dart';

@DriftAccessor(tables: [HiddenNotesTable])
class HiddenNotesDao extends DatabaseAccessor<HiddenVaultDatabase>
    with _$HiddenNotesDaoMixin {
  HiddenNotesDao(super.db);

  // ---------------------------------------------------------------------------
  // Watch streams
  // ---------------------------------------------------------------------------

  /// Active notes only (excludes archived and deleted).
  Stream<List<HiddenNoteRow>> watchAllNotes() {
    return (select(hiddenNotesTable)
          ..where((t) => t.isArchived.equals(false) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Favorited active notes.
  Stream<List<HiddenNoteRow>> watchFavoriteNotes() {
    return (select(hiddenNotesTable)
          ..where((t) =>
              t.isFavorite.equals(true) &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // One-shot queries
  // ---------------------------------------------------------------------------

  Future<HiddenNoteRow?> getNoteById(String id) {
    return (select(hiddenNotesTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<HiddenNoteRow>> getArchivedNotes() {
    return (select(hiddenNotesTable)
          ..where((t) => t.isArchived.equals(true) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<List<HiddenNoteRow>> getTrashedNotes() {
    return (select(hiddenNotesTable)
          ..where((t) => t.isDeleted.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<List<HiddenNoteRow>> searchNotes(String query) {
    final term = '%$query%';
    return (select(hiddenNotesTable)
          ..where((t) =>
              (t.title.like(term) | t.body.like(term)) &
              t.isArchived.equals(false) &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<int> insertNote(HiddenNotesTableCompanion companion) {
    return into(hiddenNotesTable).insert(companion);
  }

  Future<bool> updateNote(HiddenNotesTableCompanion companion) {
    return update(hiddenNotesTable).replace(companion);
  }

  Future<int> archiveNote(String id) {
    return (update(hiddenNotesTable)..where((t) => t.id.equals(id))).write(
      HiddenNotesTableCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<int> restoreNote(String id) {
    return (update(hiddenNotesTable)..where((t) => t.id.equals(id))).write(
      HiddenNotesTableCompanion(
        isArchived: const Value(false),
        isDeleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<int> softDeleteNote(String id) {
    final now = DateTime.now().toUtc();
    return (update(hiddenNotesTable)..where((t) => t.id.equals(id))).write(
      HiddenNotesTableCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<int> deleteNote(String id) {
    return (delete(hiddenNotesTable)..where((t) => t.id.equals(id))).go();
  }

  Future<int> emptyTrash() {
    return (delete(hiddenNotesTable)..where((t) => t.isDeleted.equals(true))).go();
  }

  // ---------------------------------------------------------------------------
  // Counts (efficient SQL COUNT — no full table scan via stream)
  // ---------------------------------------------------------------------------

  Future<int> countActive() async {
    final countExp = hiddenNotesTable.id.count();
    final query = selectOnly(hiddenNotesTable)
      ..addColumns([countExp])
      ..where(hiddenNotesTable.isArchived.equals(false) &
          hiddenNotesTable.isDeleted.equals(false));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<int> countFavorites() async {
    final countExp = hiddenNotesTable.id.count();
    final query = selectOnly(hiddenNotesTable)
      ..addColumns([countExp])
      ..where(hiddenNotesTable.isFavorite.equals(true) &
          hiddenNotesTable.isDeleted.equals(false));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<int> countArchived() async {
    final countExp = hiddenNotesTable.id.count();
    final query = selectOnly(hiddenNotesTable)
      ..addColumns([countExp])
      ..where(hiddenNotesTable.isArchived.equals(true) &
          hiddenNotesTable.isDeleted.equals(false));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<int> countTrashed() async {
    final countExp = hiddenNotesTable.id.count();
    final query = selectOnly(hiddenNotesTable)
      ..addColumns([countExp])
      ..where(hiddenNotesTable.isDeleted.equals(true));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }
}
