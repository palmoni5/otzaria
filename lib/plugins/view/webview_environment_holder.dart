import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:otzaria/core/app_paths.dart';

/// מחזיק את ה-WebViewEnvironment הסינגלטוני עם userDataFolder הניתן לכתיבה.
///
/// בהתקנה מערכתית (Program Files), WebView2 מנסה כברירת מחדל לכתוב לצד
/// קובץ ה-EXE — תיקייה read-only למשתמש רגיל — ונכשל עם
/// "Cannot create the InAppWebView instance!".
/// הגדרת נתיב מפורש תחת APPDATA פותרת זאת.
class WebViewEnvironmentHolder {
  static WebViewEnvironment? _environment;

  /// Future יחיד המגן מפני קריאות מקבילות ל-initialize().
  static Future<void>? _initFuture;

  /// Future משותף לאתחול כל תנאי המוקדמים ל-WebView (סביבה + Android debug).
  /// משמש גם את PluginTabPage וגם את _BackgroundPluginRunner.
  static Future<void>? _prereqFuture;

  /// מחזיר את ה-WebViewEnvironment שנוצר באתחול, או null בפלטפורמות שאינן Windows.
  static WebViewEnvironment? get environment => _environment;

  /// מאתחל את סביבת WebView2 עם תיקיית נתונים הניתנת לכתיבה.
  /// מוגן מפני קריאות מקבילות — מריץ את הלוגיקה פעם אחת בלבד.
  static Future<void> initialize() {
    if (!Platform.isWindows) return Future.value();
    if (_environment != null) return Future.value();
    return _initFuture ??= _doInitialize();
  }

  static Future<void> _doInitialize() async {
    if (_environment != null) return;
    final dataRoot = await AppPaths.getDataRootPath();
    final webviewDataFolder = p.join(dataRoot, 'webview2');
    await Directory(webviewDataFolder).create(recursive: true);
    _environment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(userDataFolder: webviewDataFolder),
    );
  }

  /// מוודא שכל התנאים המוקדמים ל-WebView מאותחלים (Android debug + Windows env).
  /// בטוח לקריאה מרובה — מריץ פעם אחת בלבד.
  static Future<void> ensurePrerequisites() {
    return _prereqFuture ??= _doEnsurePrerequisites();
  }

  static Future<void> _doEnsurePrerequisites() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
    }
    if (Platform.isWindows) {
      await initialize();
    }
  }

  /// Disposes the current Windows WebView environment after the old widget
  /// tree has been torn down during an in-process app restart.
  static Future<void> disposeForAppRestart() async {
    if (!Platform.isWindows) return;

    _initFuture = null;
    _prereqFuture = null;

    final environment = _environment;
    _environment = null;
    if (environment == null) return;

    environment.onNewBrowserVersionAvailable = null;
    environment.onBrowserProcessExited = null;
    environment.onProcessInfosChanged = null;

    try {
      await environment.dispose();
    } catch (_) {}
  }
}
