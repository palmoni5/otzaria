/// כלל join מותר בין שתי טבלאות
class PluginJoinRule {
  final String tableA;
  final String columnA;
  final String tableB;
  final String columnB;

  const PluginJoinRule({
    required this.tableA,
    required this.columnA,
    required this.tableB,
    required this.columnB,
  });

  /// בודק אם ה-join המבוקש תואם את הכלל (בשני הכיוונים)
  bool matches(String t1, String c1, String t2, String c2) {
    return (tableA == t1 && columnA == c1 && tableB == t2 && columnB == c2) ||
        (tableA == t2 && columnA == c2 && tableB == t1 && columnB == c1);
  }
}

/// מדיניות גישה למסד נתונים עבור תוסף
class PluginDatabasePolicy {
  /// שמות הטבלאות המותרות לקריאה
  final Set<String> tables;

  /// עמודות מותרות לפי שם טבלה
  final Map<String, Set<String>> columnsByTable;

  /// כללי join מותרים
  final List<PluginJoinRule> allowedJoins;

  /// מספר שורות מקסימלי לשאילתה
  final int maxLimit;

  /// מספר שאילתות מקסימלי ב-batch
  final int maxBatchQueries;

  /// מספר joins מקסימלי בשאילתה
  final int maxJoins;

  /// מספר עמודות מקסימלי ב-select
  final int maxColumns;

  /// חלון התוצאות המקסימלי שמותר לדלג עליו
  final int maxOffset;

  /// מספר תנאי WHERE מקסימלי, כולל קבוצות and/or
  final int maxWhereConditions;

  /// מספר ערכים מקסימלי בתנאי IN
  final int maxInValues;

  /// גודל מקסימלי של ערך פרמטר יחיד
  final int maxParameterBytes;

  /// גודל משוער מקסימלי של פלט השאילתה
  final int maxResultBytes;

  /// משך הריצה המקסימלי של שאילתה לפני עצירת ה-isolate
  final Duration maxQueryDuration;

  const PluginDatabasePolicy({
    required this.tables,
    required this.columnsByTable,
    required this.allowedJoins,
    this.maxLimit = 5000,
    this.maxBatchQueries = 5,
    this.maxJoins = 4,
    this.maxColumns = 32,
    this.maxOffset = 10000,
    this.maxWhereConditions = 32,
    this.maxInValues = 100,
    this.maxParameterBytes = 64 * 1024,
    this.maxResultBytes = 4 * 1024 * 1024,
    this.maxQueryDuration = const Duration(seconds: 3),
  });

  /// בודק אם טבלה מותרת
  bool isTableAllowed(String table) => tables.contains(table);

  /// בודק אם עמודה מותרת בטבלה
  bool isColumnAllowed(String table, String column) =>
      columnsByTable[table]?.contains(column) ?? false;

  /// בודק אם join מותר בין שתי עמודות
  bool isJoinAllowed(String t1, String c1, String t2, String c2) =>
      allowedJoins.any((rule) => rule.matches(t1, c1, t2, c2));
}

/// תיאור מקור נתונים SQLite שתוספים יכולים לגשת אליו
class PluginDatabaseSource {
  /// מזהה יחודי
  final String sourceId;

  /// שם תצוגה
  final String label;

  /// נתיב מוחלט לקובץ ה-DB
  final String databasePath;

  /// פתיחה במצב קריאה בלבד (מומלץ תמיד true)
  final bool readOnly;

  /// מדיניות הרשאות
  final PluginDatabasePolicy policy;

  /// המקור מכיל טקסט ספרייה: שם הוי"ה במחרוזות התוצאה מוצג לפי הגדרת
  /// המשתמש, אלא אם השאילתה ביקשה `rawDivineNames: true`.
  final bool filtersDivineNames;

  const PluginDatabaseSource({
    required this.sourceId,
    required this.label,
    required this.databasePath,
    this.readOnly = true,
    required this.policy,
    this.filtersDivineNames = false,
  });
}
