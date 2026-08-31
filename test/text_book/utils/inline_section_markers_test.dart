import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:otzaria/text_book/utils/inline_section_markers.dart';

void main() {
  group('prependSectionMarker', () {
    test('מקדים אות מודגשת בסוגריים מרובעים לפני התוכן', () {
      expect(
        prependSectionMarker('רַבִּי הוֹשַׁעְיָה רַבָּה פָּתַח', 'א'),
        '<b>[א]</b> רַבִּי הוֹשַׁעְיָה רַבָּה פָּתַח',
      );
    });

    test('תווית רב-אותית (יא, סעיף ג) נשמרת כלשונה', () {
      expect(
        prependSectionMarker('טקסט', 'סעיף ג'),
        '<b>[סעיף ג]</b> טקסט',
      );
    });

    test('שורה עם תגי HTML — הסמן נכנס לפני התג הראשון', () {
      expect(
        prependSectionMarker('<big>בְּ</big>רֵאשִׁית', 'ב'),
        '<b>[ב]</b> <big>בְּ</big>רֵאשִׁית',
      );
    });

    test('label null — השורה חוזרת כמות שהיא', () {
      expect(prependSectionMarker('טקסט', null), 'טקסט');
    });

    test('label ריק — השורה חוזרת כמות שהיא', () {
      expect(prependSectionMarker('טקסט', ''), 'טקסט');
    });

    test('שורה ריקה — נשארת ריקה גם עם label', () {
      expect(prependSectionMarker('', 'א'), '');
    });
  });

  group('seifMarkersFromLinkRows', () {
    Map<String, dynamic> row(int lineIndex, String baseHeRef) => {
      'lineIndex': lineIndex,
      'baseHeRef': baseHeRef,
    };

    test('סמן בשורה הראשונה של כל קבוצת ס"ק לפי הסעיף המפורש', () {
      // כדוגמת משנה ברורה סימן א: ס"ק א-ח על סעיף א, ט-יא על סעיף ג.
      final markers = seifMarkersFromLinkRows([
        row(29, 'שולחן ערוך, אורח חיים א, א'),
        row(30, 'שולחן ערוך, אורח חיים א, א'),
        row(31, 'שולחן ערוך, אורח חיים א, א'),
        row(37, 'שולחן ערוך, אורח חיים א, ג'),
        row(38, 'שולחן ערוך, אורח חיים א, ג'),
        row(40, 'שולחן ערוך, אורח חיים א, ד'),
      ]);
      expect(markers, {29: 'סעיף א', 37: 'סעיף ג', 40: 'סעיף ד'});
    });

    test('שורה עם כמה קישורים — הקישור הראשון קובע את הסעיף', () {
      final markers = seifMarkersFromLinkRows([
        row(10, 'שולחן ערוך, אורח חיים ב, א'),
        row(10, 'שולחן ערוך, אורח חיים ב, ג'),
        row(11, 'שולחן ערוך, אורח חיים ב, ג'),
      ]);
      expect(markers, {10: 'סעיף א', 11: 'סעיף ג'});
    });

    test('מעבר לסימן חדש שחוזר לסעיף א מקבל סמן גם הוא', () {
      final markers = seifMarkersFromLinkRows([
        row(47, 'שולחן ערוך, אורח חיים א, ח'),
        row(50, 'שולחן ערוך, אורח חיים ב, א'),
      ]);
      expect(markers, {47: 'סעיף ח', 50: 'סעיף א'});
    });

    test('סימן חדש שנפתח באותה אות סעיף מקבל סמן — המפתח הוא הסימן+הסעיף', () {
      final markers = seifMarkersFromLinkRows([
        row(47, 'שולחן ערוך, אורח חיים א, א'),
        row(50, 'שולחן ערוך, אורח חיים ב, א'),
      ]);
      expect(markers, {47: 'סעיף א', 50: 'סעיף א'});
    });

    test('heRef בלי פסיק או ריק — השורה מדולגת', () {
      final markers = seifMarkersFromLinkRows([
        row(5, 'ללא פסיק'),
        row(6, 'שולחן ערוך, אורח חיים א,   '),
        row(7, 'שולחן ערוך, אורח חיים א, ב'),
      ]);
      expect(markers, {7: 'סעיף ב'});
    });

    test('רשימה ריקה — מפה ריקה', () {
      expect(seifMarkersFromLinkRows(const []), isEmpty);
    });
  });
}
