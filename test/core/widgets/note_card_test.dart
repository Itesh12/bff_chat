import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/widgets/note_card.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/category_entity.dart';

void main() {
  group('NoteCard Widget Tests', () {
    late NoteEntity testNote;
    late CategoryEntity testCategory;

    setUp(() {
      final now = DateTime.now();
      testNote = NoteEntity(
        id: 'note-123',
        title: 'Ideas for app',
        body: 'Create a local-first secure notes application with dynamic sorting.',
        categoryId: 'cat-456',
        revision: 1,
        isFavorite: true,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      testCategory = CategoryEntity(
        id: 'cat-456',
        name: 'Work',
        colorHex: '3498DB',
        displayOrder: 0,
        createdAt: now,
      );
    });

    testWidgets('should render note details correctly in grid layout', (tester) async {
      bool isTapped = false;
      bool isFavTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: testNote,
              category: testCategory,
              isGrid: true,
              onTap: () => isTapped = true,
              onFavoriteTap: () => isFavTapped = true,
            ),
          ),
        ),
      );

      // Verify title & body rendered
      expect(find.text('Ideas for app'), findsOneWidget);
      expect(find.text('Create a local-first secure notes application with dynamic sorting.'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget); // marked favorite

      // Tap on card
      await tester.tap(find.byType(NoteCard));
      expect(isTapped, isTrue);

      // Tap on favorite icon
      await tester.tap(find.byIcon(Icons.star));
      expect(isFavTapped, isTrue);
    });

    testWidgets('should render note details correctly in list layout', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: testNote.copyWith(isFavorite: false),
              category: null, // uncategorized
              isGrid: false,
              onTap: () {},
              onFavoriteTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Ideas for app'), findsOneWidget);
      expect(find.text('Create a local-first secure notes application with dynamic sorting.'), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsOneWidget); // non-favorite
      expect(find.text('Work'), findsNothing); // no category badge
    });
  });
}
