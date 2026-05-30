import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:memovault/features/hidden/controllers/hidden_activation_controller.dart';
import 'package:memovault/features/hidden/services/hidden_session_service.dart';
import 'package:memovault/features/hidden/services/hidden_vault_service.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:memovault/features/hidden/data/hidden_notes_dao.dart';

class FakeHiddenVaultService extends GetxService implements HiddenVaultService {
  int lockVaultCallCount = 0;
  int panicWipeCallCount = 0;
  int setupVaultCallCount = 0;
  int unlockVaultCallCount = 0;
  bool isSetup = false;
  bool isUnlocked = false;

  @override
  HiddenVaultDatabase? get db => null;

  @override
  HiddenNotesDao? get notesDao => null;

  @override
  bool get isVaultInitialized => isUnlocked;

  @override
  Future<bool> isVaultSetup() async => isSetup;

  @override
  Future<void> setupVault(String pin) async {
    setupVaultCallCount++;
    isSetup = true;
  }

  @override
  Future<bool> unlockVault(String pin) async {
    unlockVaultCallCount++;
    if (pin == '1234') {
      isUnlocked = true;
      return true;
    }
    return false;
  }

  @override
  Future<void> lockVault() async {
    lockVaultCallCount++;
    isUnlocked = false;
  }

  @override
  Future<void> panicWipe() async {
    panicWipeCallCount++;
    isSetup = false;
    isUnlocked = false;
  }
}

class FakeHiddenSessionService extends GetxService with WidgetsBindingObserver implements HiddenSessionService {
  int activateCallCount = 0;
  int lockCallCount = 0;
  int startActivatingCallCount = 0;

  @override
  final Rx<HiddenSessionState> state = HiddenSessionState.locked.obs;

  @override
  bool get isLocked => state.value == HiddenSessionState.locked;
  @override
  bool get isActive => state.value == HiddenSessionState.active;
  @override
  bool get isActivating => state.value == HiddenSessionState.activating;

  @override
  void startActivating() {
    startActivatingCallCount++;
    state.value = HiddenSessionState.activating;
  }

  @override
  void activateSession() {
    activateCallCount++;
    state.value = HiddenSessionState.active;
  }

  @override
  void lockSession() {
    lockCallCount++;
    state.value = HiddenSessionState.locked;
  }

  @override
  void resetInactivityTimer() {}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Get.testMode = true;

