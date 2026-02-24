import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:otzaria/core/window_listener.dart';
import 'package:otzaria/core/window_persistence.dart';

AppWindowListener? _appWindowListener;

/// מחזיר את ה-window listener
AppWindowListener? get appWindowListener => _appWindowListener;

/// אתחול ספציפי לפלטפורמות Native (Desktop/Mobile)
Future<void> initializePlatform() async {
  // Initialize SQLite FFI for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await windowManager.ensureInitialized();

    // Configure window manager for proper close handling
    WindowOptions windowOptions = const WindowOptions(
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    // Add window listener for proper close handling
    _appWindowListener = AppWindowListener();
    windowManager.addListener(_appWindowListener!);

    await windowManager.setPreventClose(true);

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await WindowPersistence.restoreIfAny();
      await windowManager.show();
      await windowManager.focus();
    });
  }
}

/// ניקוי משאבים בסגירת האפליקציה
void cleanupPlatform() {
  _appWindowListener?.dispose();
}
