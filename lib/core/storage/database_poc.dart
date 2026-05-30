import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'dart:io';

part 'database_poc.g.dart';

class PocItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
}

@DriftDatabase(tables: [PocItems])
class PocDatabase extends _$PocDatabase {
  PocDatabase(String dbPath, String password) : super(_openConnection(dbPath, password));
  
  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection(String dbPath, String password) {
  return SqfliteQueryExecutor.inDatabaseFolder(
    path: dbPath,
    singleInstance: true,
    creator: (File file) {
      return openDatabase(
        file.path,
        password: password,
        version: 1,
        onCreate: (db, version) async {
          // setup handled by drift
        },
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys=ON;');
        },
      );
    },
  );
}

Future<void> runDatabasePoc() async {
  debugPrint('\n=== STARTING DRIFT + SQLCIPHER POC ===\n');

  final dbDir = await getApplicationDocumentsDirectory();
  final dbPath = '${dbDir.path}/poc.db';

  await deleteDatabase(dbPath);

  const validPassword = 'MySecretPassword123!';
  const wrongPassword = 'WrongPassword456!';

  debugPrint('[POC] 1. Creating encrypted DB with sqflite_sqlcipher directly...');
  var dbRaw = await openDatabase(
    dbPath,
    password: validPassword,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('CREATE TABLE PocItems (id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT)');
    }
  );

  debugPrint('[POC] 2. Inserting record...');
  await dbRaw.insert('PocItems', {'content': 'Super Secret Data'});
  
  debugPrint('[POC] 3. Closing DB...');
  await dbRaw.close();

  debugPrint('[POC] 4. Reopening DB with valid key...');
  dbRaw = await openDatabase(dbPath, password: validPassword, version: 1);
  
  debugPrint('[POC] 5. Reading record...');
  final items = await dbRaw.query('PocItems');
  debugPrint('[POC]    Found ${items.length} item(s): ${items.first['content']}');
  
  debugPrint('[POC] 6. Closing DB again...');
  await dbRaw.close();

  debugPrint('[POC] 7. Attempting open with WRONG key...');
  try {
    await openDatabase(dbPath, password: wrongPassword, version: 1);
    debugPrint('[POC] ❌ ERROR: Database opened with wrong key! Encryption failed.');
  } catch (e) {
    debugPrint('[POC] ✅ SUCCESS: Database rejected wrong key.');
    debugPrint('[POC]    Error caught: $e');
  }
  debugPrint('\n=== DRIFT + SQLCIPHER POC FINISHED ===\n');
}
