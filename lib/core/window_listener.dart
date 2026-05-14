import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:otzaria/core/pre_close_registry.dart';
import 'package:otzaria/core/window_persistence.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/data/data_providers/user_books_database_holder.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Callback type for fullscreen state changes
typedef FullscreenCallback = void Function(bool isFullscreen);

/// Window listener that handles window events properly to prevent crashes
class AppWindowListener extends WindowListener {
  static const MethodChannel _processControlChannel = MethodChannel(
    'otzaria/process_control',
  );

  FullscreenCallback? onFullscreenChanged;

  /// נקרא לאחר אירועי מצב חלון דיסקרטיים שעלולים לגרום לאיבוד פוקוס:
  /// maximize, unmaximize, restore, כניסה/יציאה ממסך מלא.
  VoidCallback? onWindowStateChanged;

  /// נקרא בכל אירוע resize רציף — מיועד ל-debounced restore.
  VoidCallback? onWindowResizeOccurred;
  bool _isClosing = false;

  Future<void> _runBestEffortShutdownStep(
    String stepName,
    Future<void> Function() action, {
    required Duration timeout,
  }) async {
    try {
      await action().timeout(timeout);
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('WebView shutdown step timed out: $stepName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WebView shutdown step failed ($stepName): $e');
      }
    }
  }

  Future<void> _armForceExitWatchdog() async {
    if (kIsWeb || !Platform.isWindows) {
      return;
    }

    // Backstop watchdog: kills the process if shutdown hangs for any reason.
    // The native side (flutter_window.cpp) clamps the requested value to
    // [5000, 60000] ms, so the effective timeout is 5 seconds — enough that
    // a normal shutdown completes well within it, short enough that Windows
    // doesn't put up a "Not Responding" dialog if something does block.
    await _processControlChannel.invokeMethod('armForceExitWatchdog', {
      'timeoutMs': 4500,
    });
  }

  @override
  void onWindowEnterFullScreen() {
    if (kDebugMode) {
      debugPrint('Window entered fullscreen');
    }
    onFullscreenChanged?.call(true);
    onWindowStateChanged?.call();
  }

  @override
  void onWindowLeaveFullScreen() {
    if (kDebugMode) {
      debugPrint('Window left fullscreen');
    }
    onFullscreenChanged?.call(false);
    onWindowStateChanged?.call();
  }

  @override
  void onWindowClose() async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;

    if (kDebugMode) {
      debugPrint('Window close requested');
    }

    await _runBestEffortShutdownStep(
      'armForceExitWatchdog',
      _armForceExitWatchdog,
      timeout: const Duration(seconds: 1),
    );

    // Step 1: Non-critical SQLite cleanup. Errors here must not block the
    // remaining shutdown steps (PreCloseRegistry + exit).
    try {
      await UserBooksDatabaseHolder.instance.close();
      await SqliteDataProvider.instance.dispose();
    } catch (e) {
      if (kDebugMode) print('Non-critical cleanup error: $e');
    }

    // Step 2: Run registered pre-close callbacks (e.g. HistoryBloc flushing
    // pending snapshots via `box.put()`). The writes go through Dart → OS
    // file buffer; the OS flushes those buffers when handles close on exit.
    Object? flushFailure;
    try {
      await PreCloseRegistry.runAll();
    } on PreCloseFlushFailure catch (e) {
      flushFailure = e;
      if (kDebugMode) print('Flush failed at exit: $e');
    }

    // Step 3: Error reporting and window destruction.
    //
    // We intentionally do NOT call `WindowPersistence.saveNow()` or
    // `Hive.close()` here. Both perform Hive writes, and in Windows admin
    // installs (`Program Files\אוצריא\`) those writes block the entire Dart
    // isolate indefinitely — likely Defender/AV scanning files written by
    // elevated processes synchronously stalls FlushFileBuffers. Even per-call
    // timeouts don't fire, because the isolate's event loop is frozen until
    // the native call returns. User-install and portable builds were unaffected.
    //
    // Safety: window bounds are already on disk via `scheduleSave` (400ms
    // debounce on every move/resize/maximize). Hive's append-only writes are
    // sent to the OS file buffer on each `put()`, so the OS releases handles
    // cleanly on `exit(0)`. Partial trailing records are detected and dropped
    // on next open via checksum validation.
    try {
      if (flushFailure != null) {
        // Report BEFORE Sentry.close() so the event can still be sent.
        try {
          await Sentry.captureException(
            flushFailure,
            stackTrace: StackTrace.current,
          );
        } catch (_) {
          // Sentry reporting is best-effort; never block the close path.
        }
      }

      if (!kIsWeb && Platform.isWindows) {
        // Sentry.close() calls sentry_close() through synchronous FFI on
        // Windows and can block while the native worker flushes. This path
        // exits the process immediately below, so don't delay app shutdown
        // for telemetry cleanup.
      } else {
        await Sentry.close();
      }

      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        if (Platform.isWindows) {
          // window_manager.destroy() posts WM_QUIT on Windows. Awaiting it can
          // stop the Flutter engine before the Dart continuation reaches exit().
          exit(0);
        }

        await windowManager.setPreventClose(false);
        // סגירה רגילה דרך ה-WindowManager
        await windowManager.destroy();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error during window close: $e');
      }
      // נשמור על exit(0) רק למקרה חירום של קריסה בתהליך הסגירה
      exit(0);
    }
  }

  @override
  void onWindowFocus() {
    if (kDebugMode) {
      //print('Window focused');
    }
    // איפוס מצב המקלדת בעת קבלת פוקוס, למנוע AssertionError ב-HardwareKeyboard
    // כאשר המשתמש מחזיק מקש, מחליף חלון, ומשחרר - Flutter לא מקבל KeyUpEvent
    // ובעת חזרה לחלון, מקש ה-KeyDown הבא גורם ל-assertion failure
    // ignore: invalid_use_of_visible_for_testing_member
    HardwareKeyboard.instance.clearState();
  }

  @override
  void onWindowBlur() {
    if (kDebugMode) {
      //print('Window blurred');
    }
  }

  @override
  void onWindowMinimize() {
    if (kDebugMode) {
      debugPrint('Window minimized');
    }
  }

  @override
  void onWindowRestore() {
    if (kDebugMode) {
      debugPrint('Window restored');
    }
    onWindowStateChanged?.call();
  }

  @override
  void onWindowResize() {
    if (kDebugMode) {
      debugPrint('Window resized');
    }

    if (WindowPersistence.isRestoring) return;
    WindowPersistence.scheduleSave();
    onWindowResizeOccurred?.call();
  }

  @override
  void onWindowMove() {
    if (kDebugMode) {
      debugPrint('Window moved');
    }

    if (WindowPersistence.isRestoring) return;
    WindowPersistence.scheduleSave();
  }

  @override
  void onWindowMaximize() {
    if (kDebugMode) {
      debugPrint('Window maximized');
    }
    if (WindowPersistence.isRestoring) return;
    WindowPersistence.scheduleSave();
    onWindowStateChanged?.call();
  }

  @override
  void onWindowUnmaximize() {
    if (kDebugMode) {
      debugPrint('Window unmaximized');
    }
    if (WindowPersistence.isRestoring) return;
    WindowPersistence.scheduleSave();
    onWindowStateChanged?.call();
  }

  /// Clean up the listener when disposing
  void dispose() {
    // Remove this listener from window manager
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.removeListener(this);
    }
  }
}
