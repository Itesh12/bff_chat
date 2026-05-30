import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';

class HiddenSessionGuardMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final sessionService = Get.find<HiddenSessionService>();
    if (!sessionService.isActive) {
      return const RouteSettings(name: AppRoutes.hiddenPin);
    }
    return null;
  }
}
