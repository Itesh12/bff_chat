import 'package:get/get.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/core/services/network_service.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/data/messaging/messaging_repository_impl.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'package:memovault/features/hidden/services/activation_trigger_service.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';
import 'package:memovault/features/hidden/services/hidden_vault_service.dart';
import 'package:memovault/features/hidden/services/pin_hashing_service.dart';

class InitialBinding implements Bindings {
  @override
  void dependencies() {
    // Register global services.
    // As per standardized DI strategy, application-wide services are registered permanently.
    Get.put<NetworkService>(NetworkService(), permanent: true);

    // Register hidden vault foundation services
    Get.put<ActivationTriggerService>(ActivationTriggerService(), permanent: true);
    final pinHashingService = Get.put<PinHashingService>(PinHashingService(), permanent: true);
    final vaultService = Get.put<HiddenVaultService>(
      HiddenVaultService(Get.find<SecureStorageService>(), pinHashingService),
      permanent: true,
    );
    Get.put<HiddenSessionService>(HiddenSessionService(vaultService), permanent: true);

    // Register Messaging Repository globally
    Get.put<MessagingRepository>(
      MessagingRepositoryImpl(
        Get.find<DatabaseService>(),
        vaultService,
      ),
      permanent: true,
    );
  }
}

