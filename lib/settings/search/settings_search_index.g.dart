// קובץ stub בסיסי — מאפשר קומפילציה גם בלי הרצת ה-generator.
// ה-hook (hook/build.dart) מחליף את התוכן הזה ברשימה המלאה
// בכל `flutter run` / `flutter build`. ל-CI אפשר להריץ ידנית
// `dart run tool/generate_search_index.dart`.
//
// לכן: בטוח לדחוף את הגרסה הבסיסית הזו לרפו — היא תיכתב מקומית
// בכל בנייה ולא תפריע.

import 'package:otzaria/settings/search/settings_search_models.dart';

/// כל פריטי החיפוש שנאספו מהטאבים והפנלים. ייכתב על ידי ה-generator.
const List<SettingsSearchEntry> kGeneratedSettingsSearchEntries = [];
