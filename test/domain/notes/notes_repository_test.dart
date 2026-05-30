import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/data/notes/notes_dao.dart';
import 'package:memovault/data/notes/categories_dao.dart';
import 'package:memovault/data/notes/notes_repository_impl.dart';
import 'package:memovault/data/notes/categories_repository_impl.dart';
import 'package:memovault/domain/notes/note_sort_mode.dart';

void main() {
  group('Notes & Categories Repository SQLite Integration Tests', () {
    late AppDatabase db;
    late NotesDao notesDao;
    late CategoriesDao categoriesDao;
    late NotesRepositoryImpl notesRepo;
    late CategoriesRepositoryImpl categoriesRepo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      notesDao = NotesDao(db);
      categoriesDao = CategoriesDao(db);
      notesRepo = NotesRepositoryImpl(notesDao);
      categoriesRepo = CategoriesRepositoryImpl(categoriesDao);
    });

    tearDown(() async {
      await db.close();
    });

    test('should perform Category CRUD operations successfully', () async {
      final category = await categoriesRepo.createCategory(name: 'Personal', colorHex: 'E74C3C');
      expect(category.name, 'Personal');
      expect(category.colorHex, 'E74C3C');
      expect(category.displayOrder, 0);

      final categoriesList = await categoriesRepo.getAllCategories();
      expect(categoriesList.length, 1);
      expect(categoriesList[0].id, category.id);

      final updated = category.copyWith(name: 'Private Work');
      await categoriesRepo.updateCategory(updated);

      final updatedList = await categoriesRepo.getAllCategories();
      expect(updatedList[0].name, 'Private Work');

      await categoriesRepo.deleteCategory(category.id);
      final emptyList = await categoriesRepo.getAllCategories();
      expect(emptyList.length, 0);
    });

    test('should perform Note CRUD and statistics operations successfully', () async {
      final category = await categoriesRepo.createCategory(name: 'Work', colorHex: '3498DB');

      final note1 = await notesRepo.createNote(title: 'First Note', body: 'This is body of first note.', categoryId: category.id);
      final note2 = await notesRepo.createNote(title: 'Second Note', body: 'Buy groceries and milk.', categoryId: null);

      expect(note1.title, 'First Note');
      expect(note1.categoryId, category.id);
      expect(note1.revision, 1);

      expect(note2.title, 'Second Note');
      expect(note2.categoryId, isNull);
      expect(note2.revision, 1);

      expect(await notesRepo.notesCount(), 2);
      expect(await notesRepo.favoritesCount(), 0);
      expect(await notesRepo.archivedCount(), 0);

      await notesRepo.toggleFavorite(note1.id);
      expect(await notesRepo.favoritesCount(), 1);

      await notesRepo.archiveNote(note2.id);
      expect(await notesRepo.notesCount(), 1);
      expect(await notesRepo.archivedCount(), 1);

      final updatedNote = note1.copyWith(title: 'Updated First Title', body: 'Updated body.');
      final result = await notesRepo.updateNote(updatedNote);
      expect(result.title, 'Updated First Title');
      expect(result.revision, 2);

      await notesRepo.restoreNote(note2.id);
      expect(await notesRepo.notesCount(), 2);
      expect(await notesRepo.archivedCount(), 0);

      await notesRepo.softDeleteNote(note1.id);
      expect(await notesRepo.notesCount(), 1);

      await notesRepo.permanentlyDeleteNote(note1.id);
      final empty = await notesRepo.getNoteById(note1.id);
      expect(empty, isNull);
    });

    test('should sort notes properly based on NoteSortMode', () async {
      await notesRepo.createNote(title: 'Apple', body: 'Red fruit');
      await Future.delayed(const Duration(milliseconds: 10));
      await notesRepo.createNote(title: 'Banana', body: 'Yellow fruit');

      final listAZ = await notesRepo.searchNotes('', sort: NoteSortMode.titleAZ);
      expect(listAZ[0].title, 'Apple');
      expect(listAZ[1].title, 'Banana');

      final listZA = await notesRepo.searchNotes('', sort: NoteSortMode.titleZA);
      expect(listZA[0].title, 'Banana');
      expect(listZA[1].title, 'Apple');
    });
  });
}