  group('HiddenActivationController Tests', () {
    late FakeHiddenVaultService fakeVaultService;
    late FakeHiddenSessionService fakeSessionService;
    late HiddenActivationController controller;

    setUp(() {
      fakeVaultService = FakeHiddenVaultService();
      fakeSessionService = FakeHiddenSessionService();
      controller = HiddenActivationController(fakeVaultService, fakeSessionService);
    });

    test('Initial states are empty and default to not setup', () async {
      expect(controller.isSetup.value, isFalse);
      expect(controller.pinInput.value, '');
      expect(controller.confirmInput.value, '');
      expect(controller.isConfirmingMode.value, isFalse);
      expect(controller.errorMessage.value, '');

      // Trigger status check
      controller.onInit();
      expect(controller.isSetup.value, isFalse);
    });

    test('Append digits up to 4 max', () {
      for (int i = 0; i < 10; i++) {
        controller.appendDigit('1');
      }
      expect(controller.pinInput.value, '1111'); // Capped at 4

      // Switch to confirming mode and check confirmInput append
      controller.isConfirmingMode.value = true;
      for (int i = 0; i < 10; i++) {
        controller.appendDigit('2');
      }
      expect(controller.confirmInput.value, '2222'); // Capped at 4
    });

    test('Backspace deletes last character', () {
      controller.pinInput.value = '1234';
      controller.backspace();
      expect(controller.pinInput.value, '123');

      controller.isConfirmingMode.value = true;
      controller.confirmInput.value = '5678';
      controller.backspace();
      expect(controller.confirmInput.value, '567');
    });

    test('Clear resets inputs and mode', () {
      controller.pinInput.value = '1234';
      controller.confirmInput.value = '1234';
      controller.isConfirmingMode.value = true;
      controller.errorMessage.value = 'Error';

      controller.clear();
      expect(controller.pinInput.value, '');
      expect(controller.confirmInput.value, '');
      expect(controller.isConfirmingMode.value, isFalse);
      expect(controller.errorMessage.value, '');
    });

    test('Submit with short PIN shows error', () async {
      controller.pinInput.value = '12';
      await controller.submit();
      expect(controller.errorMessage.value, 'PIN must be exactly 4 digits');
    });

    test('Submit when vault is not setup guides through confirmation and setup', () async {
      fakeVaultService.isSetup = false;
      controller.onInit();
      controller.isSetup.value = false;

      controller.pinInput.value = '1234';
      // First submit triggers confirming mode
      await controller.submit();
      expect(controller.isConfirmingMode.value, isTrue);
      expect(controller.errorMessage.value, '');

      // Mismatch confirm pin
      controller.confirmInput.value = '5678';
      await controller.submit();
      expect(controller.errorMessage.value, 'PINs do not match. Start over.');
      expect(controller.isConfirmingMode.value, isFalse);

      // Correct confirm pin
      controller.pinInput.value = '1234';
      await controller.submit(); // back to confirming mode
      controller.confirmInput.value = '1234';
      await controller.submit();

      expect(fakeVaultService.setupVaultCallCount, 1);
      expect(fakeVaultService.unlockVaultCallCount, 1);
      expect(fakeSessionService.activateCallCount, 1);
    });

    test('Submit when vault is setup validates PIN and unlocks', () async {
      fakeVaultService.isSetup = true;
      controller.onInit();
      controller.isSetup.value = true;

      // Incorrect PIN
      controller.pinInput.value = '9999';
      await controller.submit();
      expect(controller.errorMessage.value, 'Incorrect PIN');
      expect(controller.pinInput.value, '');

      // Correct PIN
      controller.pinInput.value = '1234';
      await controller.submit();
      expect(fakeVaultService.unlockVaultCallCount, 2); // 1 incorrect + 1 correct
      expect(fakeSessionService.activateCallCount, 1);
    });

    test('5 failed attempts triggers 30s cooldown and blocks input', () async {
      fakeVaultService.isSetup = true;
      controller.onInit();
      controller.isSetup.value = true;

      expect(controller.failedAttempts.value, 0);
      expect(controller.isCooldownActive, isFalse);

      // Fail 4 times
      for (int i = 0; i < 4; i++) {
        controller.pinInput.value = '9999';
        await controller.submit();
        expect(controller.errorMessage.value, 'Incorrect PIN');
      }
      expect(controller.failedAttempts.value, 4);
      expect(controller.isCooldownActive, isFalse);

      // Fail 5th time
      controller.pinInput.value = '9999';
      await controller.submit();
      expect(controller.failedAttempts.value, 5);
      expect(controller.isCooldownActive, isTrue);
      expect(controller.cooldownRemaining.value, 30);
      expect(controller.errorMessage.value, 'Too many attempts. Cooldown active.');

      // Verify input is blocked during cooldown
      controller.appendDigit('1');
      expect(controller.pinInput.value, ''); // Blocked!

      // Submit is also blocked (should not make further unlock calls)
      final preUnlockCallCount = fakeVaultService.unlockVaultCallCount;
      controller.pinInput.value = '1234';
      await controller.submit();
      expect(fakeVaultService.unlockVaultCallCount, preUnlockCallCount); // No new unlock attempt!
    });

    test('triggerPanicWipe wipes and resets controller state', () async {
      await controller.triggerPanicWipe();
      expect(fakeVaultService.panicWipeCallCount, 1);
      expect(fakeSessionService.lockCallCount, 1);
      expect(controller.isSetup.value, isFalse);
    });
  });
}
