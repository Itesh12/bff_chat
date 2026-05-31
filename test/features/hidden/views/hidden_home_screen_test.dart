import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';
import 'package:memovault/features/hidden/domain/entities/hidden_note_entity.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_notes_repository.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_categories_repository.dart';
import 'package:memovault/domain/notes/category_entity.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';
import 'package:memovault/features/hidden/views/hidden_home_screen.dart';

class FakeHiddenNotesRepository implements HiddenNotesRepository {
  final List<HiddenNoteEntity> _notes = [];
  final StreamController<List<HiddenNoteEntity>> _notesStreamController =
      StreamController<List<HiddenNoteEntity>>.broadcast();

  int createCallCount = 0;
  int updateCallCount = 0;
  int deleteCallCount = 0;
  int softDeleteCallCount = 0;
  int toggleFavoriteCallCount = 0;

  void addNote(HiddenNoteEntity note) {
    _notes.add(note);
    _notesStreamController.add(List.from(_notes));
  }

  @override
  Stream<List<HiddenNoteEntity>> watchAllNotes() {
    Timer.run(() {
      if (!_notesStreamController.isClosed) {
        _notesStreamController.add(List.from(_notes));
      }
    });
    return _notesStreamController.stream;
  }

  @override
  Future<HiddenNoteEntity?> getNoteById(String id) async {
    return _notes.firstWhere((n) => n.id == id);
  }

  @override
  Future<HiddenNoteEntity> createNote({required String title, required String body, String? categoryId}) async {
    createCallCount++;
    final note = HiddenNoteEntity(
      id: 'note-${_notes.length + 1}',
      title: title,
      body: body,
      categoryId: categoryId,
      revision: 1,
      isFavorite: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    addNote(note);
    return note;
  }

  @override
  Future<HiddenNoteEntity> updateNote(HiddenNoteEntity note) async {
    updateCallCount++;
    final idx = _notes.indexWhere((n) => n.id == note.id);
    if (idx != -1) {
      _notes[idx] = note;
      _notesStreamController.add(List.from(_notes));
    }
    return note;
  }

  @override
  Future<void> updateLastOpened(String id) async {}

  @override
  Future<void> toggleFavorite(String id) async {
    toggleFavoriteCallCount++;
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notes[idx] = _notes[idx].copyWith(isFavorite: !_notes[idx].isFavorite);
      _notesStreamController.add(List.from(_notes));
    }
  }

  @override
  Future<void> permanentlyDeleteNote(String id) async {
    deleteCallCount++;
    _notes.removeWhere((n) => n.id == id);
    _notesStreamController.add(List.from(_notes));
  }

  @override
  Future<int> notesCount() async => _notes.length;

  @override
  Stream<List<HiddenNoteEntity>> watchFavoriteNotes() {
    return _notesStreamController.stream.map((list) => list.where((n) => n.isFavorite && !n.isDeleted).toList());
  }

  @override
  Future<List<HiddenNoteEntity>> getArchivedNotes() async {
    return _notes.where((n) => n.isArchived && !n.isDeleted).toList();
  }

  @override
  Future<List<HiddenNoteEntity>> getTrashedNotes() async {
    return _notes.where((n) => n.isDeleted).toList();
  }

  @override
  Future<List<HiddenNoteEntity>> searchNotes(String query) async {
    final q = query.toLowerCase();
    return _notes.where((n) => !n.isArchived && !n.isDeleted && (n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q))).toList();
  }

  @override
  Future<void> archiveNote(String id) async {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notes[idx] = _notes[idx].copyWith(isArchived: true);
      _notesStreamController.add(List.from(_notes));
    }
  }

  @override
  Future<void> restoreNote(String id) async {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notes[idx] = _notes[idx].copyWith(isArchived: false, isDeleted: false, deletedAt: null);
      _notesStreamController.add(List.from(_notes));
    }
  }

  @override
  Future<void> softDeleteNote(String id) async {
    softDeleteCallCount++;
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notes[idx] = _notes[idx].copyWith(isDeleted: true, deletedAt: DateTime.now());
      _notesStreamController.add(List.from(_notes));
    }
  }

  @override
  Future<void> emptyTrash() async {
    _notes.removeWhere((n) => n.isDeleted);
    _notesStreamController.add(List.from(_notes));
  }

  @override
  Future<int> favoritesCount() async => _notes.where((n) => n.isFavorite && !n.isDeleted).length;

  @override
  Future<int> archivedCount() async => _notes.where((n) => n.isArchived && !n.isDeleted).length;

  @override
  Future<int> trashedCount() async => _notes.where((n) => n.isDeleted).length;

  void dispose() {
    _notesStreamController.close();
  }
}

