import 'package:get/get.dart';
import 'package:memovault/core/services/network_service.dart';

class InitialBinding implements Bindings {
  @override
  void dependencies() {
    // Register global services.
    // As per standardized DI strategy, application-wide services are registered permanently.
    Get.put<NetworkService>(NetworkService(), permanent: true);
  }
}

