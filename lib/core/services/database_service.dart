import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Key used to persist the AES-256 database encryption key in
/// [SecureStorageService] (Android Keystore / iOS Keychain).
const _kDbEncryptionKeyStorageKey = 'db_encryption_key_v1';

/// Name of the encrypted SQLite database file.
const _kDatabaseFileName = 'memovault.db';

/// Factory that creates an [AppDatabase] given a database path and encryption key.
///
/// Exposed so that unit tests can inject an in-memory database instead of
/// going through the real SQLite/SQLCipher platform channel.
///
/// Production code uses the default factory ([_defaultDatabaseFactory]).
typedef AppDatabaseFactory = AppDatabase Function(String dbPath, String encryptionKey);

AppDatabase _defaultDatabaseFactory(String dbPath, String encryptionKey) {
  return AppDatabase(buildEncryptedExecutor(dbPath, encryptionKey));
}

/// Manages the lifecycle of [AppDatabase].
///
/// Responsibilities:
///  1. Retrieve or generate the 256-bit encryption key via [SecureStorageService].
///  2. Open the encrypted [AppDatabase].
///  3. Provide [db] for dependency-injection consumers.
///  4. Handle ADR-011: if the stored key cannot open the existing database,
///     delete the corrupt/mismatched database and reinitialize with a fresh key.
///
/// Must be initialized in [main()] **before** [runApp()].
class DatabaseService extends GetxService {
  final AppDatabaseFactory _dbFactory;
  AppDatabase? _db;

  /// Creates a [DatabaseService].
  ///
  /// [dbFactory] is optional and only intended for unit tests. Production code
  /// should omit this parameter so the default encrypted executor is used.
  DatabaseService({@visibleForTesting AppDatabaseFactory? dbFactory})
      : _dbFactory = dbFactory ?? _defaultDatabaseFactory;

  /// Returns the open [AppDatabase] instance.
  /// Throws a [StateError] if accessed before [init] completes.
  AppDatabase get db {
    if (_db == null) {
      throw StateError('DatabaseService.init() must be called before accessing db.');
    }
    return _db!;
  }

  /// Initializes (or recovers) the encrypted database.
  Future<DatabaseService> init({String? dbName}) async {
    final secureStorage = Get.find<SecureStorageService>();
    final dbPath = dbName ?? _kDatabaseFileName;

    final encryptionKey = await _resolveEncryptionKey(secureStorage);
    _db = await _openDatabase(dbPath, encryptionKey, secureStorage);
    debugPrint('[DatabaseService] Encrypted database opened. path=$dbPath');
    return this;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns the stored encryption key, or generates and stores a new one.
  Future<String> _resolveEncryptionKey(SecureStorageService storage) async {
    final existing = await storage.read(_kDbEncryptionKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final newKey = _generate256BitKey();
    await storage.write(_kDbEncryptionKeyStorageKey, newKey);
    debugPrint('[DatabaseService] New 256-bit encryption key generated and stored.');
    return newKey;
  }

  /// Opens the database. On wrong-key / corruption (ADR-011), deletes the
  /// database file, generates a fresh key, and reinitializes.
  Future<AppDatabase> _openDatabase(
    String dbPath,
    String encryptionKey,
    SecureStorageService secureStorage,
  ) async {
    try {
      final db = _dbFactory(dbPath, encryptionKey);
      // Force open to trigger key verification before returning.
      await db.customStatement('SELECT 1');
      return db;
    } catch (e) {
      // ADR-011: Valid DB file but wrong key — wipe and reinitialize.
      debugPrint('[DatabaseService] ⚠️ Failed to open DB (bad key or corruption). '
          'Wiping and reinitializing. error=$e');
      await _wipeDatabase(dbPath, secureStorage);
      final freshKey = await _resolveEncryptionKey(secureStorage);
      final db = _dbFactory(dbPath, freshKey);
      await db.customStatement('SELECT 1');
      return db;
    }
  }

  /// Deletes the database file and removes the stored encryption key so a
  /// fresh key/db pair is created on the next [_openDatabase] call.
  Future<void> _wipeDatabase(
    String dbPath,
    SecureStorageService secureStorage,
  ) async {
    await secureStorage.delete(_kDbEncryptionKeyStorageKey);
    try {
      final dbDir = await getApplicationDocumentsDirectory();
      await deleteDatabase('${dbDir.path}/$dbPath');
    } catch (_) {
      // If deletion fails, the next open attempt will regenerate anyway.
    }
    debugPrint('[DatabaseService] Database wiped. A fresh DB will be created.');
  }

  /// Generates a cryptographically secure random 256-bit (32-byte) key,
  /// encoded as Base64.
  static String _generate256BitKey() {
    final rng = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(keyBytes);
  }

  @override
  void onClose() {
    _db?.close();
    super.onClose();
  }
}
