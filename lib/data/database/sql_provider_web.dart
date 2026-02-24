import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';
import 'sql_provider.dart';

/// מימוש SqlProvider לפלטפורמת Web
/// משתמש ב-sqlite3_web (SQLite דרך WASM)
class WebSqlProvider implements SqlProvider {
  static bool _initialized = false;

  /// אתחול חד-פעמי של SQLite לווב
  static Future<void> initialize() async {
    if (!_initialized) {
      // Set the database factory for web
      databaseFactory = databaseFactoryFfiWeb;
      _initialized = true;
    }
  }

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
    await initialize();
    return await databaseFactoryFfiWeb.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: onConfigure,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        onDowngrade: onDowngrade,
        onOpen: onOpen,
      ),
    );
  }

  @override
  Future<String> getDatabasesPath() async {
    // בווב, נשתמש בנתיב וירטואלי
    return '/databases';
  }

  @override
  Future<void> deleteDatabase(String path) async {
    await initialize();
    await databaseFactoryFfiWeb.deleteDatabase(path);
  }

  @override
  Future<bool> databaseExists(String path) async {
    await initialize();
    return await databaseFactoryFfiWeb.databaseExists(path);
  }
}

/// יוצר instance של SqlProvider לפלטפורמת Web
SqlProvider createSqlProvider() {
  return WebSqlProvider();
}
