import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/features/hidden/data/hidden_notes_dao.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:memovault/features/hidden/domain/entities/hidden_vault_config.dart';
import 'package:memovault/features/hidden/services/pin_hashing_service.dart';

const _kHiddenVaultConfigKey = 'hidden_vault_config_v1';
const _kHiddenVaultKeyStorageKey = 'hidden_vault_encryption_key_v1';
const _kHiddenVaultKeyVersionKey = 'hidden_vault_encryption_key_version';
const _kHiddenVaultDbName = 'hidden_vault.db';

class HiddenVaultService extends GetxService {
  final SecureStorageService _secureStorage;
  final PinHashingService _pinHashing;

  HiddenVaultService(this._secureStorage, this._pinHashing);

  HiddenVaultDatabase? _db;
  HiddenNotesDao? _notesDao;

  HiddenVaultDatabase? get db => _db;
  HiddenNotesDao? get notesDao => _notesDao;

  bool get isVaultInitialized => _db != null;

  /// Checks if the hidden vault is set up (meaning we have config in secure storage).
  Future<bool> isVaultSetup() async {
    final config = await _secureStorage.read(_kHiddenVaultConfigKey);
    return config != null && config.isNotEmpty;
  }

  /// Sets up the vault for the first time with a new PIN.
  Future<void> setupVault(String pin) async {
    // Generate salt
    final rng = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final salt = base64UrlEncode(saltBytes);

    // Hash the real PIN
    final hash = _pinHashing.hashPin(pin, salt);

    // Save configuration
    final config = HiddenVaultConfig(
      realPinHash: hash,
      pinSalt: salt,
    );
    await _secureStorage.write(_kHiddenVaultConfigKey, config.serialize());

    // Generate database encryption key and key version
    final dbKeyBytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final dbKey = base64UrlEncode(dbKeyBytes);
    await _secureStorage.write(_kHiddenVaultKeyStorageKey, dbKey);
    await _secureStorage.write(_kHiddenVaultKeyVersionKey, '1');

    AppLogger.info('[HiddenVaultService] Hidden vault setup successfully.');
  }

  /// Authenticates PIN and initializes the Drift database.
  Future<bool> unlockVault(String pin) async {
    final configStr = await _secureStorage.read(_kHiddenVaultConfigKey);
    if (configStr == null) return false;

    final config = HiddenVaultConfig.deserialize(configStr);
    final isValid = _pinHashing.verifyPin(pin, config.realPinHash, config.pinSalt);
    if (!isValid) return false;

    // Load db key
    var dbKey = await _secureStorage.read(_kHiddenVaultKeyStorageKey);
    if (dbKey == null) {
      // Regenerate if lost
      final rng = Random.secure();
      final dbKeyBytes = List<int>.generate(32, (_) => rng.nextInt(256));
      dbKey = base64UrlEncode(dbKeyBytes);
      await _secureStorage.write(_kHiddenVaultKeyStorageKey, dbKey);
      await _secureStorage.write(_kHiddenVaultKeyVersionKey, '1');
    }

    final dbDir = await getApplicationDocumentsDirectory();
    final dbPath = '${dbDir.path}/$_kHiddenVaultDbName';

    _db = HiddenVaultDatabase(buildHiddenEncryptedExecutor(dbPath, dbKey));
    _notesDao = HiddenNotesDao(_db!);

    // Warm up the database to make sure it opens and key is validated
    await _db!.customStatement('SELECT 1');

    AppLogger.info('[HiddenVaultService] Hidden vault database unlocked and opened.');
    return true;
  }

  /// Closes the database and locks the vault.
  Future<void> lockVault() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _notesDao = null;
      AppLogger.info('[HiddenVaultService] Hidden vault database closed.');
    }
  }

  /// Performs a panic wipe. Wipes the database files, config, and encryption keys from secure storage.
  Future<void> panicWipe() async {
    await lockVault();
    await _secureStorage.delete(_kHiddenVaultConfigKey);
    await _secureStorage.delete(_kHiddenVaultKeyStorageKey);
    await _secureStorage.delete(_kHiddenVaultKeyVersionKey);

    final dbDir = await getApplicationDocumentsDirectory();
    final dbPath = '${dbDir.path}/$_kHiddenVaultDbName';

    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$dbPath$suffix');
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (e) {
          AppLogger.warning(
            '[HiddenVaultService] Panic wipe: failed to delete file',
            metadata: {'suffix': suffix},
            error: e,
          );
        }
      }
    }
    AppLogger.warning('[HiddenVaultService] Panic wipe executed. All hidden data destroyed.');
  }
}
