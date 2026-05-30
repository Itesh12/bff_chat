import 'dart:async';

import 'package:drift/backends.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as s;
import 'package:memovault/core/observability/app_logger.dart';

/// Signature of a function that runs during configuration of a database.
typedef SqfliteCipherConfigure = FutureOr<void> Function(s.Database db);

class _SqfliteCipherDelegate extends DatabaseDelegate {
  late s.Database db;
  bool _isOpen = false;

  final bool inDbFolder;
  final String path;
  final String password;
  final bool singleInstance;
  final SqfliteCipherConfigure? onConfigure;

  _SqfliteCipherDelegate(
    this.inDbFolder,
    this.path, {
    required this.password,
    this.singleInstance = true,
    this.onConfigure,
  });

  @override
  late final DbVersionDelegate versionDelegate = _SqfliteCipherVersionDelegate(db);

  @override
  TransactionDelegate get transactionDelegate => const NoTransactionDelegate();

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> open(QueryExecutorUser user) async {
    String resolvedPath;
    if (inDbFolder) {
      final databasesPath = await s.getDatabasesPath();
      resolvedPath = '$databasesPath/$path';
    } else {
      resolvedPath = path;
    }

    AppLogger.info('[SqfliteCipherQueryExecutor] Applying key');
    db = await s.openDatabase(
      resolvedPath,
      password: password,
      singleInstance: singleInstance,
      onConfigure: onConfigure,
    );
    _isOpen = true;
    AppLogger.info('[SqfliteCipherQueryExecutor] Database opened');
  }

  @override
  Future<void> close() => db.close();

  @override
  Future<void> runBatched(BatchedStatements statements) async {
    final batch = db.batch();
    for (final arg in statements.arguments) {
      batch.execute(statements.statements[arg.statementIndex], arg.arguments);
    }
    await batch.apply(noResult: true);
  }

  @override
  Future<void> runCustom(String statement, List<Object?> args) =>
      db.execute(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      db.rawInsert(statement, args);

  @override
  Future<QueryResult> runSelect(String statement, List<Object?> args) async {
    final result = await db.rawQuery(statement, args);
    return QueryResult.fromRows(result);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      db.rawUpdate(statement, args);
}

class _SqfliteCipherVersionDelegate extends DynamicVersionDelegate {
  final s.Database _db;

  _SqfliteCipherVersionDelegate(this._db);

  @override
  Future<int> get schemaVersion async {
    final result = await _db.rawQuery('PRAGMA user_version;');
    final value = result.single.values.first;
    return (value as int?) ?? 0;
  }

  @override
  Future<void> setSchemaVersion(int version) async {
    await _db.rawUpdate('PRAGMA user_version = $version;');
  }
}

/// A query executor that uses sqflite_sqlcipher internally with encryption.
class SqfliteCipherQueryExecutor extends DelegatedDatabase {
  SqfliteCipherQueryExecutor({
    required String path,
    required String password,
    bool? logStatements,
    bool singleInstance = true,
    SqfliteCipherConfigure? onConfigure,
  }) : super(
          _SqfliteCipherDelegate(
            false,
            path,
            password: password,
            singleInstance: singleInstance,
            onConfigure: onConfigure,
          ),
          logStatements: logStatements,
        );

  SqfliteCipherQueryExecutor.inDatabaseFolder({
    required String path,
    required String password,
    bool? logStatements,
    bool singleInstance = true,
    SqfliteCipherConfigure? onConfigure,
  }) : super(
          _SqfliteCipherDelegate(
            true,
            path,
            password: password,
            singleInstance: singleInstance,
            onConfigure: onConfigure,
          ),
          logStatements: logStatements,
        );

  s.Database? get sqfliteDb {
    final d = delegate as _SqfliteCipherDelegate;
    return d.isOpen ? d.db : null;
  }

  @override
  bool get isSequential => true;
}
