import 'package:get/get.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/features/hidden/services/hidden_vault_service.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';

class HiddenActivationController extends GetxController {
  final HiddenVaultService _vaultService;
  final HiddenSessionService _sessionService;

  HiddenActivationController(this._vaultService, this._sessionService);

  final RxBool isSetup = false.obs;
  final RxString pinInput = ''.obs;
  final RxString confirmInput = ''.obs;
  final RxBool isConfirmingMode = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _checkSetupStatus();
  }

  Future<void> _checkSetupStatus() async {
    isSetup.value = await _vaultService.isVaultSetup();
  }

  void appendDigit(String digit) {
    errorMessage.value = '';
    if (isConfirmingMode.value) {
      if (confirmInput.value.length < 4) {
        confirmInput.value += digit;
      }
    } else {
      if (pinInput.value.length < 4) {
        pinInput.value += digit;
      }
    }
  }

  void backspace() {
    errorMessage.value = '';
    if (isConfirmingMode.value) {
      if (confirmInput.value.isNotEmpty) {
        confirmInput.value = confirmInput.value.substring(0, confirmInput.value.length - 1);
      }
    } else {
      if (pinInput.value.isNotEmpty) {
        pinInput.value = pinInput.value.substring(0, pinInput.value.length - 1);
      }
    }
  }

  void clear() {
    pinInput.value = '';
    confirmInput.value = '';
    isConfirmingMode.value = false;
    errorMessage.value = '';
  }

  Future<void> submit() async {
    final pin = pinInput.value;
    if (pin.length != 4) {
      errorMessage.value = 'PIN must be exactly 4 digits';
      return;
    }

    if (!isSetup.value) {
      // First-time setup
      if (!isConfirmingMode.value) {
        isConfirmingMode.value = true;
        errorMessage.value = '';
      } else {
        final confirm = confirmInput.value;
        if (pin != confirm) {
          clear();
          errorMessage.value = 'PINs do not match. Start over.';
          return;
        }

        // Setup the vault
        try {
          await _vaultService.setupVault(pin);
          final success = await _vaultService.unlockVault(pin);
          if (success) {
            _sessionService.activateSession();
            Get.offAllNamed(AppRoutes.hiddenHome);
          } else {
            errorMessage.value = 'Failed to open vault after setup';
          }
        } catch (e) {
          errorMessage.value = 'Encryption initialization failed';
        }
      }
    } else {
      // Unlock existing vault
      try {
        final success = await _vaultService.unlockVault(pin);
        if (success) {
          _sessionService.activateSession();
          Get.offAllNamed(AppRoutes.hiddenHome);
        } else {
          errorMessage.value = 'Incorrect PIN';
          pinInput.value = '';
        }
      } catch (e) {
        errorMessage.value = 'Decryption failed';
        pinInput.value = '';
      }
    }
  }

  Future<void> triggerPanicWipe() async {
    await _vaultService.panicWipe();
    _sessionService.lockSession();
    clear();
    isSetup.value = false;
    errorMessage.value = 'Vault completely wiped.';
  }
}
