/// גופן CFF (OTF) אינו יכול להיות מוטמע כקובץ TrueType: הוא נכתב כ-
/// CIDFontType0 עם `/FontFile3`. בלי זה הקורא מפרש מבנה אחר מזה שקיבל.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentype_shaper/opentype_shaper.dart';
import 'package:otzaria/printing/shaped_text/pdf_shaped_font.dart';
import 'package:pdf/pdf.dart';

import '../../support/shaper_test_init.dart';

const String _pointedWord = 'שָׁ֖לֹם';

/// קובץ הגופן של חבילת `otzaria_ashurit`, דרך מפת החבילות של הבדיקה.
File? _packagedFont(String name) {
  final root = resolvedTestPackageRoot('otzaria_ashurit');
  if (root == null) return null;
  final file = File('${root.path}/lib/$name');
  return file.existsSync() ? file : null;
}

void main() {
  final font = _packagedFont('OtzariaAshurit-Regular.otf');

  final skipReason = font == null
      ? 'the Ashurit package is not resolved'
      : null;

  group('PdfShapedFont with CFF outlines', () {
    late ShaperFont shaper;
    late PdfDocument document;
    late PdfShapedFont pdfFont;
    late Uint8List bytes;

    setUp(() {
      bytes = font!.readAsBytesSync();
      shaper = ShaperFont.register(bytes);
      document = PdfDocument(compress: false);
      pdfFont = PdfShapedFont(document, shaper: shaper, fontBytes: bytes);
    });

    tearDown(() => shaper.dispose());

    Future<String> renderPage() async {
      final page = PdfPage(document, pageFormat: PdfPageFormat.a5);
      final canvas = page.getGraphics()..setFillColor(PdfColors.black);
      pdfFont.drawShapedRun(
        canvas,
        shaper.shape(_pointedWord, rtl: true, script: 'hebr'),
        x: 60,
        y: 300,
        fontSize: 48,
      );
      return String.fromCharCodes(await document.save());
    }

    test('הגופן מוטמע כ-CIDFontType0 עם FontFile3', () async {
      final text = await renderPage();

      expect(text, contains('/Type0'));
      expect(text, contains('/Identity-H'));
      expect(text, contains('/CIDFontType0'));
      expect(text, isNot(contains('/CIDFontType2')));
      expect(text, contains('/FontFile3'));
      expect(text, isNot(contains('/FontFile2')));
      // מפת CID→גליף היא של ה-CFF עצמו; המפתח הזה שייך ל-TrueType בלבד.
      expect(text, isNot(contains('/CIDToGIDMap')));
      expect(text, contains('/Subtype/OpenType'));
    });

    test('הבדיקה רצה על גופן CFF אמיתי', () {
      expect(bytes.sublist(0, 4), [0x4F, 0x54, 0x54, 0x4F]);
    });
  }, skip: skipReason);
}
