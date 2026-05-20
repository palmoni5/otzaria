/// כלים לטיפול בהערות שוליים inline שמקודדות בתוכן השורה כ-HTML:
///   <sup class="footnote-marker">marker</sup><i class="footnote">body</i>
///
/// הספרים האלה (כ-322 ב-DB) מקודדים את גוף ההערה בתוך השורה עצמה, ולא
/// בקובץ נלווה. אנו מציגים אותם כמפרש וירטואלי בצד, ומסירים אותם מגוף
/// הספר.
library;

final RegExp _footnoteBodyRegExp = RegExp(
  r'<i\b[^>]*\bclass\s*=\s*"[^"]*\bfootnote\b[^"]*"[^>]*>(.*?)</i>',
  caseSensitive: false,
  dotAll: true,
);

const String _supCloseTag = '</sup>';

/// מסיר את גוף ההערות (<i class="footnote">...</i>) משורה אחת.
/// משאיר את ה-<sup> במקומו כעוגן ויזואלי לאיפה הייתה ההערה.
String stripInlineNotes(String html) {
  if (!html.contains('footnote')) return html;
  return html.replaceAll(_footnoteBodyRegExp, '');
}

/// בודק אם הספר מכיל לפחות שורה אחת עם הערה inline.
bool hasInlineNotes(List<String> content) {
  for (final line in content) {
    if (_footnoteBodyRegExp.hasMatch(line)) return true;
  }
  return false;
}

/// מחלץ את ההערות מסט שורות (לפי האינדקסים שניתנו).
///
/// כל ערך ברשימה הוא מחרוזת HTML שמכילה את ה-<sup>marker</sup> שצמוד
/// לפני ההערה (אם יש) ואחריו את גוף ההערה. אם אין <sup> צמוד - מוחזר
/// רק גוף ההערה.
///
/// משתמש ב-lastIndexOf במקום regex עם $-anchor כדי להבטיח שלכל הערה
/// מצמידים אך ורק את ה-<sup> שמופיע מיד לפניה (ולא רצף של <sup>-ים
/// קודמים יחד עם תוכן ביניהם).
List<String> notesForLines(
  List<String> content,
  Iterable<int> indexes,
) {
  final results = <String>[];
  for (final idx in indexes) {
    if (idx < 0 || idx >= content.length) continue;
    final line = content[idx];
    if (!line.contains('footnote')) continue;

    for (final iMatch in _footnoteBodyRegExp.allMatches(line)) {
      final body = iMatch.group(1) ?? '';
      final before = line.substring(0, iMatch.start);

      final closeIdx = before.lastIndexOf(_supCloseTag);
      if (closeIdx >= 0) {
        final tail = before.substring(closeIdx + _supCloseTag.length);
        if (tail.trim().isEmpty) {
          final openIdx = before.lastIndexOf('<sup', closeIdx);
          if (openIdx >= 0) {
            final supTag =
                before.substring(openIdx, closeIdx + _supCloseTag.length);
            results.add('$supTag $body');
            continue;
          }
        }
      }
      results.add(body);
    }
  }
  return results;
}
