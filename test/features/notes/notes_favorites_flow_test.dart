import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/data/notes/notes_dao.dart';
import 'package:memovault/data/notes/notes_repository_impl.dart';

void main() {
  group('Public Notes Favorites Flow Integration Tests', () {
    late AppDatabase db;
    late NotesRepositoryImpl repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = NotesRepositoryImpl(NotesDao(db));
    });

    tearDown(() async {
      await db.close();
    });

    test('Favorites Lifecycle: Create -> Star -> Unstar -> Star & Soft Delete', () async {
      // 1. Create note
      final note = await repo.createNote(title: 'Fav Note 1', body: 'Fav Content');
      final id = note.id;

      var favList = await repo.watchFavoriteNotes().first;
      expect(favList.any((n) => n.id == id), false);

      // 2. Favorite (toggle on)
      await repo.toggleFavorite(id);

      favList = await repo.watchFavoriteNotes().first;
      expect(favList.any((n) => n.id == id), true);

      // 3. Unfavorite (toggle off)
      await repo.toggleFavorite(id);

      favList = await repo.watchFavoriteNotes().first;
      expect(favList.any((n) => n.id == id), false);

      // 4. Star again and soft delete
      await repo.toggleFavorite(id);
      await repo.softDeleteNote(id);

      // A soft deleted favorite note must not appear in active favorites list
      favList = await repo.watchFavoriteNotes().first;
      expect(favList.any((n) => n.id == id), false);
    });
  });
}
