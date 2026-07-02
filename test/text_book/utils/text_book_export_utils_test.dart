import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/utils/text_book_export_utils.dart';

void main() {
  group('text book export utils', () {
    test('normalizeTextBookExportPath משאיר סיומת תואמת ללא שינוי', () {
      expect(
        normalizeTextBookExportPath(
          r'C:\exports\book.docx',
          defaultExtension: 'docx',
        ),
        r'C:\exports\book.docx',
      );
    });

    test('normalizeTextBookExportPath מחליף סיומת קיימת בסיומת שנבחרה', () {
      expect(
        normalizeTextBookExportPath(
          r'C:\exports\book.txt',
          defaultExtension: 'docx',
        ),
        r'C:\exports\book.docx',
      );
    });

    test('normalizeTextBookExportPath מוסיף סיומת כשאין סיומת קיימת', () {
      expect(
        normalizeTextBookExportPath(
          r'C:\exports\book',
          defaultExtension: 'txt',
        ),
        r'C:\exports\book.txt',
      );
    });

    test('normalizeTextBookExportPath מתעלם מנקודה בשם התיקייה', () {
      expect(
        normalizeTextBookExportPath(
          r'C:\exports.v2\book',
          defaultExtension: 'docx',
        ),
        r'C:\exports.v2\book.docx',
      );
    });

    test('sanitizeTextBookExportFileName מחליף תווים אסורים בשם קובץ', () {
      expect(
        sanitizeTextBookExportFileName('ספר: בדיקה/א'),
        'ספר_ בדיקה_א',
      );
    });

    test('applyTextBookExportTextTransforms מנקה HTML וניקוד לייצוא טקסט', () {
      expect(
        applyTextBookExportTextTransforms(
          '<b>בְּרֵאשִׁית</b>',
          removeNikud: true,
          removeTaamim: true,
          shouldReplaceHolyNames: false,
          stripHtml: true,
        ),
        'בראשית',
      );
    });
  });
}
