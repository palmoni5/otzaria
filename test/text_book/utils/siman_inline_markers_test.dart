import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/utils/siman_inline_markers.dart';

void main() {
  group('prependSimanMarker', () {
    test('מקדים אות מודגשת בסוגריים מרובעים לפני התוכן', () {
      expect(
        prependSimanMarker('רַבִּי הוֹשַׁעְיָה רַבָּה פָּתַח', 'א'),
        '<b>[א]</b> רַבִּי הוֹשַׁעְיָה רַבָּה פָּתַח',
      );
    });

    test('תווית רב-אותית (יא, קכג) נשמרת כלשונה', () {
      expect(
        prependSimanMarker('טקסט', 'קכג'),
        '<b>[קכג]</b> טקסט',
      );
    });

    test('שורה עם תגי HTML — האות נכנסת לפני התג הראשון', () {
      expect(
        prependSimanMarker('<big>בְּ</big>רֵאשִׁית', 'ב'),
        '<b>[ב]</b> <big>בְּ</big>רֵאשִׁית',
      );
    });

    test('label null — השורה חוזרת כמות שהיא', () {
      expect(prependSimanMarker('טקסט', null), 'טקסט');
    });

    test('label ריק — השורה חוזרת כמות שהיא', () {
      expect(prependSimanMarker('טקסט', ''), 'טקסט');
    });

    test('שורה ריקה — נשארת ריקה גם עם label', () {
      expect(prependSimanMarker('', 'א'), '');
    });
  });
}
