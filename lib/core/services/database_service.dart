import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/services/analytics_service.dart';
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
    if (_db != null) {
      AppLogger.debug('[DatabaseService] Database already initialized. Skipping.');
      return this;
    }

    final secureStorage = Get.find<SecureStorageService>();
    final name = dbName ?? _kDatabaseFileName;

    // Resolve absolute path inside getApplicationDocumentsDirectory()
    // unless it is an explicit absolute path or test database path.
    final String dbPath;
    if (name.contains('/') || name.contains('\\') || name.startsWith('test_')) {
      dbPath = name;
    } else {
      final dbDir = await getApplicationDocumentsDirectory();
      dbPath = '${dbDir.path}/$name';
    }

    final encryptionKey = await _resolveEncryptionKey(secureStorage);
    _db = await _openDatabase(dbPath, encryptionKey, secureStorage);
    AppLogger.info('[DatabaseService] Encrypted database opened.');
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
    final newKey = generate256BitKey();
    await storage.write(_kDbEncryptionKeyStorageKey, newKey);
    AppLogger.info('[DatabaseService] New 256-bit encryption key generated and stored.');
    _emitAnalyticsEvent('database_key_regenerated');
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
      // Key length validation: MUST be exactly 32 bytes (256 bits) when decoded.
      final decodedBytes = base64Url.decode(encryptionKey);
      if (decodedBytes.length != 32) {
        throw ArgumentError('Database encryption key must be exactly 256 bits (32 bytes).');
      }

      final db = _dbFactory(dbPath, encryptionKey);
      // Force open to trigger key verification before returning.
      await db.customStatement('SELECT 1');
      return db;
    } catch (e) {
      // ADR-011: Valid DB file but wrong key — wipe and reinitialize.
      AppLogger.warning(
        '[DatabaseService] Failed to open DB (bad key or corruption). Wiping and reinitializing.',
        error: e,
      );
      _emitAnalyticsEvent('database_open_failed');
      await _wipeDatabase(dbPath, secureStorage);
      _emitAnalyticsEvent('database_recovery_triggered');
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
      await deleteDatabase(dbPath);
    } catch (_) {
      // If deletion fails, the next open attempt will regenerate anyway.
    }
    AppLogger.info('[DatabaseService] Database wiped. A fresh DB will be created.');
  }

  /// Generates a cryptographically secure random 256-bit (32-byte) key,
  /// encoded as Base64.
  static String generate256BitKey() {
    final rng = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(keyBytes);
  }

  /// Emits a non-sensitive database telemetry event when AnalyticsService is
  /// registered. Silently skips if analytics are unavailable (e.g. in tests).
  void _emitAnalyticsEvent(String name) {
    try {
      final analytics = Get.find<AnalyticsService>();
      if (analytics.isEnabled) {
        analytics.logEvent(name: name);
      }
    } catch (_) {
      // AnalyticsService not yet registered — skip silently.
    }
  }

  /// Closes the database connection and resets internal references.
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      AppLogger.info('[DatabaseService] Database connection closed.');
    }
  }

  @override
  void onClose() {
    close();
    super.onClose();
  }
}
