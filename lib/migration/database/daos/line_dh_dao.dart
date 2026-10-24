import 'package:otzaria/data/sqlite/sqlite3_api.dart' as sqlite3;

import 'database.dart';

/// דיבור-מתחיל בודד, עם `line.id` שלו לשליפת מפרשים על אותה שורה.
typedef DibburCandidate = ({
  int bookId,
  int lineIndex,
  int lineId,
  String display,
  String? heRef,
});

/// ציון בתוך ספר שהדיבור חייב לשבת בו: שם הספר ו-[refKeyTokens] של הציון.
typedef DibburLocation = ({String bookTitle, List<String> keyTokens});

/// גישה ל-`line_dh` — דיבורי-המתחיל `(bookId, dhText) → lineIndex`.
///
/// `dhText` מנורמל (בלי ניקוד וגרשיים) ויושב ב-PRIMARY KEY, ולכן חיפוש
/// תחילית בתוך ספר מוגש מהאינדקס. הטבלה והעמודה `dhDisplay` נוספו בגרסאות
/// מאוחרות של המסד; [isAvailable] מאפשר לקורא לדלג בשקט על מסד ישן.
class LineDhDao {
  final MyDatabase _db;
  bool? _available;

  LineDhDao(this._db);

  Future<sqlite3.Database> get database => _db.database;

  /// האם המסד הנוכחי מכיל את הטבלה **ואת** עמודת התצוגה. נבדק פעם אחת ונשמר.
  Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    final db = await database;
    final hasTable = db
        .select(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' "
          "AND name = 'line_dh' LIMIT 1",
        )
        .isNotEmpty;
    if (!hasTable) return _available = false;
    final hasDisplay = db
        .select("PRAGMA table_info('line_dh')")
        .any((row) => row['name'] == 'dhDisplay');
    return _available = hasDisplay;
  }

  /// הדיבורים שתחילתם [prefix] בכל אחד מ-[bookIds], בשאילתה מאוגדת אחת,
  /// בסדר הספרים שנמסר: התקרה חותכת את הספרים האחרונים ברשימה.
  ///
  /// כש-[contains] דלוק, [prefix] מחופש בכל מקום בדיבור — מסלול יקר יותר
  /// (סריקת שורות הספרים), ולכן הקורא מפעיל אותו רק כשהתחילית לא החזירה כלום.
  /// [where] מסנן לפני התקרה, כך שדיבורים שנדחו אינם תופסים את מקומה.
  Future<List<DibburCandidate>> dibburimForBooks(
    List<int> bookIds,
    String prefix, {
    bool contains = false,
    int limit = 40,
    bool Function(DibburCandidate dibbur)? where,
  }) async {
    if (bookIds.isEmpty || prefix.isEmpty || !await isAvailable()) {
      return const [];
    }
    final db = await database;
    final ids = [
      for (var i = 0; i < bookIds.length; i++) '(${bookIds[i]}, $i)',
    ].join(',');
    final match = contains
        ? "d.dhText LIKE '%' || ? || '%'"
        // התו הגבוה ביותר ב-Unicode סוגר את טווח התחילית מלמעלה.
        : 'd.dhText >= ? AND d.dhText < ? || char(1114111)';
    final statement = db.prepare(
      'WITH ids(bookId, priority) AS (VALUES $ids) '
      'SELECT d.bookId, d.lineIndex, d.dhDisplay AS display, '
      'l.id AS lineId, l.heRef '
      'FROM ids '
      'JOIN line_dh d ON d.bookId = ids.bookId '
      'JOIN line l ON l.bookId = d.bookId AND l.lineIndex = d.lineIndex '
      'WHERE $match '
      'ORDER BY ids.priority, d.lineIndex',
    );
    final found = <DibburCandidate>[];
    try {
      final cursor = statement.selectCursor(
        contains ? [prefix] : [prefix, prefix],
      );
      while (found.length < limit && cursor.moveNext()) {
        final row = cursor.current;
        final dibbur = (
          bookId: row['bookId'] as int,
          lineIndex: row['lineIndex'] as int,
          lineId: row['lineId'] as int,
          display: (row['display'] as String?) ?? '',
          heRef: row['heRef'] as String?,
        );
        if (where == null || where(dibbur)) found.add(dibbur);
      }
    } finally {
      statement.close();
    }
    return found;
  }
}
