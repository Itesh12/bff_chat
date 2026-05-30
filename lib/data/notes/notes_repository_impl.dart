import 'dart:math';
import 'package:drift/drift.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/data/notes/notes_dao.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/note_sort_mode.dart';
import 'package:memovault/domain/notes/notes_repository.dart';

class NotesRepositoryImpl implements NotesRepository {
  final NotesDao _notesDao;

  NotesRepositoryImpl(this._notesDao);

  // Cryptographically secure UUID v4 generator in pure Dart
  String _generateUuid() {
    final random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (i) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC4122
    
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  NoteEntity _toEntity(NoteRow row) {
    return NoteEntity(
      id: row.id,
      title: row.title,
      body: row.body,
      categoryId: row.categoryId,
      revision: row.revision,
      isFavorite: row.isFavorite,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastOpenedAt: row.lastOpenedAt,
    );
  }

  @override
  Stream<List<NoteEntity>> watchAllNotes({NoteSortMode sort = NoteSortMode.updatedDesc}) {
    return _notesDao.watchAllNotes(sort: sort).map(
      (rows) => rows.map(_toEntity).toList(),
    );
  }

  @override
  Stream<List<NoteEntity>> watchFavoriteNotes({NoteSortMode sort = NoteSortMode.updatedDesc}) {
    return _notesDao.watchFavoriteNotes(sort: sort).map(
      (rows) => rows.map(_toEntity).toList(),
    );
  }

  @override
  Future<List<NoteEntity>> getArchivedNotes({NoteSortMode sort = NoteSortMode.updatedDesc}) async {
    final rows = await _notesDao.getArchivedNotes(sort: sort);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<List<NoteEntity>> searchNotes(String query, {NoteSortMode sort = NoteSortMode.updatedDesc}) async {
    final rows = await _notesDao.searchNotes(query, sort: sort);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<NoteEntity?> getNoteById(String id) async {
    final row = await _notesDao.getNoteById(id);
    if (row == null) return null;
    return _toEntity(row);
  }

  @override
  Future<NoteEntity> createNote({required String title, required String body, String? categoryId}) async {
    final id = _generateUuid();
    final now = DateTime.now().toUtc();
    final companion = NotesTableCompanion(
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
  Future<NoteEntity> updateNote(NoteEntity note) async {
    final now = DateTime.now().toUtc();
    final updatedRevision = note.revision + 1;
    final companion = NotesTableCompanion(
      id: Value(note.id),
      title: Value(note.title),
      body: Value(note.body),
      categoryId: Value(note.categoryId),
      revision: Value(updatedRevision),
      isFavorite: Value(note.isFavorite),
      isArchived: Value(note.isArchived),
      isDeleted: const Value(false),
      createdAt: Value(note.createdAt),
      updatedAt: Value(now),
      lastOpenedAt: Value(note.lastOpenedAt),
    );

    await _notesDao.updateNote(companion);
    final row = await _notesDao.getNoteById(note.id);
    return _toEntity(row!);
  }

  @override
  Future<void> updateLastOpened(String id) async {
    final now = DateTime.now().toUtc();
    await _notesDao.updateLastOpened(id, now);
  }

  @override
  Future<void> toggleFavorite(String id) async {
    await _notesDao.toggleFavorite(id);
  }

  @override
  Future<void> archiveNote(String id) async {
    await _notesDao.archiveNote(id);
  }

  @override
  Future<void> restoreNote(String id) async {
    await _notesDao.restoreNote(id);
  }

  @override
  Future<void> softDeleteNote(String id) async {
    await _notesDao.softDeleteNote(id);
  }

  @override
  Future<void> permanentlyDeleteNote(String id) async {
    await _notesDao.deleteNotePermanently(id);
  }

  // Statistics Counts
  @override
  Future<int> notesCount() => _notesDao.countNotes();

  @override
  Future<int> favoritesCount() => _notesDao.countFavorites();

  @override
  Future<int> archivedCount() => _notesDao.countArchived();
}
