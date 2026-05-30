import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HiddenSessionService Tests', () {
    late FakeHiddenVaultService fakeVaultService;
    late HiddenSessionService sessionService;

    setUp(() {
      fakeVaultService = FakeHiddenVaultService();
      sessionService = HiddenSessionService(fakeVaultService);
      Get.put<HiddenSessionService>(sessionService);
    });

    tearDown(() {
      Get.delete<HiddenSessionService>();
    });

    test('Initial state is locked', () {
      expect(sessionService.state.value, HiddenSessionState.locked);
      expect(sessionService.isLocked, isTrue);
      expect(sessionService.isActive, isFalse);
      expect(sessionService.isActivating, isFalse);
    });

    test('startActivating updates state to activating', () {
      sessionService.startActivating();
      expect(sessionService.state.value, HiddenSessionState.activating);
      expect(sessionService.isActivating, isTrue);
    });

    test('activateSession updates state to active and resets timer', () {
      sessionService.activateSession();
      expect(sessionService.state.value, HiddenSessionState.active);
      expect(sessionService.isActive, isTrue);
    });

    test('lockSession transitions state to locked and calls lockVault', () {
      sessionService.activateSession();
      expect(sessionService.isLocked, isFalse);

      sessionService.lockSession();
      expect(sessionService.state.value, HiddenSessionState.locked);
      expect(sessionService.isLocked, isTrue);
      expect(fakeVaultService.lockVaultCallCount, 1);
    });

    test('lockSession does nothing if already locked', () {
      sessionService.lockSession();
      expect(fakeVaultService.lockVaultCallCount, 0);
    });

    test('didChangeAppLifecycleState locks session on non-resumed states', () {
      sessionService.activateSession();
      expect(sessionService.isActive, isTrue);

      sessionService.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(sessionService.isLocked, isTrue);
      expect(fakeVaultService.lockVaultCallCount, 1);
    });

    test('didChangeAppLifecycleState does not lock session on resumed state', () {
      sessionService.activateSession();
      expect(sessionService.isActive, isTrue);

      sessionService.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(sessionService.isActive, isTrue);
      expect(fakeVaultService.lockVaultCallCount, 0);
    });
  });
}
