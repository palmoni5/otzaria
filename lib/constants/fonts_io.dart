import 'package:system_fonts/system_fonts.dart' show SystemFonts;

/// מחזירה רשימת גופני מערכת (Desktop/Mobile)
Future<Map<String, String>> getSystemFontsMap() async {
  try {
    return SystemFonts().getFontMap();
  } catch (_) {
    return {};
  }
}

/// טוען גופן מערכת
Future<void> loadSystemFont(String fontFamily) async {
  try {
    await SystemFonts().loadFont(fontFamily);
  } catch (_) {
    // אם לא ניתן לטעון, נשאיר את fallback של Flutter
  }
}
