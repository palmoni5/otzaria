// לוגיקה טהורה לבניית קישורי deep link לספרים.

import 'package:easy_localization/easy_localization.dart' hide TextDirection;

/// בניית קישור ישיר לספר טקסט לפי מזהה
String buildBookLink(int bookId) => 'otzaria://open/book/$bookId';

/// בניית קישור ישיר לספר PDF לפי מזהה (משותף עם TextBook)
String buildPdfBookLink(int bookId) => 'otzaria://open/pdf/$bookId';

/// בניית קישור ישיר למקטע ספציפי בספר טקסט.
/// ערכי index שליליים מוחלפים ב-0.
String buildSectionLink(int bookId, int index) =>
    'otzaria://open/book/$bookId?index=${index < 0 ? 0 : index}';

/// בניית קישור ישיר לעמוד ספציפי בספר PDF.
/// ערכי page שליליים מוחלפים ב-1.
String buildPdfPageLink(int bookId, int page) =>
    'otzaria://open/pdf/$bookId?index=${page < 1 ? 1 : page}';

/// בניית קישור למקטע עם הדגשת המקטע כולו.
/// ערכי index שליליים מוחלפים ב-0.
String buildSectionMarkLink(int bookId, int index) =>
    'otzaria://open/book/$bookId?index=${index < 0 ? 0 : index}&mark';

/// בניית קישור למקטע עם הדגשת טקסט ספציפי.
/// text ריק או רווחים בלבד → מחזיר null (לא לבנות קישור).
/// ערכי index שליליים מוחלפים ב-0.
String? buildTextMarkLink(int bookId, int index, String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final encoded = Uri.encodeComponent(trimmed);
  return 'otzaria://open/book/$bookId?index=${index < 0 ? 0 : index}&m=$encoded';
}

/// בניית רשימת פריטי תת-תפריט "העתק קישור ישיר" עבור תפריט הלחיצה הימנית.
/// הקישור לספר עצמו מוצג בתפריט "אפשרויות נוספות" שבסרגל העליון, ולכן אינו
/// כלול כאן כדי למנוע כפילות.
/// מחזיר 2 פריטים ללא טקסט מסומן, 3 פריטים עם טקסט מסומן לא-ריק.
/// כל פריט מכיל label ו-link (link יכול להיות null אם הבנייה נכשלה).
List<({String label, String? link})> buildDirectLinkSubmenuEntries({
  required int bookId,
  required int index,
  required String? selectedText,
}) {
  final entries = <({String label, String? link})>[
    (
      label: 'utils.copy_section_link'.tr(),
      link: buildSectionLink(bookId, index)
    ),
    (
      label: 'utils.copy_section_mark_link'.tr(),
      link: buildSectionMarkLink(bookId, index)
    ),
  ];

  if (selectedText != null && selectedText.trim().isNotEmpty) {
    entries.add((
      label: 'utils.copy_text_mark_link'.tr(),
      link: buildTextMarkLink(bookId, index, selectedText),
    ));
  }

  return entries;
}
