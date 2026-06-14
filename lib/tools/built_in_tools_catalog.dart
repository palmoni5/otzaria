import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/widgets.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// מטא-דאטה לתצוגה של כלי מובנה ב-Settings (טבלת ניהול הכלים).
///
/// אינו כולל את [pageBuilder] של ה-`BuiltInToolDescriptor` המלא — רק מזהה,
/// תווית, סדר, ואייקון לתצוגה.
class BuiltInToolMeta {
  final String toolId;
  final String labelKey;
  final int order;

  /// התווית המתורגמת להצגה.
  String get label => labelKey.tr();

  /// אייקון Fluent (אם זה כלי שמשתמש באייקון מתוך החבילה).
  final IconData? icon;

  /// נתיב נכס תמונה (לכלים שמשתמשים בתמונה במקום באייקון, כמו "שמור וזכור").
  final String? imageIcon;

  const BuiltInToolMeta({
    required this.toolId,
    required this.labelKey,
    required this.order,
    this.icon,
    this.imageIcon,
  });
}

/// קטלוג הכלים המובנים — מקור סמכותי יחיד עבור ToolsScreen ומסך ההגדרות.
///
/// סדר הפריטים תואם לסדר ב-[ToolsScreenState._buildAllBuiltInDescriptors];
/// כל שינוי כאן חייב להתעדכן גם שם (או להפך).
const List<BuiltInToolMeta> kBuiltInToolsCatalog = [
  BuiltInToolMeta(
    toolId: 'builtin.calendar',
    labelKey: 'tools.tab_calendar',
    order: 10,
    icon: FluentIcons.calendar_24_regular,
  ),
  BuiltInToolMeta(
    toolId: 'builtin.shamor_zachor',
    labelKey: 'tools.tab_shamor_zachor',
    order: 20,
    imageIcon: 'assets/icon/שמור וזכור שחור ריק.png',
  ),
  BuiltInToolMeta(
    toolId: 'builtin.measurements',
    labelKey: 'tools.tab_measurements',
    order: 30,
    icon: FluentIcons.ruler_24_regular,
  ),
  BuiltInToolMeta(
    toolId: 'builtin.notes',
    labelKey: 'tools.tab_notes',
    order: 40,
    icon: FluentIcons.note_24_regular,
  ),
  BuiltInToolMeta(
    toolId: 'builtin.gematria',
    labelKey: 'tools.tab_gematria',
    order: 50,
    icon: FluentIcons.calculator_24_regular,
  ),
  BuiltInToolMeta(
    toolId: 'builtin.aramaic_dictionary',
    labelKey: 'tools.tab_aramaic_dict',
    order: 60,
    icon: FluentIcons.translate_24_regular,
  ),
  BuiltInToolMeta(
    toolId: 'builtin.acronyms_dictionary',
    labelKey: 'tools.tab_acronyms',
    order: 70,
    icon: FluentIcons.text_quote_24_regular,
  ),
];
