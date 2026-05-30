import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/services/analytics_service.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/core/storage/app_database.dart';

/// Key used to persist the AES-256 database encryption key in
/// [SecureStorageService] (Android Keystore / iOS Keychain).
const _kDbEncryptionKeyStorageKey = 'db_encryption_key_v1';

/// Name of the encrypted SQLite database file.
const _kDatabaseFileName = 'memovault.db';

// ── Recovery Counter Keys ──────────────────────────────────────────────────

/// Counts how many times the database has been wiped within the current window.
/// Used to prevent a key-management bug from silently erasing user data
/// through repeated automatic wipes.
const _kDbRecoveryCountKey = 'db_recovery_count';

/// ISO-8601 timestamp marking the start of the current recovery window.
const _kDbRecoveryWindowStartKey = 'db_recovery_window_start';

/// Maximum number of automated wipes permitted within [_kRecoveryWindowDuration].
/// More than 1 wipe in 24 hours indicates a persistent key-management bug,
/// not one-time corruption. The app halts to protect user data.
const _kMaxRecoveriesInWindow = 1;

/// Rolling window for the recovery counter.
const _kRecoveryWindowDuration = Duration(hours: 24);

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
///     check the recovery counter first. If this is the first wipe in 24 h,
///     delete the corrupt/mismatched database and reinitialize with a fresh key.
///     If the counter exceeds [_kMaxRecoveriesInWindow], halt with a fatal error
///     rather than silently erasing user data again.
///
/// Must be initialized in [main()] **before** [runApp()].
class DatabaseService extends GetxService {
  final AppDatabaseFactory _dbFactory;
  AppDatabase? _db;

  /// Guards against concurrent [init] calls (e.g. if GetX calls init twice).
  bool _isInitializing = false;

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
  ///
  /// Concurrent calls are safe: the second caller spin-waits until the first
  /// completes, then returns the already-initialized service.
  Future<DatabaseService> init({String? dbName}) async {
    // Already initialized — idempotent.
    if (_db != null) {
      AppLogger.debug('[DatabaseService] Already initialized. Skipping.');
      return this;
    }

    // Concurrency guard — prevents double-init race on app startup.
    if (_isInitializing) {
      AppLogger.debug('[DatabaseService] Init already in progress. Waiting…');
      while (_isInitializing) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return this;
    }

    _isInitializing = true;
    try {
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

      // Diagnostic pre-open state — helps diagnose key/WAL mismatch issues.
      final dbFileExists = File(dbPath).existsSync();
      final walFileExists = File('$dbPath-wal').existsSync();
      final storedKeyExists = (await secureStorage.read(_kDbEncryptionKeyStorageKey)) != null;
      AppLogger.info('[DatabaseService] Pre-open state', metadata: {
        'db_file_exists': dbFileExists,
        'wal_file_exists': walFileExists,
        'key_in_storage': storedKeyExists,
      });

      final encryptionKey = await _resolveEncryptionKey(secureStorage);
      _db = await _openDatabase(dbPath, encryptionKey, secureStorage);
      AppLogger.info('[DatabaseService] Encrypted database opened successfully.');
      return this;
    } finally {
      _isInitializing = false;
    }
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

  /// Opens the database. On wrong-key / corruption (ADR-011), checks the
  /// recovery counter before wiping. If the counter exceeds
  /// [_kMaxRecoveriesInWindow] within [_kRecoveryWindowDuration], the
  /// service halts with a [StateError] rather than silently erasing data.
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
      // Force-open to trigger key verification before returning.
      await db.customStatement('SELECT 1');
      return db;
    } catch (e) {
      // ADR-011: Valid DB file but wrong key — check recovery counter first.
      AppLogger.warning(
        '[DatabaseService] Failed to open DB (bad key or corruption). '
        'Checking recovery counter before wipe.',
        error: e,
      );
      _emitAnalyticsEvent('database_open_failed');

      // This may throw StateError if the counter is exceeded — intentional.
      await _guardedWipeDatabase(dbPath, secureStorage);

      final freshKey = await _resolveEncryptionKey(secureStorage);
      final db = _dbFactory(dbPath, freshKey);
      await db.customStatement('SELECT 1');
      return db;
    }
  }

  /// Checks the rolling recovery counter. If within budget, increments and
  /// proceeds with wipe. If over budget, halts to protect user data.
  ///
  /// Throws [StateError] when recovery has been attempted more than
  /// [_kMaxRecoveriesInWindow] times within [_kRecoveryWindowDuration].
  Future<void> _guardedWipeDatabase(
    String dbPath,
    SecureStorageService storage,
  ) async {
    final countStr = await storage.read(_kDbRecoveryCountKey);
    final windowStr = await storage.read(_kDbRecoveryWindowStartKey);
    final now = DateTime.now().toUtc();

    final existingCount = int.tryParse(countStr ?? '0') ?? 0;
    final windowStart = windowStr != null ? DateTime.tryParse(windowStr) : null;
    final inActiveWindow = windowStart != null &&
        now.difference(windowStart) < _kRecoveryWindowDuration;

    // If outside the window, reset the counter for a fresh window.
    final effectiveCount = inActiveWindow ? existingCount : 0;

    if (effectiveCount >= _kMaxRecoveriesInWindow) {
      // HALT — repeated wipe within 24 h indicates a persistent bug.
      // Do NOT wipe again: user data would be permanently destroyed.
      _emitAnalyticsEvent('database_recovery_halted');
      AppLogger.fatal(
        '[DatabaseService] Recovery guard triggered: repeated automatic wipe '
        'detected within the last 24 hours. Halting to protect user data. '
        'Manual intervention required.',
        metadata: {
          'recovery_count': effectiveCount,
          'window_start': windowStr ?? 'unknown',
        },
      );
      throw StateError(
        'Database recovery halted after $effectiveCount wipe(s) in 24 hours. '
        'This indicates a persistent key-management problem. '
        'Manual app data clear is required.',
      );
    }

    // Within budget — record the wipe and proceed.
    final newCount = effectiveCount + 1;
    await storage.write(_kDbRecoveryCountKey, '$newCount');
    if (!inActiveWindow) {
      // Start a new 24-hour window.
      await storage.write(_kDbRecoveryWindowStartKey, now.toIso8601String());
    }

    AppLogger.warning(
      '[DatabaseService] Recovery wipe #$newCount of $_kMaxRecoveriesInWindow '
      'permitted in this window. Wiping database.',
    );
    _emitAnalyticsEvent('database_recovery_triggered');
    await _wipeDatabase(dbPath, storage);
  }

  /// Deletes the database file (and companion WAL/SHM files) and removes the
  /// stored encryption key so a fresh key/db pair is created on the next
  /// [_openDatabase] call.
  ///
  /// WAL and SHM companion files are always removed alongside the main database
  /// to prevent stale checkpoint data from a previous key version causing
  /// an [Invalid MagicHeader] on the new database.
  Future<void> _wipeDatabase(
    String dbPath,
    SecureStorageService secureStorage,
  ) async {
    await secureStorage.delete(_kDbEncryptionKeyStorageKey);

    // Delete main database file + WAL + SHM companion files.
    for (final suffix in <String>['', '-wal', '-shm']) {
      final file = File('$dbPath$suffix');
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (e) {
          AppLogger.warning(
            '[DatabaseService] Could not delete companion file',
            metadata: {'suffix': suffix},
            error: e,
          );
        }
      }
    }

    AppLogger.info(
      '[DatabaseService] Database and WAL/SHM files wiped. '
      'A fresh encrypted database will be created.',
    );
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
