import 'package:get/get.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/core/services/notes_preferences_service.dart';
import 'package:memovault/core/services/preferences_service.dart';
import 'package:memovault/data/notes/notes_dao.dart';
import 'package:memovault/data/notes/categories_dao.dart';
import 'package:memovault/data/notes/notes_repository_impl.dart';
import 'package:memovault/data/notes/categories_repository_impl.dart';
import 'package:memovault/domain/notes/notes_repository.dart';
import 'package:memovault/domain/notes/categories_repository.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';
import 'package:memovault/features/notes/controllers/notes_search_controller.dart';

class NotesBinding extends Bindings {
  @override
  void dependencies() {
    final db = Get.find<DatabaseService>().db;

    // Services
    Get.lazyPut<NotesPreferencesService>(
      () => NotesPreferencesService(Get.find<PreferencesService>()),
      fenix: true,
    );

    // DAOs
    Get.lazyPut<NotesDao>(() => NotesDao(db), fenix: true);
    Get.lazyPut<CategoriesDao>(() => CategoriesDao(db), fenix: true);

    // Repositories
    Get.lazyPut<NotesRepository>(
      () => NotesRepositoryImpl(Get.find<NotesDao>()),
      fenix: true,
    );
    Get.lazyPut<CategoriesRepository>(
      () => CategoriesRepositoryImpl(Get.find<CategoriesDao>()),
      fenix: true,
    );

    // Controllers
    Get.lazyPut<NotesController>(
      () => NotesController(
        Get.find<NotesRepository>(),
        Get.find<CategoriesRepository>(),
        Get.find<NotesPreferencesService>(),
      ),
    );
    Get.lazyPut<NotesSearchController>(
      () => NotesSearchController(Get.find<NotesRepository>()),
    );
  }
}
