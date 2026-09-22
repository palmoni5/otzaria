import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// המעדכן החיצוני מחליף קבצים רק אחרי שהתהליך יצא, ולכן אישור "מוכן
/// להתקנה" חייב לבקש גם משאר החלונות להיסגר. הבקשה היא **בקשה**: המסלול
/// הוא הסגירה הרגילה של כל חלון, ושומר שיסרב משאיר אותו פתוח.
///
/// סריקת מקור ולא הרצה: המסלול מסתיים ביציאת התהליך.
void main() {
  late List<String> updateSource;

  setUpAll(() {
    updateSource = [
      for (final file in Directory(
        'lib/update',
      ).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart'))
          ...file.readAsLinesSync().where(
            (line) => !line.trimLeft().startsWith('//'),
          ),
    ];
    expect(updateSource, isNotEmpty, reason: 'הסריקה חייבת לרוץ משורש החבילה');
  });

  test('מסלול העדכון מבקש משאר החלונות להיסגר', () {
    expect(
      updateSource.any(
        (line) => line.contains('MultiWindowService.closePeers'),
      ),
      isTrue,
    );
  });

  test('מסלול העדכון אינו מכבה חלונות אחרים בכפייה', () {
    for (final forced in ['forceTerminate', 'quitApplication(', 'exit(0)']) {
      expect(
        updateSource.any((line) => line.contains(forced)),
        isFalse,
        reason: '$forced היה הורג את ה-isolates של שאר החלונות בלי שומרי סגירה',
      );
    }
  });
}
