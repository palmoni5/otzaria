import 'package:sqflite/sqflite.dart';
import 'sql_provider.dart';

/// Stub implementation - לא אמור להיקרא
class StubSqlProvider implements SqlProvider {
  @override
  Future<Database> openDatabase(
    String path, {
    int? version,
    OnDatabaseConfigureFn? onConfigure,
    OnDatabaseCreateFn? onCreate,
    OnDatabaseVersionChangeFn? onUpgrade,
    OnDatabaseVersionChangeFn? onDowngrade,
    OnDatabaseOpenFn? onOpen,
  }) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<String> getDatabasesPath() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> deleteDatabase(String path) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<bool> databaseExists(String path) async {
    throw UnsupportedError('Platform not supported');
  }
}

/// יוצר instance של SqlProvider
SqlProvider createSqlProvider() {
  return StubSqlProvider();
}
