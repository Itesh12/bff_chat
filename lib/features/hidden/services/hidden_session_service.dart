import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/features/hidden/services/hidden_vault_service.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';
import 'package:memovault/features/hidden/controllers/hidden_activation_controller.dart';
import 'package:memovault/data/messaging/services/media_transfer_service_impl.dart';

enum HiddenSessionState { locked, activating, active }

class HiddenSessionService extends GetxService with WidgetsBindingObserver {
  final HiddenVaultService _vaultService;

  HiddenSessionService(this._vaultService);

  final Rx<HiddenSessionState> state = HiddenSessionState.locked.obs;
  Timer? _inactivityTimer;

  bool get isLocked => state.value == HiddenSessionState.locked;
  bool get isActive => state.value == HiddenSessionState.active;
  bool get isActivating => state.value == HiddenSessionState.activating;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.onClose();
  }

  void startActivating() {
    state.value = HiddenSessionState.activating;
  }

  void activateSession() {
    state.value = HiddenSessionState.active;
    resetInactivityTimer();
    AppLogger.info('[HiddenSessionService] Session activated.');
  }

  void lockSession() {
    _inactivityTimer?.cancel();
    if (state.value != HiddenSessionState.locked) {
      state.value = HiddenSessionState.locked;
      _vaultService.lockVault();
      MediaTransferServiceImpl.purgeDecryptedCache();
      AppLogger.info('[HiddenSessionService] Session locked.');

      // Auto-redirect out of hidden vault routes on lock
      final currentRoute = Get.currentRoute;
      if (currentRoute.startsWith('/hidden')) {
        Get.offAllNamed(AppRoutes.notes);
        Get.delete<HiddenHomeController>(force: true);
        Get.delete<HiddenActivationController>(force: true);
      }
    }
  }

  void resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (isActive) {
      _inactivityTimer = Timer(const Duration(minutes: 5), () {
        AppLogger.info('[HiddenSessionService] 5-minute inactivity timer expired.');
        lockSession();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock only on true background or termination — not on transient inactive state
    // (e.g. notification shade, incoming call UI, system dialog).
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      AppLogger.info('[HiddenSessionService] App backgrounded ($state). Locking.');
      lockSession();
    }
  }
}
