/// שירות לזיהוי וניהול שפות זמינות באפליקציה.
///
/// קורא את AssetManifest בעת אתחול ומזהה את כל קבצי התרגום
/// שנמצאים תחת `assets/translations/`. כל קובץ JSON שם מציין שפה זמינה.
///
/// תבנית שמות הקבצים:
/// • `<lang>.json` — לדוגמה `en.json` → Locale('en')
/// • `<lang>-<country>.json` — לדוגמה `he-IL.json` → Locale('he', 'IL')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class LocaleService {
  /// ברירת מחדל — נשמר עד שתסתיים האתחול.
  static List<Locale> _availableLocales = const [Locale('he', 'IL')];

  /// רשימת השפות הזמינות (לפי קבצי JSON שנמצאו).
  static List<Locale> get availableLocales => _availableLocales;

  /// קורא את AssetManifest ומאתר את כל קבצי התרגום הזמינים.
  /// יש לקרוא לפונקציה זו לפני אתחול EasyLocalization.
  static Future<void> initialize() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assetPaths = manifest.listAssets();

      final locales = <Locale>[];
      for (final assetPath in assetPaths) {
        if (!assetPath.startsWith('assets/translations/')) continue;
        if (!assetPath.endsWith('.json')) continue;

        final filename = assetPath.split('/').last.replaceAll('.json', '');
        final parts = filename.split('-');
        if (parts.length == 1 && parts[0].isNotEmpty) {
          locales.add(Locale(parts[0]));
        } else if (parts.length == 2 &&
            parts[0].isNotEmpty &&
            parts[1].isNotEmpty) {
          locales.add(Locale(parts[0], parts[1]));
        }
      }

      // הבטחה שהעברית תמיד תהיה זמינה
      if (!locales
          .any((l) => l.languageCode == 'he' && l.countryCode == 'IL')) {
        locales.add(const Locale('he', 'IL'));
      }

      _availableLocales = locales;

      if (kDebugMode) {
        debugPrint(
          'LocaleService: discovered locales: '
          '${locales.map((l) => l.toString()).join(", ")}',
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('LocaleService: failed to load locales: $error\n$stackTrace');
      }
    }
  }

  /// השם הילידי (native name) של שפה — מוצג ב-dropdown של הבחירה.
  static String displayNameOf(Locale locale) {
    const nativeNames = {
      'he': 'עברית',
      'en': 'English',
      'ar': 'العربية',
      'yi': 'יידיש',
      'fr': 'Français',
      'es': 'Español',
      'ru': 'Русский',
      'de': 'Deutsch',
      'pt': 'Português',
      'it': 'Italiano',
      'tr': 'Türkçe',
      'pl': 'Polski',
      'uk': 'Українська',
      'nl': 'Nederlands',
      'ja': '日本語',
      'zh': '中文',
      'ko': '한국어',
      'hi': 'हिन्दी',
      'fa': 'فارسی',
    };
    return nativeNames[locale.languageCode] ?? locale.toString();
  }
}
