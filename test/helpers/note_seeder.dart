// ignore_for_file: prefer_const_constructors
import 'package:drift/drift.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';

class NoteSeeder {
  static Future<void> seedPublicNotes(AppDatabase db, int count) async {
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    await db.batch((batch) {
      for (int i = 0; i < count; i++) {
        batch.insert(
          db.notesTable,
          NotesTableCompanion(
            id: Value('pub_${nowUs}_$i'),
            title: Value('Public Note Title $i'),
            body: Value('This is the body of public note $i. It contains some text for search benchmark testing.'),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
            revision: Value(1),
            isArchived: Value(false),
            isFavorite: Value(i % 10 == 0), // 10% favorites
            isDeleted: Value(false),
          ),
        );
      }
    });
  }

  static Future<void> seedHiddenNotes(HiddenVaultDatabase db, int count) async {
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    await db.batch((batch) {
      for (int i = 0; i < count; i++) {
        batch.insert(
          db.hiddenNotesTable,
          HiddenNotesTableCompanion(
            id: Value('hid_${nowUs}_$i'),
            title: Value('Secret Note Title $i'),
            body: Value('This is the body of secret note $i. It contains some confidential text for search benchmarking.'),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
            revision: Value(1),
            isArchived: Value(false),
            isFavorite: Value(i % 10 == 0),
            isDeleted: Value(false),
          ),
        );
      }
    });
  }
}
