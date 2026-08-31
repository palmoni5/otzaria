import 'package:flutter_test/flutter_test.dart';
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
}
