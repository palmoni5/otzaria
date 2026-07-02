import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/user_content_import/models/user_import_models.dart';

/// גישת כתיבה/קריאה לנתוני-המשתמש ב-user_books.db: דור הספר (book_generation)
/// וקישורי-משתמש מיובאים (user_link).
///
/// משתמש ב-SQL ישיר על אותו [MyDatabase] של user_books.db (writable).
class UserContentRepository {
  final MyDatabase _db;
  bool _seeded = false;

  UserContentRepository(this._db);

  /// מוחק את כל נתוני-הייבוא (דור + קישורים). ב-user_books.db טבלאות אלה
  /// מנוהלות אך ורק ע"י הייבוא, לכן בטוח לרוקן. משמש את פעולת "נקה הכל"
  /// (הייבוא עצמו מצטבר ואינו מנקה).
  Future<void> clearAllUserContent() async {
    final db = await _db.database;
    db.execute('DELETE FROM book_generation');
    db.execute('DELETE FROM user_link');
  }

  // ---- דורות ----

  /// מוסיף את שמות הדורות הקנוניים (idempotent). מבוצע פעם אחת לכל instance —
  /// קריאות חוזרות (למשל מכל setBookGeneration) הן no-op.
  Future<void> seedCanonicalGenerations() async {
    if (_seeded) return;
    final db = await _db.database;
    for (final name in kCanonicalEraNames) {
      db.execute('INSERT OR IGNORE INTO generation (name) VALUES (?)', [name]);
    }
    _seeded = true;
  }