class FakeHiddenCategoriesRepository implements HiddenCategoriesRepository {
  final List<CategoryEntity> _categories = [];

  @override
  Future<List<CategoryEntity>> getAllCategories() async => _categories;

  @override
  Future<CategoryEntity> createCategory({required String name, required String colorHex}) async {
    final cat = CategoryEntity(
      id: 'cat-${_categories.length + 1}',
      name: name,
      colorHex: colorHex,
      displayOrder: _categories.length,
      createdAt: DateTime.now(),
    );
    _categories.add(cat);
    return cat;
  }

  @override
  Future<CategoryEntity> updateCategory(CategoryEntity category) async {
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx != -1) {
      _categories[idx] = category;
    }
    return category;
  }

  @override
  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> reorderCategories(List<String> orderedIds) async {}
}

class FakeHiddenSessionService extends GetxService with WidgetsBindingObserver implements HiddenSessionService {
  int lockCallCount = 0;
  int resetTimerCallCount = 0;

  @override
  final Rx<HiddenSessionState> state = HiddenSessionState.active.obs;

  @override
  bool get isLocked => state.value == HiddenSessionState.locked;
  @override
  bool get isActive => state.value == HiddenSessionState.active;
  @override
  bool get isActivating => state.value == HiddenSessionState.activating;

  @override
  void activateSession() {}

  @override
  void lockSession() {
    lockCallCount++;
    state.value = HiddenSessionState.locked;
  }

  @override
  void startActivating() {}

  @override
  void resetInactivityTimer() {
    resetTimerCallCount++;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HiddenHomeScreen Widget Tests', () {
    late FakeHiddenNotesRepository fakeRepository;
    late FakeHiddenCategoriesRepository fakeCategoriesRepository;
    late FakeHiddenSessionService fakeSessionService;
    late HiddenHomeController controller;

    setUp(() {
      fakeRepository = FakeHiddenNotesRepository();
      fakeCategoriesRepository = FakeHiddenCategoriesRepository();
      fakeSessionService = FakeHiddenSessionService();
      controller = HiddenHomeController(fakeRepository, fakeCategoriesRepository, fakeSessionService);
      Get.put<HiddenHomeController>(controller);
    });

    tearDown(() async {
      fakeRepository.dispose();
      await Get.delete<HiddenHomeController>();
    });

    testWidgets('displays AppEmptyState when no notes are present', (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: HiddenHomeScreen(),
        ),
      );

      await tester.pump(Duration.zero);

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('No Hidden Notes'), findsOneWidget);
    });

    testWidgets('renders list of notes when notes are present', (tester) async {
      fakeRepository.addNote(HiddenNoteEntity(
        id: '1',
        title: 'Secret Agent Code',
        body: 'The code is 007.',
        revision: 1,
        isFavorite: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await tester.pumpWidget(
        const GetMaterialApp(
          home: HiddenHomeScreen(),
        ),
      );

      await tester.pump(Duration.zero);

      expect(find.text('Secret Agent Code'), findsOneWidget);
      expect(find.text('The code is 007.'), findsOneWidget);
      expect(find.byType(AppEmptyState), findsNothing);
    });

    testWidgets('favorite action propagates to repository', (tester) async {
      fakeRepository.addNote(HiddenNoteEntity(
        id: '1',
        title: 'Secret Agent Code',
        body: 'The code is 007.',
        revision: 1,
        isFavorite: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await tester.pumpWidget(
        const GetMaterialApp(
          home: HiddenHomeScreen(),
        ),
      );

      await tester.pump(Duration.zero);

      final favoriteFinder = find.byIcon(Icons.star_border_rounded);
      expect(favoriteFinder, findsOneWidget);
      await tester.tap(favoriteFinder);
      await tester.pumpAndSettle();

      expect(fakeRepository.toggleFavoriteCallCount, 1);
      expect(fakeSessionService.resetTimerCallCount, greaterThanOrEqualTo(1));
    });
  });
}
