import 'package:get/get.dart';
import 'package:memovault/features/hidden/controllers/hidden_activation_controller.dart';
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';
import 'package:memovault/features/hidden/data/repositories/hidden_notes_repository_impl.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_notes_repository.dart';
import 'package:memovault/features/hidden/services/hidden_vault_service.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';

class HiddenBinding extends Bindings {
  @override
  void dependencies() {
    // Repositories — only resolved once the vault database is open
    Get.lazyPut<HiddenNotesRepository>(
      () => HiddenNotesRepositoryImpl(Get.find<HiddenVaultService>().notesDao!),
      fenix: true,
    );

    // Controllers
    Get.lazyPut<HiddenActivationController>(
      () => HiddenActivationController(
        Get.find<HiddenVaultService>(),
        Get.find<HiddenSessionService>(),
      ),
    );

    Get.lazyPut<HiddenHomeController>(
      () => HiddenHomeController(
        Get.find<HiddenNotesRepository>(),
        Get.find<HiddenSessionService>(),
      ),
    );
  }
}
