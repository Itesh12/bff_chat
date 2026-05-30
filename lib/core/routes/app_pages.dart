import 'package:get/get.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/features/home/views/home_screen.dart';
import 'package:memovault/features/theme_sandbox/views/theme_sandbox_screen.dart';

import 'package:memovault/features/notes/bindings/notes_binding.dart';
import 'package:memovault/features/notes/views/notes_dashboard_screen.dart';
import 'package:memovault/features/notes/views/note_editor_screen.dart';
import 'package:memovault/features/notes/views/note_detail_screen.dart';
import 'package:memovault/features/notes/views/notes_search_screen.dart';
import 'package:memovault/features/notes/views/notes_archive_screen.dart';
import 'package:memovault/features/notes/views/categories_screen.dart';

abstract final class AppPages {
  static final List<GetPage<dynamic>> pages = [
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
    ),
    GetPage(
      name: AppRoutes.themeSandbox,
      page: () => const ThemeSandboxScreen(),
    ),
    GetPage(
      name: AppRoutes.notes,
      page: () => const NotesDashboardScreen(),
      binding: NotesBinding(),
    ),
    GetPage(
      name: AppRoutes.noteEditor,
      page: () => const NoteEditorScreen(),
      binding: NotesBinding(),
    ),
    GetPage(
      name: '${AppRoutes.noteDetail}/:id',
      page: () => const NoteDetailScreen(),
      binding: NotesBinding(),
    ),
    GetPage(
      name: AppRoutes.notesSearch,
      page: () => const NotesSearchScreen(),
      binding: NotesBinding(),
    ),
    GetPage(
      name: AppRoutes.notesArchive,
      page: () => const NotesArchiveScreen(),
      binding: NotesBinding(),
    ),
    GetPage(
      name: AppRoutes.categories,
      page: () => const CategoriesScreen(),
      binding: NotesBinding(),
    ),
  ];
}
