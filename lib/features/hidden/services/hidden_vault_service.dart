import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/features/hidden/data/hidden_notes_dao.dart';
import 'package:memovault/features/hidden/data/hidden_categories_dao.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:memovault/features/hidden/domain/entities/hidden_vault_config.dart';
import 'package:memovault/features/hidden/services/pin_hashing_service.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/data/messaging/services/media_transfer_service_impl.dart';
import 'package:crypto/crypto.dart';

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
  HiddenCategoriesDao? _categoriesDao;

  HiddenVaultDatabase? get db => _db;
  HiddenNotesDao? get notesDao => _notesDao;
  HiddenCategoriesDao? get categoriesDao => _categoriesDao;

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

    final fingerprint = sha256.convert(utf8.encode(dbKey)).toString().substring(0, 8);
    AppLogger.info('[HiddenVaultService] Hidden vault setup successfully. Key fingerprint: $fingerprint');
  }

  /// Authenticates PIN and initializes the Drift database.
  Future<bool> unlockVault(String pin) async {
    final configStr = await _secureStorage.read(_kHiddenVaultConfigKey);
    if (configStr == null) return false;

    final config = HiddenVaultConfig.deserialize(configStr);
    final isValid = _pinHashing.verifyPin(pin, config.realPinHash, config.pinSalt);
    if (!isValid) return false;

    // Load db key
    final dbKey = await _secureStorage.read(_kHiddenVaultKeyStorageKey);
    if (dbKey == null) {
      throw StateError('[HiddenVaultService] Encryption key is missing from secure storage but vault configuration is present.');
    }

    final dbDir = await getApplicationDocumentsDirectory();
    final dbPath = '${dbDir.path}/$_kHiddenVaultDbName';

    final dbKeyVersion = await _secureStorage.read(_kHiddenVaultKeyVersionKey);
    final dbFileExists = File(dbPath).existsSync();
    final fingerprint = sha256.convert(utf8.encode(dbKey)).toString().substring(0, 8);

    AppLogger.info('[HiddenVaultService] Pre-open state', metadata: {
      'db_path': dbPath,
      'db_file_exists': dbFileExists,
      'key_in_storage': true,
      'key_version': dbKeyVersion ?? 'null',
      'key_fingerprint': fingerprint,
    });

    _db = HiddenVaultDatabase(buildHiddenEncryptedExecutor(dbPath, dbKey));
    _notesDao = HiddenNotesDao(_db!);
    _categoriesDao = HiddenCategoriesDao(_db!);

    // Warm up the database to make sure it opens and key is validated
    await _db!.customSelect('SELECT 1').get();

    AppLogger.info('[HiddenVaultService] Hidden vault database unlocked and opened.');
    return true;
  }

  /// Closes the database and locks the vault.
  Future<void> lockVault() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _notesDao = null;
      _categoriesDao = null;
      AppLogger.info('[HiddenVaultService] Hidden vault database closed.');
    }
  }

  /// Performs a panic wipe. Wipes the database files, config, and encryption keys from secure storage.
  Future<void> panicWipe() async {
    // 1. Lock/close hidden vault db
    await lockVault();

    // 2. Delete main app database and its secure storage key
    try {
      if (Get.isRegistered<DatabaseService>()) {
        await Get.find<DatabaseService>().wipeDatabase();
      }
    } catch (e) {
      AppLogger.warning('[HiddenVaultService] Panic wipe: failed to wipe main database', error: e);
    }

    // 3. Reset Signal identity and session keys
    try {
      if (Get.isRegistered<MessagingIdentityService>()) {
        await Get.find<MessagingIdentityService>().resetIdentity();
      }
    } catch (e) {
      AppLogger.warning('[HiddenVaultService] Panic wipe: failed to reset messaging identity', error: e);
    }

    // 4. Delete hidden vault secure storage keys
    await _secureStorage.delete(_kHiddenVaultConfigKey);
    await _secureStorage.delete(_kHiddenVaultKeyStorageKey);
    await _secureStorage.delete(_kHiddenVaultKeyVersionKey);

    // 5. Delete hidden vault database files
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

    // 6. Purge decrypted cache
    await MediaTransferServiceImpl.purgeDecryptedCache();

    // 7. Delete local mock R2 directory if it exists
    final tempDir = Directory.systemTemp.path;
    final mockR2Dir = Directory('$tempDir/memovault_mock_r2');
    if (mockR2Dir.existsSync()) {
      try {
        mockR2Dir.deleteSync(recursive: true);
      } catch (_) {}
    }

    AppLogger.warning('[HiddenVaultService] Panic wipe executed. All hidden data destroyed.');
  }
}
