import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/notes_repository.dart';
import 'package:memovault/domain/notes/note_sort_mode.dart';
import 'package:memovault/features/hidden/services/activation_trigger_service.dart';
import 'package:memovault/features/notes/controllers/notes_search_controller.dart';

class FakeNotesRepository implements NotesRepository {
  @override
  Future<List<NoteEntity>> searchNotes(String query, {NoteSortMode sort = NoteSortMode.updatedDesc}) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('NotesSearchController Activation Conflict Tests', () {
    late FakeNotesRepository fakeRepository;
    late NotesSearchController controller;

    setUp(() {
      Get.testMode = true;
      Get.reset();
      
      // Put the services into GetX
      Get.put(ActivationTriggerService());
      fakeRepository = FakeNotesRepository();
      controller = NotesSearchController(fakeRepository);
      Get.put(controller);
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('Typing .1234 character by character during onQueryChanged does NOT trigger activation', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.notes,
          getPages: [
            GetPage(name: AppRoutes.notes, page: () => const Scaffold(body: Text('Notes Dashboard'))),
            GetPage(name: AppRoutes.hiddenPin, page: () => const Scaffold(body: Text('Hidden PIN'))),
          ],
          defaultTransition: Transition.noTransition,
          transitionDuration: Duration.zero,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(Get.currentRoute, AppRoutes.notes);

      controller.onQueryChanged('.');
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.query.value, '.');
      expect(Get.currentRoute, AppRoutes.notes);

      controller.onQueryChanged('.1');
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.query.value, '.1');
      expect(Get.currentRoute, AppRoutes.notes);

      controller.onQueryChanged('.12');
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.query.value, '.12');
      expect(Get.currentRoute, AppRoutes.notes);

      controller.onQueryChanged('.123');
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.query.value, '.123');
      expect(Get.currentRoute, AppRoutes.notes);

      controller.onQueryChanged('.1234');
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.query.value, '.1234');
      expect(Get.currentRoute, AppRoutes.notes); // Still notes screen, did not navigate yet!

      // Drain debounce timers
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('submitQuery(".1234") DOES trigger navigation to hidden pin and clears search state', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.notes,
          getPages: [
            GetPage(name: AppRoutes.notes, page: () => const Scaffold(body: Text('Notes Dashboard'))),
            GetPage(name: AppRoutes.hiddenPin, page: () => const Scaffold(body: Text('Hidden PIN'))),
          ],
          defaultTransition: Transition.noTransition,
          transitionDuration: Duration.zero,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(Get.currentRoute, AppRoutes.notes);

      controller.submitQuery('.1234');
      await tester.pump(const Duration(milliseconds: 100));

      // Assert it navigated to Hidden PIN route
      expect(Get.currentRoute, AppRoutes.hiddenPin);

      // Assert search state is fully cleared for security
      expect(controller.query.value, '');
      expect(controller.results, isEmpty);
      expect(controller.isSearching.value, isFalse);

      // Drain debounce timers
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('submitQuery(".123") with wrong length does NOT trigger navigation', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.notes,
          getPages: [
            GetPage(name: AppRoutes.notes, page: () => const Scaffold(body: Text('Notes Dashboard'))),
            GetPage(name: AppRoutes.hiddenPin, page: () => const Scaffold(body: Text('Hidden PIN'))),
          ],
          defaultTransition: Transition.noTransition,
          transitionDuration: Duration.zero,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(Get.currentRoute, AppRoutes.notes);

      controller.submitQuery('.123');
      await tester.pump(const Duration(milliseconds: 100));

      expect(Get.currentRoute, AppRoutes.notes);
      expect(controller.query.value, '.123');

      // Drain debounce timers
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('submitQuery(".12345") with too long input does NOT trigger navigation', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.notes,
          getPages: [
            GetPage(name: AppRoutes.notes, page: () => const Scaffold(body: Text('Notes Dashboard'))),
            GetPage(name: AppRoutes.hiddenPin, page: () => const Scaffold(body: Text('Hidden PIN'))),
          ],
          defaultTransition: Transition.noTransition,
          transitionDuration: Duration.zero,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(Get.currentRoute, AppRoutes.notes);

      controller.submitQuery('.12345');
      await tester.pump(const Duration(milliseconds: 100));

      expect(Get.currentRoute, AppRoutes.notes);
      expect(controller.query.value, '.12345');

      // Drain debounce timers
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('submitQuery("hello.1234") with partial suffix match does NOT trigger navigation', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.notes,
          getPages: [
            GetPage(name: AppRoutes.notes, page: () => const Scaffold(body: Text('Notes Dashboard'))),
            GetPage(name: AppRoutes.hiddenPin, page: () => const Scaffold(body: Text('Hidden PIN'))),
          ],
          defaultTransition: Transition.noTransition,
          transitionDuration: Duration.zero,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(Get.currentRoute, AppRoutes.notes);

      controller.submitQuery('hello.1234');
      await tester.pump(const Duration(milliseconds: 100));

      expect(Get.currentRoute, AppRoutes.notes);
      expect(controller.query.value, 'hello.1234');

      // Drain debounce timers
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
