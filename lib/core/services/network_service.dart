import 'package:get/get.dart';

/// Service to monitor network connectivity status.
class NetworkService extends GetxService {
  final RxBool _isConnected = true.obs;

  bool get isConnected => _isConnected.value;

  Future<void> init() async {
    // Initializer logic for connectivity checking.
  }
}
