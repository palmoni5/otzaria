import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/indexing/services/indexing_isolate_service.dart';
import 'package:otzaria/search/search_query_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IndexingDocumentBuilder.normalizeTextForIndexing', () {
    test('מסיר תגי HTML', () {
      expect(
        IndexingDocumentBuilder.normalizeTextForIndexing('<p>תורה</p>'),
        'תורה',
      );
    });

    test('מסיר ניקוד וטעמים', () {
      expect(
        IndexingDocumentBuilder.normalizeTextForIndexing('בְּרֵאשִׁ֖ית'),
        'בראשית',
      );
    });

    test('ממיר ״ ל-" (כמו sanitizeQuery)', () {
      expect(
        IndexingDocumentBuilder.normalizeTextForIndexing('רמב״ם'),
        'רמב"ם',
      );
    });

    test('ממיר ׳ ל-\' (כמו sanitizeQuery)', () {
      expect(
        IndexingDocumentBuilder.normalizeTextForIndexing('א׳'),
        "א'",
      );
    });

    test('ממיר מקף עברי (־) לרווח', () {
      expect(
        IndexingDocumentBuilder.normalizeTextForIndexing('אל־משה'),
        'אל משה',
      );
    });

    test('ממיר מקף לועזי (-) לרווח', () {
      expect(
        IndexingDocumentBuilder.normalizeTextForIndexing('פר-קציאל'),
        'פר קציאל',
      );
    });

    test('מסיר תווי פיסוק לפי כללי sanitizeQuery', () {
      expect(
        IndexingDocumentBuilder.normalizeTextForIndexing('אבא;בן, גדול!'),
        'אבאבן גדול',
      );
    });

    test('מצמצם רווחים מרובים לרווח יחיד', () {
      expect(
        IndexingDocumentBuilder.normalizeTextForIndexing('תורה   ומצוות'),
        'תורה ומצוות',
      );
    });

    test('שווה־ערך ל-sanitizeQuery על קלט נטול HTML/ניקוד', () {
      // החיפוש דורש שטוקני האינדוקס יהיו זהים לטוקני השאילתה לאחר sanitize.
      const queries = [
        'רמב״ם',
        'אל־משה',
        'פר-קציאל',
        'אבא, גדול',
        'בית ספר',
      ];
      for (final query in queries) {
        expect(
          IndexingDocumentBuilder.normalizeTextForIndexing(query),
          SearchQueryBuilder.sanitizeQuery(query),
          reason: 'אינדוקס ושאילתה חייבים לייצר אותו פלט עבור: "$query"',
        );
      }
    });

    test('שילוב מלא: HTML + ניקוד + המרות + צמצום רווחים', () {
      expect(
        IndexingDocumentBuilder.normalizeTextForIndexing(
          '<b>אַבָּא־בֵּן-דָּוִד   רמב״ם, מלך!</b>',
        ),
        'אבא בן דוד רמב"ם מלך',
      );
    });
  });

  group('IndexingDocumentBuilder.normalizePdfTextForIndexing', () {
    test('מסיר תווים בלתי־נראים (ZWJ, BOM וכו\')', () {
      // תווים בלתי־נראים מטווחים ספציפיים שצינור ה-PDF מסיר
      expect(
        IndexingDocumentBuilder.normalizePdfTextForIndexing(
          'תורה​‎ומצוות﻿',
        ),
        'תורהומצוות',
      );
    });

    test('מצמצם רווחים מרובים ומחיל sanitizeQuery', () {
      expect(
        IndexingDocumentBuilder.normalizePdfTextForIndexing(
          'אבא־בן   רמב״ם',
        ),
        'אבא בן רמב"ם',
      );
    });

    test('משלב הסרת בלתי־נראים עם המרות sanitizeQuery', () {
      expect(
        IndexingDocumentBuilder.normalizePdfTextForIndexing(
          'רמב​״ם',
        ),
        'רמב"ם',
      );
    });
  });

  group('IndexingDocumentBuilder', () {
    test('builds text book documents with hierarchical references', () {
      final documents = IndexingDocumentBuilder.buildTextBookDocuments(
        '<h1>פרק א</h1>\n'
        'שורה ראשונה\n'
        '<h2>סימן א</h2>\n'
        'שורה שניה',
      );

      expect(documents, hasLength(4));
      expect(documents[0].reference, 'פרק א');
      expect(documents[0].text, 'פרק א');
      expect(documents[1].reference, 'פרק א');
      expect(documents[1].text, 'שורה ראשונה');
      expect(documents[2].reference, 'פרק א, סימן א');
      expect(documents[2].text, 'סימן א');
      expect(documents[3].reference, 'פרק א, סימן א');
      expect(documents[3].text, 'שורה שניה');
      expect(documents.map((document) => document.ordinal).toList(), [0, 1, 2, 3]);
    });

    test('replaces previous header branch when same level appears again', () {
      final documents = IndexingDocumentBuilder.buildTextBookDocuments(
        '<h1>חלק א</h1>\n'
        '<h2>סימן א</h2>\n'
        '<h1>חלק ב</h1>\n'
        'טקסט',
      );

      expect(documents.last.reference, 'חלק ב');
      expect(documents.last.text, 'טקסט');
    });
  });

  group('IndexingIsolateService', () {
    test('streams prepared text batches from isolate', () async {
      final service = await IndexingIsolateService.create();
      addTearDown(service.dispose);

      final stream = await service.processTextBook(
        text: '<h1>פרק א</h1>\nשורה א\nשורה ב',
      );

      final documents = <PreparedIndexDocument>[];
      var completed = false;

      await for (final update in stream) {
        if (update is IndexingBatchReady) {
          documents.addAll(update.documents);
          await update.acknowledge();
        } else if (update is IndexingWorkComplete) {
          completed = true;
        }
      }

      expect(completed, isTrue);
      expect(documents, hasLength(3));
      expect(documents[1].text, 'שורה א');
      expect(documents[2].text, 'שורה ב');
      expect(documents.map((document) => document.ordinal).toList(), [0, 1, 2]);
    });

    test('cancel stops further batch generation', () async {
      final service = await IndexingIsolateService.create();
      addTearDown(service.dispose);

      final text = List.generate(700, (index) => 'שורה $index').join('\n');
      final stream = await service.processTextBook(text: text);

      var batchesSeen = 0;
      var documentCount = 0;

      await for (final update in stream) {
        if (update is! IndexingBatchReady) {
          continue;
        }

        batchesSeen++;
        documentCount += update.documents.length;
        await service.cancelActiveWork();
        await update.acknowledge();
      }

      expect(batchesSeen, 1);
      expect(documentCount, lessThan(700));
    });
  });
}
