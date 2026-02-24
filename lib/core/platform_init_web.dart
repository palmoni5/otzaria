import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';

/// מחזיר null בווב (אין window listener)
dynamic get appWindowListener => null;

/// אתחול ספציפי לפלטפורמת Web
Future<void> initializePlatform() async {
  // Initialize SQLite for web
  databaseFactory = databaseFactoryFfiWeb;
}

/// ניקוי משאבים (no-op בווב)
void cleanupPlatform() {
  // Nothing to clean up on web
}
