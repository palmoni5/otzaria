import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/utils/toc_unit_label.dart';

void main() {
  group('allUnitLabel', () {
    group('מילות מפתח מוכרות', () {
      test('פרק → כל הפרק', () {
        expect(allUnitLabel('פרק ראשון'), 'כל הפרק');
      });

      test('דף → כל הדף', () {
        expect(allUnitLabel('דף י:'), 'כל הדף');
      });

      test('פסוק → כל הפסוק', () {
        expect(allUnitLabel('פסוק א'), 'כל הפסוק');
      });

      test('סימן → כל הסימן', () {
        expect(allUnitLabel('סימן א'), 'כל הסימן');
      });

      test('אות → כל האות', () {
        expect(allUnitLabel('אות א'), 'כל האות');
      });

      test('סעיף → כל הסעיף', () {
        expect(allUnitLabel('סעיף א'), 'כל הסעיף');
      });

      test('הלכה → כל ההלכה', () {
        expect(allUnitLabel('הלכה א'), 'כל ההלכה');
      });

      test('משנה → כל המשנה', () {
        expect(allUnitLabel('משנה א'), 'כל המשנה');
      });

      test('מאמר → כל המאמר', () {
        expect(allUnitLabel('מאמר ראשון'), 'כל המאמר');
      });

      test('שאלה → כל השאלה', () {
        expect(allUnitLabel('שאלה ה'), 'כל השאלה');
      });

      test('תשובה → כל התשובה', () {
        expect(allUnitLabel('תשובה א'), 'כל התשובה');
      });

      test('עמוד → כל העמוד', () {
        expect(allUnitLabel('עמוד א'), 'כל העמוד');
      });

      test('פרשה → כל הפרשה', () {
        expect(allUnitLabel('פרשה בראשית'), 'כל הפרשה');
      });

      test('מזמור → כל המזמור', () {
        expect(allUnitLabel('מזמור כג'), 'כל המזמור');
      });
    });

    group('ברירת מחדל — כל הפיסקה', () {
      test('כותרת ספר ברירת מחדל', () {
        expect(allUnitLabel('ספר בראשית'), 'כל הפיסקה');
      });

      test('שם עצם שאינו מוכר', () {
        expect(allUnitLabel('הקדמה'), 'כל הפיסקה');
      });

      test('מחרוזת ריקה', () {
        expect(allUnitLabel(''), 'כל הפיסקה');
      });

      test('רווחים בלבד', () {
        expect(allUnitLabel('   '), 'כל הפיסקה');
      });

      test('מספר בלבד', () {
        expect(allUnitLabel('42'), 'כל הפיסקה');
      });
    });

    group('מילה ראשונה בלבד נבדקת', () {
      test('מילת מפתח שנייה לא מספיקה', () {
        // "ראשון פרק" — המילה הראשונה היא "ראשון", לא "פרק"
        expect(allUnitLabel('ראשון פרק'), 'כל הפיסקה');
      });

      test('מילת מפתח + מספרים', () {
        expect(allUnitLabel('פרק ג'), 'כל הפרק');
      });

      test('ריווח מוביל מוסר לפני בדיקה', () {
        expect(allUnitLabel('  פרק א'), 'כל הפרק');
      });
    });
  });
}
