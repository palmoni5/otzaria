import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// בודק האם גרסת WebView2 הזמינה במכשיר מתאימה להרצת תוספים.
///
/// תוספים נופלים על מכשירים עם WebView2 v143 או ישן יותר (לדוגמה, מכשירים
/// שלא קיבלו עדכון של Edge WebView2 Runtime). הקריסה היא native ב-MSVCP140
/// בקריאה מ-EmbeddedBrowserWebView.dll v143, ולא ניתן לטפל בה ב-Dart.
///
/// במקום לאפשר ל-WebView להיווצר ולקרוס — בודקים את הגרסה קודם, ואם היא
/// נמוכה מ-[minimumSupportedMajor], מסרבים ליצור WebView ומאפשרים להציג
/// הודעה ידידותית למשתמש.
class WebView2CompatCheck {
  /// הגרסה הראשית המינימלית של Edge WebView2 הנתמכת לתוספים.
  /// v143 ידועה כקורסת על Windows 10 1903; v144+ בודקים שנפתרה.
  static const int minimumSupportedMajor = 144;

  /// תוצאה מטמונה כדי לא לקרוא ל-IPC בכל build של widget.
  static WebView2CompatResult? _cached;

  /// בודק (פעם אחת) את גרסת WebView2 הזמינה במערכת.
  ///
  /// בפלטפורמות שאינן Windows, מחזיר תמיד supported (יש implementation אחר
  /// — Android WebView ו-WKWebView). הבדיקה רלוונטית ל-Windows בלבד.
  static Future<WebView2CompatResult> check() async {
    final cached = _cached;
    if (cached != null) return cached;
    final result = await _doCheck();
    _cached = result;
    return result;
  }

  static Future<WebView2CompatResult> _doCheck() async {
    if (kIsWeb || !Platform.isWindows) {
      return const WebView2CompatResult(
          supported: true, version: null, majorVersion: null);
    }
    try {
      final version = await WebViewEnvironment.getAvailableVersion();
      if (version == null || version.isEmpty) {
        return const WebView2CompatResult(
          supported: false,
          version: null,
          majorVersion: null,
        );
      }
      final major = _parseMajor(version);
      final supported = major != null && major >= minimumSupportedMajor;
      return WebView2CompatResult(
        supported: supported,
        version: version,
        majorVersion: major,
      );
    } catch (e) {
      debugPrint('WebView2CompatCheck failed: $e');
      // אם הבדיקה עצמה נכשלה — מניחים שלא נתמך כדי לא לקרוס.
      return WebView2CompatResult(
        supported: false,
        version: null,
        majorVersion: null,
        error: e.toString(),
      );
    }
  }

  static int? _parseMajor(String version) {
    final dot = version.indexOf('.');
    final firstPart = dot >= 0 ? version.substring(0, dot) : version;
    return int.tryParse(firstPart);
  }

  /// משמש לאיפוס המטמון בטסטים בלבד.
  @visibleForTesting
  static void resetCacheForTesting() {
    _cached = null;
  }
}

/// תוצאת בדיקת תאימות WebView2.
class WebView2CompatResult {
  final bool supported;
  final String? version;
  final int? majorVersion;
  final String? error;

  const WebView2CompatResult({
    required this.supported,
    required this.version,
    required this.majorVersion,
    this.error,
  });

  /// תיאור הסיבה לכך שאין תמיכה (לשימוש בהודעה למשתמש).
  String get reasonForUser {
    if (version == null) {
      return 'לא נמצאה התקנה של Microsoft Edge WebView2 Runtime במכשיר.';
    }
    return 'גרסת Edge WebView2 Runtime המותקנת (v$version) ישנה מדי. '
        'נדרשת גרסה $minimumSupportedMajor ומעלה כדי להריץ תוספים.';
  }

  static int get minimumSupportedMajor =>
      WebView2CompatCheck.minimumSupportedMajor;
}
