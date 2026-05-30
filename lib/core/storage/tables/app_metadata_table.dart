import 'package:drift/drift.dart';

/// Internal application metadata stored as key-value pairs.
///
/// Scope: Infrastructure only.
/// - [configKey]   Unique string key (e.g. 'db_version', 'install_id')
/// - [configValue] String value associated with the key
/// - [updatedAt]   UTC epoch ms of last write
///
/// NOTE: This table is intentionally generic.
/// Feature tables (Notes, Vault, Messages) are defined in later phases.
class AppMetadata extends Table {
  TextColumn get configKey => text()();
  TextColumn get configValue => text()();
  IntColumn get updatedAt => integer().withDefault(Constant(0))();

  @override
  Set<Column> get primaryKey => {configKey};
}
