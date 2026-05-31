import 'package:get/get.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'package:memovault/features/hidden/controllers/hidden_activation_controller.dart';
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';
import 'package:memovault/features/hidden/controllers/hidden_messaging_controller.dart';
import 'package:memovault/features/hidden/data/repositories/hidden_notes_repository_impl.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_notes_repository.dart';
import 'package:memovault/features/hidden/data/repositories/hidden_categories_repository_impl.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_categories_repository.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/hidden/services/seed_recovery_service.dart';
import 'package:memovault/features/hidden/controllers/messaging_setup_controller.dart';
import 'package:memovault/features/hidden/services/hidden_vault_service.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';
import 'package:memovault/features/messaging/services/signal_session_manager.dart';
import 'package:memovault/features/messaging/services/signal_sync_service.dart';
import 'package:memovault/core/services/secure_storage_service.dart';

class HiddenBinding extends Bindings {
  @override
  void dependencies() {
    // Repositories — only resolved once the vault database is open
    Get.lazyPut<HiddenNotesRepository>(
      () => HiddenNotesRepositoryImpl(Get.find<HiddenVaultService>().notesDao!),
      fenix: true,
    );

    Get.lazyPut<HiddenCategoriesRepository>(
      () => HiddenCategoriesRepositoryImpl(Get.find<HiddenVaultService>().categoriesDao!),
      fenix: true,
    );

    // Services
    Get.lazyPut<SeedRecoveryService>(
      () => SeedRecoveryServiceImpl(),
    );

    Get.lazyPut<MessagingIdentityService>(
      () => MessagingIdentityServiceImpl(Get.find()),
    );

    Get.lazyPut<SignalSessionManager>(
      () => SignalSessionManager(
        Get.find<MessagingIdentityService>(),
        Get.find<MessagingRepository>(),
        Get.find<SecureStorageService>(),
      ),
      fenix: true,
    );

    Get.put<SignalSyncService>(
      SignalSyncService(
        Get.find<SignalSessionManager>(),
        Get.find<MessagingIdentityService>(),
        Get.find<HiddenSessionService>(),
        Get.find<MessagingRepository>(),
      ),
      permanent: true,
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
        Get.find<HiddenCategoriesRepository>(),
        Get.find<HiddenSessionService>(),
      ),
    );

    Get.lazyPut<HiddenMessagingController>(
      () => HiddenMessagingController(
        Get.find<MessagingRepository>(),
        Get.find<HiddenSessionService>(),
        Get.find<MessagingIdentityService>(),
      ),
    );

    Get.lazyPut<MessagingSetupController>(
      () => MessagingSetupController(
        Get.find<MessagingIdentityService>(),
        Get.find<SeedRecoveryService>(),
      ),
    );
  }
}
