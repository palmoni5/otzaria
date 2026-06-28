import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/text/global_search_helper.dart';

void main() {
  setUpAll(() async {
    // טוען את התרגומים האמיתיים כדי ש-.tr() יחזיר טקסט מתורגם בבדיקות.
    final data = jsonDecode(
      await File('assets/translations/he-IL.json').readAsString(),
    ) as Map<String, dynamic>;
    Localization.load(
      const Locale('he', 'IL'),
      translations: Translations(data),
    );
  });

  group('previewForLabel', () {
    test('מחזיר את הטקסט כמו שהוא כשהוא קצר מספיק', () {
      expect(previewForLabel('בראשית'), 'בראשית');
    });

    test('חותך עם אליפסיס כשהטקסט עולה על maxLen', () {
      const longText = 'בראשית ברא אלהים את השמים ואת הארץ והארץ הייתה תהו';
      final result = previewForLabel(longText, maxLen: 10);
      expect(result.length, 11); // 10 + אליפסיס
      expect(result.endsWith('…'), isTrue);
      expect(result.startsWith('בראשית ברא'), isTrue);
    });

    test('מנרמל רווחים מרובים לרווח אחד', () {
      expect(previewForLabel('  אבג   דהו  '), 'אבג דהו');
    });
  });

  group('buildSearchMenuLabel', () {
    testWidgets('מציג את הקידומת "חפש \'", הטקסט שנבחר והסיומת בנפרד',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 400, child: _Wrapper()),
          ),
        ),
      );

      expect(find.text("חפש '"), findsOneWidget);
      expect(find.text('בראשית'), findsOneWidget);
      expect(find.text("' בספר זה"), findsOneWidget);
    });

    testWidgets('הטקסט שנבחר עטוף ב-Flexible (כדי לאפשר חיתוך עם …)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 400, child: _Wrapper()),
          ),
        ),
      );

      // מאתר את ה-Text של הטקסט הנבחר
      final selectedTextFinder = find.text('בראשית');
      expect(selectedTextFinder, findsOneWidget);

      // עוטף ב-Flexible
      final flexibleAncestor = find.ancestor(
        of: selectedTextFinder,
        matching: find.byType(Flexible),
      );
      expect(flexibleAncestor, findsOneWidget);

      // הגדרות חיתוך נכונות
      final selectedTextWidget = tester.widget<Text>(selectedTextFinder);
      expect(selectedTextWidget.overflow, TextOverflow.ellipsis);
      expect(selectedTextWidget.softWrap, isFalse);
      expect(selectedTextWidget.maxLines, 1);
    });

    testWidgets('הסיומת לא עטופה ב-Flexible (תמיד מוצגת במלואה)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 400, child: _Wrapper()),
          ),
        ),
      );

      final suffixFinder = find.text("' בספר זה");
      expect(suffixFinder, findsOneWidget);

      final flexibleAncestor = find.ancestor(
        of: suffixFinder,
        matching: find.byType(Flexible),
      );
      expect(
        flexibleAncestor,
        findsNothing,
        reason: 'הסיומת חייבת להישאר גלויה גם כשרוחב מצומצם',
      );
    });

    testWidgets('הקידומת לא עטופה ב-Flexible (תמיד מוצגת במלואה)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 400, child: _Wrapper()),
          ),
        ),
      );

      final prefixFinder = find.text("חפש '");
      expect(prefixFinder, findsOneWidget);

      final flexibleAncestor = find.ancestor(
        of: prefixFinder,
        matching: find.byType(Flexible),
      );
      expect(flexibleAncestor, findsNothing);
    });

    testWidgets('Row מתכווץ ל-MainAxisSize.min', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 400, child: _Wrapper()),
          ),
        ),
      );

      final row = tester.widget<Row>(find.ancestor(
        of: find.text('בראשית'),
        matching: find.byType(Row),
      ));
      expect(row.mainAxisSize, MainAxisSize.min);
    });

    testWidgets('סיומת מותאמת אישית — "בכל הספרים"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: buildSearchMenuLabel(
                selectedText: 'בראשית',
                suffix: 'בכל הספרים',
              ),
            ),
          ),
        ),
      );

      expect(find.text("' בכל הספרים"), findsOneWidget);
      expect(find.text("' בספר זה"), findsNothing);
    });

    testWidgets('טקסט נבחר ארוך אינו מוסיף עטיפת softWrap (שורה אחת בלבד)',
        (tester) async {
      const longText =
          'בראשית ברא אלהים את השמים ואת הארץ והארץ הייתה תהו ובהו';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: buildSearchMenuLabel(
                selectedText: longText,
                suffix: 'בספר זה',
              ),
            ),
          ),
        ),
      );

      final selectedTextWidget = tester.widget<Text>(find.text(longText));
      expect(selectedTextWidget.softWrap, isFalse,
          reason: 'softWrap=false חיוני כדי שהטקסט לא יעטוף לשורה שנייה');
      expect(selectedTextWidget.maxLines, 1);
    });
  });
}

class _Wrapper extends StatelessWidget {
  const _Wrapper();

  @override
  Widget build(BuildContext context) {
    return buildSearchMenuLabel(
      selectedText: 'בראשית',
      suffix: 'בספר זה',
    );
  }
}
