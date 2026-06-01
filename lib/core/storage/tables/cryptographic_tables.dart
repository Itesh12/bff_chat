import 'package:drift/drift.dart';

@DataClassName('SignalSessionRow')
class SignalSessionsTable extends Table {
  @override
  String get tableName => 'signal_sessions';

  TextColumn get addressName => text()();
  IntColumn get deviceId => integer()();
  BlobColumn get sessionRecord => blob()();

  @override
  Set<Column> get primaryKey => {addressName, deviceId};
}

@DataClassName('SignalOneTimePrekeyRow')
class SignalOneTimePrekeysTable extends Table {
  @override
  String get tableName => 'signal_one_time_prekeys';

  IntColumn get preKeyId => integer()();
  BlobColumn get preKeyRecord => blob()();

  @override
  Set<Column> get primaryKey => {preKeyId};
}

@DataClassName('SignalSkippedKeyRow')
class SignalSkippedKeysTable extends Table {
  @override
  String get tableName => 'signal_skipped_keys';

  TextColumn get senderId => text()();
  TextColumn get ratchetKey => text()();
  IntColumn get sequenceNumber => integer()();
  BlobColumn get keyBytes => blob()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {senderId, ratchetKey, sequenceNumber};
}
