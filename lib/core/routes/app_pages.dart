import 'package:get/get.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/features/theme_sandbox/views/theme_sandbox_screen.dart';

import 'package:memovault/features/notes/bindings/notes_binding.dart';
import 'package:memovault/features/notes/views/notes_dashboard_screen.dart';
import 'package:memovault/features/notes/views/note_editor_screen.dart';
import 'package:memovault/features/notes/views/note_detail_screen.dart';
import 'package:memovault/features/notes/views/notes_search_screen.dart';
import 'package:memovault/features/notes/views/notes_archive_screen.dart';
import 'package:memovault/features/notes/views/notes_favorites_screen.dart';
import 'package:memovault/features/notes/views/notes_trash_screen.dart';
import 'package:memovault/features/notes/views/categories_screen.dart';

import 'package:memovault/features/hidden/bindings/hidden_binding.dart';
import 'package:memovault/features/hidden/middleware/hidden_session_guard_middleware.dart';
import 'package:memovault/features/hidden/views/hidden_pin_screen.dart';
import 'package:memovault/features/hidden/views/hidden_home_screen.dart';
import 'package:memovault/features/hidden/views/hidden_note_editor_screen.dart';
import 'package:memovault/features/hidden/views/hidden_chat_screen.dart';
import 'package:memovault/features/hidden/views/messaging_setup_flow_screens.dart';
import 'package:memovault/features/hidden/views/messaging_profile_screen.dart';

abstract final class AppPages {
  static final List<GetPage<dynamic>> pages = [
    GetPage(
      name: AppRoutes.themeSandbox,
      page: () => const DesignSystemSandboxScreen(),
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
      name: AppRoutes.notesFavorites,
      page: () => const NotesFavoritesScreen(),
      binding: NotesBinding(),
    ),
    GetPage(
      name: AppRoutes.notesTrash,
      page: () => const NotesTrashScreen(),
      binding: NotesBinding(),
    ),
    GetPage(
      name: AppRoutes.categories,
      page: () => const CategoriesScreen(),
      binding: NotesBinding(),
    ),
    GetPage(
      name: AppRoutes.hiddenPin,
      page: () => const HiddenPinScreen(),
      binding: HiddenBinding(),
    ),
    GetPage(
      name: AppRoutes.hiddenHome,
      page: () => const HiddenHomeScreen(),
      binding: HiddenBinding(),
      middlewares: [HiddenSessionGuardMiddleware()],
    ),
    GetPage(
      name: AppRoutes.hiddenArchive,
      page: () => const NotesArchiveScreen(isHiddenMode: true),
      binding: HiddenBinding(),
      middlewares: [HiddenSessionGuardMiddleware()],
    ),
    GetPage(
      name: AppRoutes.hiddenTrash,
      page: () => const NotesTrashScreen(isHiddenMode: true),
      binding: HiddenBinding(),
      middlewares: [HiddenSessionGuardMiddleware()],
    ),
    GetPage(
      name: AppRoutes.hiddenFavorites,
      page: () => const NotesFavoritesScreen(isHiddenMode: true),
      binding: HiddenBinding(),
      middlewares: [HiddenSessionGuardMiddleware()],
    ),
    GetPage(
      name: AppRoutes.hiddenSearch,
      page: () => const NotesSearchScreen(isHiddenMode: true),
      binding: HiddenBinding(),
      middlewares: [HiddenSessionGuardMiddleware()],
    ),
    GetPage(
      name: AppRoutes.hiddenEditor,
      page: () => const HiddenNoteEditorScreen(),
      binding: HiddenBinding(),
      middlewares: [HiddenSessionGuardMiddleware()],
    ),
    GetPage(
      name: AppRoutes.hiddenChat,
      page: () => const HiddenChatScreen(),
      binding: HiddenBinding(),
      middlewares: [HiddenSessionGuardMiddleware()],
    ),
    GetPage(
      name: AppRoutes.hiddenMessagingSetup,
      page: () => const MessagingSetupFlowView(),
      binding: HiddenBinding(),
      middlewares: [HiddenSessionGuardMiddleware()],
    ),
    GetPage(
      name: AppRoutes.hiddenMessagingProfile,
      page: () => const MessagingProfileScreen(),
      binding: HiddenBinding(),
      middlewares: [HiddenSessionGuardMiddleware()],
    ),
  ];
}
