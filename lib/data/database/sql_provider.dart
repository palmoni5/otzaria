import 'package:sqflite/sqflite.dart';

/// שכבת הפשטה ל-SQL Database
/// מאפשרת החלפה בין sqflite (Native) ל-sqlite3_web (Web)
abstract class SqlProvider {
  /// פותח מסד נתונים
  Future<Database> openDatabase(
    String path, {
    int? version,
    OnDatabaseConfigureFn? onConfigure,
    OnDatabaseCreateFn? onCreate,
    OnDatabaseVersionChangeFn? onUpgrade,
    OnDatabaseVersionChangeFn? onDowngrade,
    OnDatabaseOpenFn? onOpen,
  });

  /// מחזיר את נתיב תיקיית מסדי הנתונים
  Future<String> getDatabasesPath();

  /// מוחק מסד נתונים
  Future<void> deleteDatabase(String path);

  /// בודק אם מסד נתונים קיים
  Future<bool> databaseExists(String path);
}
