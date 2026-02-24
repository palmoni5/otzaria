import 'package:sqflite/sqflite.dart' as sqflite;
import 'sql_provider.dart';

/// מימוש SqlProvider לפלטפורמות Native
class NativeSqlProvider implements SqlProvider {
  @override
  Future<sqflite.Database> openDatabase(
    String path, {
    int? version,
    sqflite.OnDatabaseConfigureFn? onConfigure,
    sqflite.OnDatabaseCreateFn? onCreate,
    sqflite.OnDatabaseVersionChangeFn? onUpgrade,
    sqflite.OnDatabaseVersionChangeFn? onDowngrade,
    sqflite.OnDatabaseOpenFn? onOpen,
  }) async {
    return await sqflite.openDatabase(
      path,
      version: version,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      onDowngrade: onDowngrade,
      onOpen: onOpen,
    );
  }

  @override
  Future<String> getDatabasesPath() async {
    return await sqflite.getDatabasesPath();
  }

  @override
  Future<void> deleteDatabase(String path) async {
    await sqflite.deleteDatabase(path);
  }

  @override
  Future<bool> databaseExists(String path) async {
    return await sqflite.databaseExists(path);
  }
}

/// יוצר instance של SqlProvider לפלטפורמות Native
SqlProvider createSqlProvider() {
  return NativeSqlProvider();
}
