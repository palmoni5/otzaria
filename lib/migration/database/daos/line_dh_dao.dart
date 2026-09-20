import 'package:otzaria/data/sqlite/sqlite3_api.dart' as sqlite3;

import 'database.dart';

/// דיבור-מתחיל בודד, עם `line.id` שלו לשליפת מפרשים על אותה שורה.
typedef DibburCandidate = ({
  int bookId,
  int lineIndex,
  int lineId,
  String display,
});

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

  /// הדיבורים שתחילתם [prefix] בכל אחד מ-[bookIds], בשאילתה מאוגדת אחת.
  ///
  /// כש-[contains] דלוק, [prefix] מחופש בכל מקום בדיבור — מסלול יקר יותר
  /// (סריקת שורות הספרים), ולכן הקורא מפעיל אותו רק כשהתחילית לא החזירה כלום.
  Future<List<DibburCandidate>> dibburimForBooks(
    List<int> bookIds,
    String prefix, {
    bool contains = false,
    int limit = 40,
  }) async {
    if (bookIds.isEmpty || prefix.isEmpty || !await isAvailable()) {
      return const [];
    }
    final db = await database;
    final ids = bookIds.join(',');
    final match = contains
        ? "d.dhText LIKE '%' || ? || '%'"
        // התו הגבוה ביותר ב-Unicode סוגר את טווח התחילית מלמעלה.
        : 'd.dhText >= ? AND d.dhText < ? || char(1114111)';
    final args = contains ? [prefix, limit] : [prefix, prefix, limit];
    return db
        .select(
          'SELECT d.bookId, d.lineIndex, d.dhDisplay AS display, '
          'l.id AS lineId '
          'FROM line_dh d '
          'JOIN line l ON l.bookId = d.bookId AND l.lineIndex = d.lineIndex '
          'WHERE d.bookId IN ($ids) AND $match '
          'ORDER BY d.bookId, d.lineIndex '
          'LIMIT ?',
          args,
        )
        .map(
          (row) => (
            bookId: row['bookId'] as int,
            lineIndex: row['lineIndex'] as int,
            lineId: row['lineId'] as int,
            display: (row['display'] as String?) ?? '',
          ),
        )
        .toList();
  }
}
