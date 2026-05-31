import 'dart:math';
import 'package:drift/drift.dart';
import 'package:memovault/features/hidden/data/hidden_notes_dao.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:memovault/features/hidden/domain/entities/hidden_note_entity.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_notes_repository.dart';

class HiddenNotesRepositoryImpl implements HiddenNotesRepository {
  final HiddenNotesDao _notesDao;

  HiddenNotesRepositoryImpl(this._notesDao);

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  String _generateUuid() {
    final random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (i) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC4122
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  HiddenNoteEntity _toEntity(HiddenNoteRow row) {
    return HiddenNoteEntity(
      id: row.id,
      title: row.title,
      body: row.body,
      categoryId: row.categoryId,
      revision: row.revision,
      isFavorite: row.isFavorite,
      isArchived: row.isArchived,
      isDeleted: row.isDeleted,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      lastOpenedAt: row.lastOpenedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Watch streams
  // ---------------------------------------------------------------------------

  @override
  Stream<List<HiddenNoteEntity>> watchAllNotes() {
    return _notesDao.watchAllNotes().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Stream<List<HiddenNoteEntity>> watchFavoriteNotes() {
    return _notesDao.watchFavoriteNotes().map((rows) => rows.map(_toEntity).toList());
  }

  // ---------------------------------------------------------------------------
  // One-shot queries
  // ---------------------------------------------------------------------------

  @override
  Future<HiddenNoteEntity?> getNoteById(String id) async {
    final row = await _notesDao.getNoteById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<List<HiddenNoteEntity>> getArchivedNotes() async {
    final rows = await _notesDao.getArchivedNotes();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<List<HiddenNoteEntity>> getTrashedNotes() async {
    final rows = await _notesDao.getTrashedNotes();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<List<HiddenNoteEntity>> searchNotes(String query) async {
    final rows = await _notesDao.searchNotes(query);
    return rows.map(_toEntity).toList();
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  @override
  Future<HiddenNoteEntity> createNote({required String title, required String body, String? categoryId}) async {
    final id = _generateUuid();
    final now = DateTime.now().toUtc();
    final companion = HiddenNotesTableCompanion(
      id: Value(id),
      title: Value(title),
      body: Value(body),
      categoryId: Value(categoryId),
      revision: const Value(1),
      isFavorite: const Value(false),
      isArchived: const Value(false),
      isDeleted: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    await _notesDao.insertNote(companion);
    final row = await _notesDao.getNoteById(id);
    return _toEntity(row!);
  }

  @override
  Future<HiddenNoteEntity> updateNote(HiddenNoteEntity note) async {
    final now = DateTime.now().toUtc();
    final companion = HiddenNotesTableCompanion(
      id: Value(note.id),
      title: Value(note.title),
      body: Value(note.body),
      categoryId: Value(note.categoryId),
      revision: Value(note.revision + 1),
      isFavorite: Value(note.isFavorite),
      isArchived: Value(note.isArchived),
      isDeleted: Value(note.isDeleted),
      createdAt: Value(note.createdAt),
      updatedAt: Value(now),
      deletedAt: Value(note.deletedAt),
      lastOpenedAt: Value(note.lastOpenedAt),
    );
    await _notesDao.updateNote(companion);
    final row = await _notesDao.getNoteById(note.id);
    return _toEntity(row!);
  }

  @override
  Future<void> updateLastOpened(String id) async {
    final note = await getNoteById(id);
    if (note != null) {
      await _notesDao.updateNote(HiddenNotesTableCompanion(
        id: Value(id),
        lastOpenedAt: Value(DateTime.now().toUtc()),
      ));
    }
  }

  @override
  Future<void> toggleFavorite(String id) async {
    final note = await getNoteById(id);
    if (note != null) {
      await _notesDao.updateNote(HiddenNotesTableCompanion(
        id: Value(id),
        isFavorite: Value(!note.isFavorite),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
    }
  }

  @override
  Future<void> archiveNote(String id) => _notesDao.archiveNote(id);

  @override
  Future<void> restoreNote(String id) => _notesDao.restoreNote(id);

  @override
  Future<void> softDeleteNote(String id) => _notesDao.softDeleteNote(id);

  @override
  Future<void> permanentlyDeleteNote(String id) => _notesDao.deleteNote(id);

  @override
  Future<void> emptyTrash() => _notesDao.emptyTrash();

  // ---------------------------------------------------------------------------
  // Statistics (proper SQL COUNT — no stream scan)
  // ---------------------------------------------------------------------------

  @override
  Future<int> notesCount() => _notesDao.countActive();

  @override
  Future<int> favoritesCount() => _notesDao.countFavorites();

  @override
  Future<int> archivedCount() => _notesDao.countArchived();

  @override
  Future<int> trashedCount() => _notesDao.countTrashed();
}
