import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:path/path.dart' as path;

/// שליפת דיבורי-המתחיל מ-`line_dh` — המסלול שמאחורי איתור "ד"ה" (issue #1415).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('otzaria-line-dh-test-');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  var dbCounter = 0;

  Future<MyDatabase> buildDb({
    bool withTable = true,
    bool withDisplay = true,
  }) async {
    final db = MyDatabase.withPath(
      path.join(tempDir.path, 'test${dbCounter++}.db'),
    );
    addTearDown(db.close);
    final conn = await db.database;
    // טבלת line נוצרת ע"י סכמת המסד עצמה — רק השורות מוזרקות כאן.
    conn.execute(
      "INSERT INTO line (id, bookId, lineIndex, content) VALUES "
      "(501, 1, 3, ''), (502, 1, 40, ''), (503, 2, 7, '')",
    );
    if (!withTable) return db;
    conn.execute(
      'CREATE TABLE line_dh (bookId INTEGER NOT NULL, dhText TEXT NOT NULL, '
      'lineIndex INTEGER NOT NULL'
      '${withDisplay ? ', dhDisplay TEXT NOT NULL' : ''}, '
      'PRIMARY KEY (bookId, dhText, lineIndex)) WITHOUT ROWID',
    );
    const rows = [
      (1, 'מאימתי קורין וכו', 3, "מאימתי קורין וכו'"),
      (1, 'ואמר רבי יוחנן', 40, 'ואמר רבי יוחנן'),
      (2, 'הכל שוחטין', 7, 'הכל שוחטין'),
    ];
    for (final row in rows) {
      conn.execute(
        withDisplay
            ? 'INSERT INTO line_dh (bookId, dhText, lineIndex, dhDisplay) '
                  'VALUES (?, ?, ?, ?)'
            : 'INSERT INTO line_dh (bookId, dhText, lineIndex) '
                  'VALUES (?, ?, ?)',
        [
          row.$1,
          row.$2,
          row.$3,
          if (withDisplay) row.$4,
        ],
      );
    }
    return db;
  }

  test('תחילית מחזירה את הדיבור עם שורת המקור שלו', () async {
    final db = await buildDb();
    final found = await db.lineDhDao.dibburimForBooks([1, 2], 'מאימתי');

    expect(found, hasLength(1));
    expect(found.single.bookId, 1);
    expect(found.single.lineIndex, 3);
    expect(found.single.lineId, 501);
    expect(found.single.display, "מאימתי קורין וכו'");
  });

  test('תחילית של כמה מילים', () async {
    final db = await buildDb();
    final found = await db.lineDhDao.dibburimForBooks([1], 'ואמר רבי');

    expect(found.single.lineIndex, 40);
  });

  test('תחילית שאינה קיימת מחזירה ריק', () async {
    final db = await buildDb();
    expect(await db.lineDhDao.dibburimForBooks([1, 2], 'שוחטין'), isEmpty);
  });

  test('מסלול "מכיל" תופס מילה מאמצע הדיבור', () async {
    final db = await buildDb();
    final found = await db.lineDhDao.dibburimForBooks(
      [1, 2],
      'שוחטין',
      contains: true,
    );

    expect(found.single.bookId, 2);
    expect(found.single.lineId, 503);
  });

  test('הספרים שלא נשאלו אינם מוחזרים', () async {
    final db = await buildDb();
    final found = await db.lineDhDao.dibburimForBooks(
      [1],
      'הכל',
      contains: true,
    );

    expect(found, isEmpty);
  });

  test('מסד בלי הטבלה או בלי עמודת התצוגה מחזיר ריק בלי לזרוק', () async {
    final noTable = await buildDb(withTable: false);
    expect(await noTable.lineDhDao.dibburimForBooks([1], 'מאימתי'), isEmpty);

    final noDisplay = await buildDb(withDisplay: false);
    expect(await noDisplay.lineDhDao.dibburimForBooks([1], 'מאימתי'), isEmpty);
  });

  test('רשימת ספרים ריקה או תחילית ריקה אינן פונות למסד', () async {
    final db = await buildDb();
    expect(await db.lineDhDao.dibburimForBooks([], 'מאימתי'), isEmpty);
    expect(await db.lineDhDao.dibburimForBooks([1], ''), isEmpty);
  });
}
