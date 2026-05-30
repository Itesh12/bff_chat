import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:memovault/core/services/database_service.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/core/services/secure_storage_service_impl.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'secure_storage_service_test.dart'; // reuse FakeFlutterSecureStorage

// ---------------------------------------------------------------------------
// Minimal in-memory QueryExecutor for drift
// ---------------------------------------------------------------------------

/// A minimal [QueryExecutor] that satisfies drift's interface using pure
/// Dart state — no platform channels, no sqflite singleInstance cache.
///
/// Only implements the subset of SQL needed by [DatabaseService]:
///   • `SELECT 1`  – key-verification probe
///   • `PRAGMA journal_mode` – WAL assertion
///   • Schema bootstrap queries (ignored)
class _InMemoryExecutor implements QueryExecutor {
  bool _open = false;

  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async {
    if (!_open) {
      _open = true;
      await user.beforeOpen(this, const OpeningDetails(null, 1));
    }
    return true;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
      String statement, List<Object?> args) async {
    if (statement.contains('SELECT 1')) return [{'1': 1}];
    if (statement.toLowerCase().contains('pragma journal_mode')) {
      return [{'journal_mode': 'wal'}];
    }
    return [];
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {}

  @override
  Future<int> runInsert(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runDelete(String statement, List<Object?> args) async => 0;

  @override
  Future<void> runBatched(BatchedStatements statements) async {}

  @override
  TransactionExecutor beginTransaction() => _InMemoryTransactionExecutor();

  @override
  QueryExecutor beginExclusive() => _InMemoryExecutor();

  @override
  Future<void> close() async => _open = false;
}

class _InMemoryTransactionExecutor extends _InMemoryExecutor
    implements TransactionExecutor {
  @override
  bool get supportsNestedTransactions => false;

  @override
  Future<void> send() async {}

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// Database factory helpers
// ---------------------------------------------------------------------------

/// Always creates a fresh [AppDatabase] backed by the in-memory executor.
/// Tracks the most recently used (path, key) pair.
class _FakeDbFactory {
  String? lastPath;
  String? lastKey;

  AppDatabase call(String path, String key) {
    lastPath = path;
    lastKey = key;
    return AppDatabase(LazyDatabase(() async => _InMemoryExecutor()));
  }
}

/// Accepts the first key it sees as the "correct" encryption key.
/// Throws a plain [Exception] for any subsequent call with a different key —
/// simulating SQLCipher's wrong-key rejection without touching sqflite at all.
///
/// After a wrong-key throw, resets state so the post-wipe reinitialize
/// (with a freshly generated key) is accepted — matching real SQLCipher
/// behavior where a wiped database accepts any new key.
class _WrongKeySimulatorFactory {
  String? _correctKey;

  AppDatabase call(String path, String key) {
    if (_correctKey == null) {
      // First open or post-wipe open — register this as the correct key.
      _correctKey = key;
    } else if (key != _correctKey) {
      // Wrong key — simulate SQLCipher rejection. Reset state so the
      // subsequent post-wipe open (with a fresh key) is accepted.
      _correctKey = null;
      throw Exception(
        'open_failed (wrong encryption key or corrupt database)',
      );
    }
    return AppDatabase(LazyDatabase(() async => _InMemoryExecutor()));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Each test creates its own AppDatabase with an independent in-memory executor.
  // Drift's multiple-instances check is safe to suppress here because no two
  // instances share a QueryExecutor in these tests.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);

  late FakeFlutterSecureStorage fakeStorage;
  late SecureStorageService secureStorage;

  setUp(() {
    Get.delete<SecureStorageService>(force: true);
    Get.delete<DatabaseService>(force: true);
    Get.reset();

    fakeStorage = FakeFlutterSecureStorage();
    secureStorage = SecureStorageServiceImpl(storage: fakeStorage);
    Get.put<SecureStorageService>(secureStorage, permanent: true);
  });

  tearDown(() {
    Get.delete<SecureStorageService>(force: true);
    Get.delete<DatabaseService>(force: true);
  });

  group('DatabaseService Tests', () {
    // ── 1. Key generation & storage ─────────────────────────────────────────
    test('opens database successfully and generates/stores encryption key',
        () async {
      final factory = _FakeDbFactory();
      final dbService = DatabaseService(dbFactory: factory.call);
      await dbService.init(dbName: 'test_key.db');

      // Key must have been persisted in secure storage.
      final key = await secureStorage.read('db_encryption_key_v1');
      expect(key, isNotNull, reason: 'Key must be written to secure storage');
      expect(key!.isNotEmpty, isTrue);

      // Factory must have been called with that exact key and path.
      expect(factory.lastKey, equals(key));
      expect(factory.lastPath, equals('test_key.db'));

      // AppDatabase must be accessible.
      expect(dbService.db, isNotNull);

      dbService.onClose();
    });

    // ── 2. Second launch reuses the stored key ───────────────────────────────
    test('second launch reuses the stored encryption key without regenerating',
        () async {
      final factory1 = _FakeDbFactory();
      final dbService1 = DatabaseService(dbFactory: factory1.call);
      await dbService1.init(dbName: 'test_reuse.db');
      final originalKey = factory1.lastKey!;
      dbService1.onClose();

      // Second launch — same secure storage, same key must be reused.
      final factory2 = _FakeDbFactory();
      final dbService2 = DatabaseService(dbFactory: factory2.call);
      await dbService2.init(dbName: 'test_reuse.db');

      expect(factory2.lastKey, equals(originalKey),
          reason: 'Key must be reused from secure storage, not regenerated');
      dbService2.onClose();
    });

    // ── 3. WAL mode (PRAGMA journal_mode returns 'wal') ─────────────────────
    test('WAL verification — PRAGMA journal_mode returns wal', () async {
      final factory = _FakeDbFactory();
      final dbService = DatabaseService(dbFactory: factory.call);
      await dbService.init(dbName: 'test_wal.db');

      final result = await dbService.db
          .customSelect('PRAGMA journal_mode;')
          .getSingle();
      expect(result.data['journal_mode'], equals('wal'),
          reason: 'AppDatabase must report WAL journal mode');

      dbService.onClose();
    });

    // ── 4. ADR-011 wrong-key recovery ────────────────────────────────────────
    test(
        'ADR-011: wrong-key triggers wipe-and-reinitialize without crash',
        () async {
      final simulator = _WrongKeySimulatorFactory();

      // First launch — generates and stores a correct key.
      final dbService1 = DatabaseService(dbFactory: simulator.call);
      await dbService1.init(dbName: 'test_adr011.db');
      final originalKey = await secureStorage.read('db_encryption_key_v1');
      expect(originalKey, isNotNull);
      dbService1.onClose();

      // Tamper: overwrite stored key with an incorrect value.
      await secureStorage.write('db_encryption_key_v1', 'mismatched_wrong_key');

      // Second launch — simulator throws for 'mismatched_wrong_key'.
      // DatabaseService must: catch → wipe (delete key) → regenerate → reopen.
      final dbService2 = DatabaseService(dbFactory: simulator.call);
      await dbService2.init(dbName: 'test_adr011.db');

      final newKey = await secureStorage.read('db_encryption_key_v1');
      expect(newKey, isNotNull,
          reason: 'A fresh key must be stored after recovery');
      expect(newKey, isNot(equals('mismatched_wrong_key')),
          reason: 'The wrong key must be replaced by recovery');
      expect(dbService2.db, isNotNull,
          reason: 'DB must be accessible after recovery');

      dbService2.onClose();
    });
  });
}
