import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/note_sort_mode.dart';
import 'package:memovault/domain/notes/notes_repository.dart';
import 'package:memovault/features/notes/controllers/notes_search_controller.dart';

class FakeNotesRepository implements NotesRepository {
  final List<NoteEntity> _notes = [];
  int searchCallCount = 0;

  void addNote(NoteEntity note) => _notes.add(note);

  @override
  Future<List<NoteEntity>> searchNotes(String query, {NoteSortMode sort = NoteSortMode.updatedDesc}) async {
    searchCallCount++;
    return _notes.where(
      (n) => n.title.contains(query) || n.body.contains(query),
    ).toList();
  }

  // Stubs for interface completeness
  @override
  Stream<List<NoteEntity>> watchAllNotes({NoteSortMode sort = NoteSortMode.updatedDesc}) => throw UnimplementedError();
  @override
  Stream<List<NoteEntity>> watchFavoriteNotes({NoteSortMode sort = NoteSortMode.updatedDesc}) => throw UnimplementedError();
  @override
  Future<List<NoteEntity>> getArchivedNotes({NoteSortMode sort = NoteSortMode.updatedDesc}) => throw UnimplementedError();
  @override
  Future<NoteEntity?> getNoteById(String id) => throw UnimplementedError();
  @override
  Future<NoteEntity> createNote({required String title, required String body, String? categoryId}) => throw UnimplementedError();
  @override
  Future<NoteEntity> updateNote(NoteEntity note) => throw UnimplementedError();
  @override
  Future<void> updateLastOpened(String id) => throw UnimplementedError();
  @override
  Future<void> toggleFavorite(String id) => throw UnimplementedError();
  @override
  Future<void> archiveNote(String id) => throw UnimplementedError();
  @override
  Future<void> restoreNote(String id) => throw UnimplementedError();
  @override
  Future<void> softDeleteNote(String id) => throw UnimplementedError();
  @override
  Future<void> permanentlyDeleteNote(String id) => throw UnimplementedError();
  @override
  Future<int> notesCount() => throw UnimplementedError();
  @override
  Future<int> favoritesCount() => throw UnimplementedError();
  @override
  Future<int> archivedCount() => throw UnimplementedError();
}

void main() {
  group('NotesSearchController Tests', () {
    late FakeNotesRepository repository;
    late NotesSearchController controller;

    setUp(() {
      repository = FakeNotesRepository();
      controller = NotesSearchController(repository);
      
      final now = DateTime.now();
      repository.addNote(NoteEntity(
        id: '1',
        title: 'Meeting Notes',
        body: 'Discuss next quarters marketing plan.',
        revision: 1,
        isFavorite: false,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      ));
      repository.addNote(NoteEntity(
        id: '2',
        title: 'Shopping List',
        body: 'Milk, Eggs, Bread, Butter',
        revision: 1,
        isFavorite: true,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      ));
    });

    test('should not fire search if query is less than 2 characters', () async {
      controller.onInit();
      controller.onQueryChanged('a');
      
      await Future.delayed(const Duration(milliseconds: 350));

      expect(controller.results.length, 0);
      expect(repository.searchCallCount, 0);
      controller.onClose();
    });

    test('should execute search and populate results when query is 2+ chars', () async {
      controller.onInit();
      controller.onQueryChanged('Meet');
      
      await Future.delayed(const Duration(milliseconds: 350));

      expect(controller.results.length, 1);
      expect(controller.results[0].title, 'Meeting Notes');
      expect(repository.searchCallCount, 1);
      controller.onClose();
    });

    test('should trigger onQuerySubmitted callback on query submission', () {
      bool isCalled = false;
      controller.onQuerySubmitted = () {
        isCalled = true;
      };

      controller.submitQuery('Meet');

      expect(isCalled, isTrue);
      expect(controller.query.value, 'Meet');
    });
  });
}
