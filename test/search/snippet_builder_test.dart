import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/search_query_builder.dart';
import 'package:otzaria/search/utils/snippet_builder.dart';

void main() {
  test('buildHighlightSpans מדגיש חלופה שסופקה ב-alternativeWords', () {
    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: 'אמר שלום לכל אדם',
      query: 'ברכה',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: const {},
      alternativeWords: const {
        0: ['שלום'],
      },
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join();

    expect(highlighted, contains('שלום'));
  });

  test('buildHighlightSpans מכבד קידומות דקדוקיות ומדגיש רק את בסיס המילה', () {
    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: 'והחכמה מאין תמצא',
      query: 'חכמה',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: {
        SearchQueryBuilder.buildWordKey('חכמה', 0): const {
          'קידומות דקדוקיות': true,
        },
      },
      alternativeWords: const {},
      fallbackToIndividualWords: false,
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join();

    expect(highlighted, 'חכמה');
  });

  test('buildExcerptText מעגן את הקטע להתאמת phrase הראשונה עם spacing', () {
    final excerpt = SnippetBuilder.buildExcerptText(
      fullText: 'פתיח ארוך מאוד אבג מילה1 מילה2 דהו המשך נוסף ולאחר מכן אבג',
      query: 'אבג דהו',
      maxChars: 40,
      searchOptions: const {},
      alternativeWords: const {},
      spacingValues: const {'0-1': '2'},
      fallbackToIndividualWords: false,
    );

    expect(excerpt, contains('אבג מילה1 מילה2 דהו'));
    expect(excerpt, isNot(contains('לאחר מכן אבג')));
  });

  test('SnippetBuilder שומר גרשיים בתצוגת ראשי תיבות', () {
    final spans = SnippetBuilder.createSnippetSpans(
      fullHtml: '<p>רש"י אומר</p>',
      query: 'רשי',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      availableWidth: 400,
      searchOptions: const {},
      alternativeWords: const {},
    );

    final renderedText =
        spans.whereType<TextSpan>().map((span) => span.text ?? '').join();

    expect(renderedText, contains('רש"י'));
  });

  // ── סימטריה מול sanitizeQuery ────────────────────────────────────────────
  // sanitizeQuery ממיר ״→" ו-׳→' ו-־→רווח ו-‎-→רווח. הטקסט המוצג נשאר
  // עם הצורה המקורית, ולכן ההדגשה חייבת לזהות שתי הצורות.

  test('הדגשה: שאילתה עם ״ עברי מדגישה רמב״ם (גרשיים בטקסט)', () {
    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: 'אמר רמב״ם בפירושו',
      query: 'רמב״ם',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: const {},
      alternativeWords: const {},
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join();

    expect(highlighted, 'רמב״ם');
  });

  test('הדגשה: שאילתה עם " לועזי מדגישה רמב״ם (גרשיים עבריים בטקסט)', () {
    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: 'אמר רמב״ם בפירושו',
      query: 'רמב"ם',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: const {},
      alternativeWords: const {},
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join();

    expect(highlighted, 'רמב״ם');
  });

  test('הדגשה: שאילתה עם " לועזי מדגישה גם רמב"ם (לועזי בטקסט)', () {
    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: 'אמר רמב"ם בפירושו',
      query: 'רמב"ם',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: const {},
      alternativeWords: const {},
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join();

    expect(highlighted, 'רמב"ם');
  });

  test('הדגשה: שאילתה עם ׳ עברי מדגישה גם א׳ וגם א\' בטקסט', () {
    final spansHebrew = SnippetBuilder.buildHighlightSpans(
      plainText: 'בפרק א׳ של הספר',
      query: 'א׳',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: const {},
      alternativeWords: const {},
    );
    final highlightedHebrew = spansHebrew
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join();
    expect(highlightedHebrew, 'א׳');

    final spansLatin = SnippetBuilder.buildHighlightSpans(
      plainText: "בפרק א' של הספר",
      query: 'א׳',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: const {},
      alternativeWords: const {},
    );
    final highlightedLatin = spansLatin
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join();
    expect(highlightedLatin, "א'");
  });

  test('הדגשה: שאילתה עם מקף עברי (־) מדגישה את שתי המילים בטקסט', () {
    // sanitizeQuery הופך 'אל־משה' לשתי מילים 'אל משה'.
    // הטקסט בכל זאת מכיל 'אל־משה' אחד — _collectSearchTokens מפצל על ־ לטוקנים,
    // ו-phrase matching מאתר את שתי המילים סמוכות.
    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: 'ויאמר אל־משה לאמר',
      query: 'אל־משה',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: const {},
      alternativeWords: const {},
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .toList();

    expect(highlighted, contains('אל'));
    expect(highlighted, contains('משה'));
  });

  test('הדגשה: שאילתה עם מקף לועזי (-) מדגישה את שתי המילים בטקסט', () {
    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: 'מערכת אבא-גדול בשימוש',
      query: 'אבא-גדול',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: const {},
      alternativeWords: const {},
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .toList();

    expect(highlighted, contains('אבא'));
    expect(highlighted, contains('גדול'));
  });

  test('SnippetBuilder מדגיש גם התאמה דומה כשהופעלו שגיאות כתיב', () {
    final spans = SnippetBuilder.createSnippetSpans(
      fullHtml: '<p>חכמה לכל העולם</p>',
      query: 'חמכה',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      availableWidth: 400,
      searchOptions: {
        SearchQueryBuilder.buildWordKey('חמכה', 0): const {
          'שגיאות כתיב': true,
        },
      },
      alternativeWords: const {},
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join();

    expect(highlighted, contains('חכמה'));
  });

  test('SnippetBuilder לא מרחיב את הקטע לטוקנים דומים רחוקים', () {
    final spans = SnippetBuilder.createSnippetSpans(
      fullHtml: '<p>שלון ${'אבגדה ' * 80} שלום לכל העולם</p>',
      query: 'שלומ',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      availableWidth: 220,
      searchOptions: {
        SearchQueryBuilder.buildWordKey('שלומ', 0): const {
          'שגיאות כתיב': true,
        },
      },
      alternativeWords: const {},
    );

    final renderedText =
        spans.whereType<TextSpan>().map((span) => span.text ?? '').join();

    expect(renderedText, contains('שלום'));
    expect(renderedText, isNot(contains('שלון')));
  });

  test('SnippetBuilder לא מוסיף התאמה דומה רחוקה כשיש התאמה מדויקת', () {
    final spans = SnippetBuilder.createSnippetSpans(
      fullHtml: '<p>שלומ ${'אבגדה ' * 80} שלום לכל העולם</p>',
      query: 'שלום',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      availableWidth: 220,
      searchOptions: {
        SearchQueryBuilder.buildWordKey('שלום', 0): const {
          'שגיאות כתיב': true,
        },
      },
      alternativeWords: const {},
    );

    final renderedText =
        spans.whereType<TextSpan>().map((span) => span.text ?? '').join();

    expect(renderedText, contains('שלום'));
    expect(renderedText, isNot(contains('שלומ')));
  });

  test('SnippetBuilder מדגיש phrase עם custom spacing בין מילים', () {
    final spans = SnippetBuilder.createSnippetSpans(
      fullHtml: '<p>אבג מילה1 מילה2 דהו</p>',
      query: 'אבג דהו',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      availableWidth: 400,
      searchOptions: const {},
      alternativeWords: const {},
      customSpacing: const {'0-1': '2'},
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join('|');

    expect(highlighted, contains('אבג'));
    expect(highlighted, contains('דהו'));
  });

  test('SnippetBuilder לא מדגיש הופעות בודדות כש-custom spacing לא מספיק', () {
    final spans = SnippetBuilder.createSnippetSpans(
      fullHtml: '<p>אבג מילה1 מילה2 מילה3 דהו</p>',
      query: 'אבג דהו',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      availableWidth: 400,
      searchOptions: const {},
      alternativeWords: const {},
      customSpacing: const {'0-1': '2'},
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join();

    final renderedText =
        spans.whereType<TextSpan>().map((span) => span.text ?? '').join();

    expect(renderedText, contains('אבג'));
    expect(renderedText, contains('דהו'));
    expect(highlighted, isEmpty);
  });

  test('SnippetBuilder מדגיש טקסט מנוקד עם spacing בין מילים', () {
    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: 'וְעַתָּה יֵרֶא פַּרְעֹה אִישׁ נָבוֹן וְחָכָם',
      query: 'פרעה נבון',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: const {},
      alternativeWords: const {},
      spacingValues: const {'0-1': '1'},
      fallbackToIndividualWords: false,
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join('|');

    expect(highlighted, contains('פַּרְעֹה'));
    expect(highlighted, contains('נָבוֹן'));
  });

  test('SnippetBuilder מדגיש טקסט מנוקד גם עם searchDistance ללא spacing מפורש',
      () {
    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: 'וְעַתָּה יֵרֶא פַּרְעֹה אִישׁ נָבוֹן וְחָכָם',
      query: 'פרעה נבון',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: const {},
      alternativeWords: const {},
      searchDistance: 1,
      fallbackToIndividualWords: false,
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join('|');

    expect(highlighted, contains('פַּרְעֹה'));
    expect(highlighted, contains('נָבוֹן'));
  });

  test('SnippetBuilder לא נתקע על בחירה גרידית כשיש התאמה חוקית מאוחרת', () {
    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: 'A B X C B C',
      query: 'A B C',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: const {},
      alternativeWords: const {},
      spacingValues: const {'0-1': '4', '1-2': '0'},
      fallbackToIndividualWords: false,
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join('|');

    expect(highlighted, isNotEmpty);
    expect(highlighted, contains('A'));
    expect(highlighted, contains('B'));
    expect(highlighted, contains('C'));
  });

  test('SnippetBuilder מדגיש phrase כשמונח ראשון הוא חלק ממילה', () {
    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: 'זהו כינויי השני הידוע',
      query: 'כינוי השני',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: {
        SearchQueryBuilder.buildWordKey('כינוי', 0): const {
          'חלק ממילה': true,
        },
      },
      alternativeWords: const {},
      fallbackToIndividualWords: false,
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join('|');

    expect(highlighted, contains('כינוי'));
    expect(highlighted, contains('השני'));
  });

  test('SnippetBuilder typo tolerance מתחשב גם ב-alternativeWords', () {
    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: 'אמר שלומ לכל אדם',
      query: 'ברכה',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: {
        SearchQueryBuilder.buildWordKey('ברכה', 0): const {
          'שגיאות כתיב': true,
        },
      },
      alternativeWords: const {
        0: ['שלום'],
      },
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join();

    expect(highlighted, contains('שלומ'));
  });

  test('SnippetBuilder typo tolerance מתחשב גם בכתיב מלא וחסר', () {
    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: 'דד אמר',
      query: 'דויד',
      defaultStyle: const TextStyle(),
      highlightStyle: const TextStyle(fontWeight: FontWeight.bold),
      searchOptions: {
        SearchQueryBuilder.buildWordKey('דויד', 0): const {
          'כתיב מלא/חסר': true,
          'שגיאות כתיב': true,
        },
      },
      alternativeWords: const {},
    );

    final highlighted = spans
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.bold)
        .map((span) => span.text ?? '')
        .join();

    expect(highlighted, contains('דד'));
  });
}