  Future<int?> generationIdByName(String name) async {
    final db = await _db.database;
    final rows =
        db.select('SELECT id FROM generation WHERE name = ? LIMIT 1', [name]);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Future<int?> bookIdByTitle(String title, {int? categoryId}) async {
    final db = await _db.database;
    final rows = categoryId != null
        ? db.select(
            'SELECT id FROM book WHERE title = ? AND categoryId = ? LIMIT 1',
            [title, categoryId])
        : db.select('SELECT id FROM book WHERE title = ? LIMIT 1', [title]);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  /// קובע את דור הספר לפי שם דור קנוני (מחליף דור קודם — idempotent).
  Future<void> setBookGeneration(int bookId, String eraName) async {
    await seedCanonicalGenerations();
    final genId = await generationIdByName(eraName);
    if (genId == null) return;
    final db = await _db.database;
    db.execute('DELETE FROM book_generation WHERE bookId = ?', [bookId]);
    db.execute(
      'INSERT INTO book_generation (bookId, generationId) VALUES (?, ?)',
      [bookId, genId],
    );
  }

  // ---- קישורי-משתמש ----

  /// מוסיף קישור-משתמש, או דורס קישור זהה אם כבר קיים. שני קישורים נחשבים
  /// "זהים" כשכל שדות הזיהוי שווים (מקור, שורת-מקור, יעד ומיקומו); רק
  /// [UserLinkRecord.connectionType] מתעדכן. כך ייבוא חוזר מצטבר ואינו מכפיל.
  Future<void> upsertUserLink(UserLinkRecord link) async {
    final db = await _db.database;
    // השוואת השדות ב-IS (ולא =) כדי ש-NULL ישווה ל-NULL — אחרת קישור עם
    // targetRef/targetLineIndex ריק לא היה נדרס בייבוא חוזר.
    db.execute(
      'DELETE FROM user_link WHERE sourceTitle = ? AND sourceIsUserBook = ? '
      'AND sourceCategoryId IS ? AND sourceLineIndex = ? '
      'AND targetTitle = ? AND targetIsUserBook = ? AND targetCategoryId IS ? '
      'AND targetRef IS ? AND targetLineIndex IS ?',
      [
        link.sourceTitle,
        link.sourceIsUserBook ? 1 : 0,
        link.sourceCategoryId,
        link.sourceLineIndex,
        link.targetTitle,
        link.targetIsUserBook ? 1 : 0,
        link.targetCategoryId,
        link.targetRef,
        link.targetLineIndex,
      ],
    );
    db.execute(
      'INSERT INTO user_link (sourceTitle, sourceCategoryId, sourceIsUserBook, '
      'sourceLineIndex, targetTitle, targetCategoryId, targetIsUserBook, '
      'targetRef, targetLineIndex, connectionType) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        link.sourceTitle,
        link.sourceCategoryId,
        link.sourceIsUserBook ? 1 : 0,
        link.sourceLineIndex,
        link.targetTitle,
        link.targetCategoryId,
        link.targetIsUserBook ? 1 : 0,
        link.targetRef,
        link.targetLineIndex,
        link.connectionType,
      ],
    );
  }

  /// קישורי-משתמש *יוצאים* מספר מקור (לפי כותרת+דגל), בטווח שורות (0-based,
  /// כולל). כשידועה קטגוריית המקור מסננים גם לפיה; שורות בלי קטגוריה עוברות.
  Future<List<UserLinkRecord>> forwardUserLinks(
    String sourceTitle, {
    required bool sourceIsUserBook,
    int? sourceCategoryId,
    int? startLineIndex,
    int? endLineIndex,
  }) async {
    final db = await _db.database;
    final categoryClause = sourceCategoryId != null
        ? 'AND (sourceCategoryId IS NULL OR sourceCategoryId = ?)'
        : '';
    final hasRange = startLineIndex != null && endLineIndex != null;
    final rangeClause = hasRange ? 'AND sourceLineIndex BETWEEN ? AND ?' : '';
    final rows = db.select(
      'SELECT * FROM user_link WHERE sourceTitle = ? AND sourceIsUserBook = ? '
      '$categoryClause $rangeClause ORDER BY sourceLineIndex',
      [
        sourceTitle,
        sourceIsUserBook ? 1 : 0,
        if (sourceCategoryId != null) sourceCategoryId,
        if (hasRange) ...[startLineIndex, endLineIndex],
      ],
    );
    return rows.map(_fromRow).toList();
  }

  /// קישורי-משתמש *נכנסים* אל ספר יעד (לפי כותרת) — לתצוגה הפוכה. למשל
  /// מפרש-משתמש על ספר רשמי מופיע כשפותחים את הספר הרשמי.
  Future<List<UserLinkRecord>> inverseUserLinks(
    String targetTitle, {
    required bool targetIsUserBook,
    int? targetCategoryId,
    int? startLineIndex,
    int? endLineIndex,
  }) async {
    final db = await _db.database;
    // כשידועה קטגוריית היעד, מסננים גם לפיה (כדי לא לערבב בין שני ספרי-יעד
    // בעלי אותה כותרת בקטגוריות שונות). שורות בלי קטגוריה תמיד עוברות.
    final categoryClause = targetCategoryId != null
        ? 'AND (ul.targetCategoryId IS NULL OR ul.targetCategoryId = ?)'
        : '';
    final hasRange = startLineIndex != null && endLineIndex != null;
    final rangeClause =
        hasRange ? 'AND ul.targetLineIndex BETWEEN ? AND ?' : '';
    final rows = db.select(
      'SELECT ul.* FROM user_link ul '
      'WHERE ul.targetTitle = ? AND ul.targetIsUserBook = ? '
      '$categoryClause $rangeClause '
      'ORDER BY ul.targetLineIndex',
      [
        targetTitle,
        targetIsUserBook ? 1 : 0,
        if (targetCategoryId != null) targetCategoryId,
        if (hasRange) ...[startLineIndex, endLineIndex],
      ],
    );
    return rows.map(_fromRow).toList();
  }

  UserLinkRecord _fromRow(Map<String, Object?> row) => UserLinkRecord(
        sourceTitle: row['sourceTitle'] as String,
        sourceCategoryId: row['sourceCategoryId'] as int?,
        sourceIsUserBook: (row['sourceIsUserBook'] as int? ?? 0) == 1,
        sourceLineIndex: row['sourceLineIndex'] as int,
        targetTitle: row['targetTitle'] as String,
        targetCategoryId: row['targetCategoryId'] as int?,
        targetIsUserBook: (row['targetIsUserBook'] as int? ?? 0) == 1,
        targetRef: row['targetRef'] as String?,
        targetLineIndex: row['targetLineIndex'] as int?,
        connectionType: row['connectionType'] as String,
      );
}
