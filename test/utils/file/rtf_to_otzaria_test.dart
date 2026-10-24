import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/document_conversion_exceptions.dart';
import 'package:otzaria/utils/file/rtf_to_otzaria.dart';
import 'package:otzaria/text_book/utils/inline_notes_utils.dart';

/// RTF הוא זרם בייטים, לא טקסט Unicode — הבנייה כאן היא ברמת הבייט כדי
/// שבדיקות דפי-הקוד ישקפו את מה שקורה בקובץ אמיתי.
Uint8List _rtf(String body) => Uint8List.fromList(utf8.encode(body));

/// בונה מסמך שבו העברית מקודדת ב-`\'hh` (Windows-1255) — כפי ש-Word שומר,
/// ולכן הקובץ אינו UTF-8 תקין.
Uint8List _rtfCp1255(String asciiBody, List<int> cp1255Bytes, String tail) =>
    Uint8List.fromList([
      ...latin1.encode(asciiBody),
      ...cp1255Bytes,
      ...latin1.encode(tail),
    ]);

String _convert(String body, {bool embedImages = true}) =>
    rtfToText(_rtf(body), 'ספר', embedImages: embedImages);

/// עוטף גוף במסמך RTF מינימלי.
String _doc(String body, {String header = r'\rtf1\ansi'}) => '{$header$body}';

/// הזחת רשימה/טאב היא NBSP — רווח רגיל היה נבלע ברינדור.
const String _nbsp = ' ';

/// פקודת `\uN` של RTF. נבנית דרך עוזר כדי שקוד הבדיקה יכיל את *הפקודה*
/// ולא את התו עצמו — אחרת הבדיקה בודקת מסלול אחר לגמרי.
String _u(int codePoint) => '\\u$codePoint';

void main() {
  group('מבנה בסיסי', () {
    test('טקסט ASCII פשוט', () {
      expect(_convert(_doc(r'\par Hello')), '<h1>ספר</h1>\nHello');
    });

    test('הכותרת מוזרקת כ-h1 ועוברת escape', () {
      final out = rtfToText(_rtf(_doc('x')), 'א<b>&');
      expect(out.split('\n').first, '<h1>א&lt;b&gt;&amp;</h1>');
    });

    // הוראת שדה מסומנת ב-Word כיעד שאפשר להתעלם ממנו, אבל גם בלי הסימון
    // היא אינה תוכן — התוצאה בלבד נשמרת.
    test(r'\fldinst נבלע וה-fldrslt נשמר', () {
      final out = _convert(
        _doc(
          r'\pard עיין הערה '
          r'{\field{\fldinst NOTEREF _Ref403498473}{\fldrslt 10}}'
          r'. סוף\par',
        ),
      );

      expect(out, contains('10'));
      expect(out, isNot(contains('NOTEREF')));
      expect(out, isNot(contains('_Ref403498473')));
    });

    test(r'\par מפריד בין פסקאות', () {
      final out = _convert(_doc(r'ראשונה\par שנייה\par'));
      expect(out, '<h1>ספר</h1>\nראשונה\nשנייה');
    });

    test('פסקה ריקה אינה נוספת לפלט', () {
      final out = _convert(_doc(r'\par\par תוכן\par'));
      expect(out, '<h1>ספר</h1>\nתוכן');
    });

    test('מעברי שורה בקובץ עצמו אינם מסיימים פסקה', () {
      final out = _convert('{\\rtf1\\ansi א\nב\\par}');
      expect(out, '<h1>ספר</h1>\nאב');
    });

    test('קובץ שאינו פותח ב-rtf זורק חריגה מוקלדת', () {
      expect(
        () => rtfToText(Uint8List.fromList(utf8.encode('סתם טקסט')), 'ס'),
        throwsA(isA<CorruptedDocumentException>()),
      );
    });
  });

  group('קבוצות ויעדים', () {
    test('טבלת הגופנים אינה זולגת לטקסט', () {
      final out = _convert(
        _doc(r'{\fonttbl{\f0\fswiss Arial;}}תוכן אמיתי\par'),
      );
      expect(out, '<h1>ספר</h1>\nתוכן אמיתי');
      expect(out, isNot(contains('Arial')));
    });

    test('טבלת הצבעים וה-info אינן זולגות', () {
      final out = _convert(
        _doc(
          r'{\colortbl;\red0\green0\blue0;}'
          r'{\info{\author דוד}{\title כותרת פנימית}}'
          r'גוף\par',
        ),
      );
      expect(out, '<h1>ספר</h1>\nגוף');
      expect(out, isNot(contains('דוד')));
    });

    test(r'יעד \* לא מוכר נבלע במלואו', () {
      final out = _convert(
        _doc(r'{\*\unknowndest טקסט פנימי}נשאר\par'),
      );
      expect(out, '<h1>ספר</h1>\nנשאר');
      expect(out, isNot(contains('טקסט פנימי')));
    });

    test('עיצוב שנפתח בקבוצה אינו דולף החוצה', () {
      final out = _convert(_doc(r'{\b מודגש}רגיל\par'));
      expect(out, contains('<b>מודגש</b>רגיל'));
    });

    test('קינון עמוק אינו מאבד תוכן', () {
      final out = _convert(_doc(r'{{{{עמוק}}}}\par'));
      expect(out, contains('עמוק'));
    });

    test('סוגר מיותר אינו מפיל את ההמרה', () {
      final out = _convert(_doc(r'תקין}}}\par'));
      expect(out, contains('תקין'));
    });

    test('קבוצה שלא נסגרה — התוכן עדיין נפלט', () {
      final out = rtfToText(_rtf(r'{\rtf1\ansi {\b לא נסגר\par'), 'ס');
      expect(out, contains('לא נסגר'));
    });
  });

  group('עיצוב תווים', () {
    test('מודגש ונטוי', () {
      expect(_convert(_doc(r'\b חזק\b0\par')), contains('<b>חזק</b>'));
      expect(_convert(_doc(r'\i נטוי\i0\par')), contains('<i>נטוי</i>'));
    });

    test('קו תחתי וקו חוצה', () {
      expect(_convert(_doc(r'\ul קו\ulnone\par')), contains('<u>קו</u>'));
      expect(
        _convert(_doc(r'\strike חוצה\strike0\par')),
        contains('<s>חוצה</s>'),
      );
    });

    test('עילי ותחתי', () {
      expect(
        _convert(_doc(r'\super עילי\nosupersub\par')),
        contains('<sup>עילי</sup>'),
      );
      expect(
        _convert(_doc(r'\sub תחתי\nosupersub\par')),
        contains('<sub>תחתי</sub>'),
      );
    });

    test('שילוב עיצובים', () {
      final out = _convert(_doc(r'\b\i שניהם\par'));
      expect(out, contains('<b><i>שניהם</i></b>'));
    });

    test(r'\plain מאפס עיצוב תווים', () {
      final out = _convert(_doc(r'\b\i מעוצב\plain רגיל\par'));
      expect(out, contains('<b><i>מעוצב</i></b>'));
      expect(out, contains('רגיל'));
      expect(out, isNot(contains('<b><i>מעוצב</i></b><b>')));
    });

    test('פרמטר 0 מכבה, היעדר פרמטר מדליק', () {
      expect(_convert(_doc(r'\b0 רגיל\par')), isNot(contains('<b>')));
    });
  });

  group('Unicode ודפי קוד', () {
    test(r'\u מייצר תו יוניקוד ומדלג על תו הגיבוי', () {
      // א היא U+05D0 = 1488, ואחריה תו גיבוי יחיד שיש לדלג עליו.
      final out = _convert(_doc('${r'\uc1'}${_u(1488)} ?${r'\par'}'));
      expect(out, contains('א'));
      expect(out, isNot(contains('?')));
    });

    test(r'\ucN קובע כמה תווי גיבוי לדלג', () {
      final out = _convert(_doc('${r'\uc3'}${_u(1488)} ???${r'\par'}'));
      expect(out, contains('א'));
      expect(out, isNot(contains('?')));
    });

    test(r'\uc0 אינו מדלג על כלום', () {
      final out = _convert(_doc('${r'\uc0'}${_u(1488)} X${r'\par'}'));
      expect(out, contains('אX'));
    });

    test(r'\u שלילי מייצג נקודת קוד גבוהה', () {
      // -3891 + 65536 = 61645
      final out = _convert(_doc(r'\uc0\u-3891\par'));
      expect(out.codeUnits, contains(61645));
    });

    test(r"עברית ב-\'hh עם \ansicpg1255", () {
      final out = _convert(_doc(r"\ansicpg1255 \'f9\'ec\'e5\'ed\par"));
      expect(out, contains('שלום'));
    });

    test('בייטים גולמיים של Windows-1255 אינם מפילים את הפענוח', () {
      // קובץ שאינו UTF-8 תקין — הפענוח נופל ל-latin1 והתוכן שורד.
      final bytes = _rtfCp1255(
        r'{\rtf1\ansi\ansicpg1255 ',
        const [0xF9, 0xEC, 0xE5, 0xED],
        r'\par}',
      );
      final out = rtfToText(bytes, 'ס');
      expect(out.split('\n').length, 2);
      expect(out.split('\n')[1], isNotEmpty);
    });

    test(r"\'hh בלי הכרזת דף-קוד אינו מייצר ג'יבריש עברי", () {
      final out = _convert(_doc(r"\'e0\par"));
      // ברירת המחדל היא 1252, ולכן הבית אינו אל"ף.
      expect(out, isNot(contains('א')));
    });

    test('עברית UTF-8 גולמית בקובץ נקראת נכון', () {
      // יש כלים ששומרים עברית כבייטים גולמיים ולא ב-`\'hh`.
      final out = _convert(_doc(r'\ansicpg1255 שלום עולם\par'));
      expect(out, contains('שלום עולם'));
    });

    test('תווי בקרה נמלטים נפלטים כתוכן', () {
      final out = _convert(_doc(r'\{סוגר\}\\לוכסן\par'));
      expect(out, contains('{סוגר}\\לוכסן'));
    });
  });

  group('פסקה, שורה וטאב', () {
    test(r'\line מייצר <br> בתוך אותה פסקה', () {
      final out = _convert(_doc(r'א\line ב\par'));
      expect(out, '<h1>ספר</h1>\nא<br>ב');
    });

    test(r'\tab מייצר הזחה קשיחה', () {
      final out = _convert(_doc(r'\tab מוזח\par'));
      expect(out, contains('${_nbsp * 4}מוזח'));
    });

    test(r'\~ מייצר רווח קשיח', () {
      final out = _convert(_doc(r'א\~ב\par'));
      expect(
        out,
        contains(
          'א$_nbsp'
          'ב',
        ),
      );
    });

    test('יישור מפורש עוטף ב-div', () {
      expect(
        _convert(_doc(r'\qc ממורכז\par')),
        contains('<div style="text-align: center;">ממורכז</div>'),
      );
      expect(
        _convert(_doc(r'\qr לימין\par')),
        contains('text-align: right'),
      );
    });

    test(r'\pard מאפס יישור', () {
      final out = _convert(_doc(r'\qc ממורכז\par\pard רגיל\par'));
      expect(out, contains('<div style="text-align: center;">ממורכז</div>'));
      expect(out.split('\n').last, 'רגיל');
    });
  });

  group('כותרות', () {
    test(r'\outlinelevel ממופה ל-<h>', () {
      expect(
        _convert(_doc(r'\outlinelevel0 פרק\par')),
        contains('<h1>פרק</h1>'),
      );
      expect(
        _convert(_doc(r'\outlinelevel2 סעיף\par')),
        contains('<h3>סעיף</h3>'),
      );
    });

    test('רמה עמוקה נחתכת ל-h6', () {
      expect(
        _convert(_doc(r'\outlinelevel7 עמוק\par')),
        contains('<h6>עמוק</h6>'),
      );
    });

    test('outlinelevel מחוץ לטווח אינו כותרת', () {
      final out = _convert(_doc(r'\outlinelevel9 גוף\par'));
      expect(out, isNot(contains('<h2')));
      expect(out, contains('גוף'));
    });

    test('סגנון מ-stylesheet ששמו "heading 2" מזוהה ככותרת', () {
      final out = _convert(
        _doc(
          r'{\stylesheet{\s2 heading 2;}}'
          r'\s2 כותרת מסגנון\par',
        ),
      );
      expect(out, contains('<h2>כותרת מסגנון</h2>'));
    });

    test('סגנון עברי "כותרת 1" מזוהה', () {
      final out = _convert(
        _doc(
          r'{\stylesheet{\s1 כותרת 1;}}'
          r'\s1 בעברית\par',
        ),
      );
      expect(out, contains('<h1>בעברית</h1>'));
    });

    test('סגנון שאינו כותרת נשאר פסקה', () {
      final out = _convert(
        _doc(r'{\stylesheet{\s5 Body Text;}}\s5 גוף\par'),
      );
      expect(out, '<h1>ספר</h1>\nגוף');
    });
  });

  group('רשימות', () {
    test('תווית הפריט מ-listtext מופיעה לפני התוכן', () {
      final out = _convert(
        _doc(r'{\*\listtext 1.\tab}פריט ראשון\par'),
      );
      expect(out, contains('1. פריט ראשון'));
    });

    test('תבליט נשמר', () {
      final out = _convert(
        _doc('${r'{\*\pntext\uc0'}${_u(8226)} ${r'\tab}'}פריט${r'\par'}'),
      );
      expect(out, contains('פריט'));
      expect(out, contains('•'));
    });
  });

  group('הערות שוליים', () {
    test('נפלטות בתבנית המשותפת של אוצריא', () {
      final out = _convert(
        _doc(r'טקסט{\footnote גוף ההערה}\par'),
      );
      expect(
        out,
        contains(
          'טקסט<sup class="footnote-marker">1</sup>'
          '<i class="footnote">גוף ההערה</i>',
        ),
      );
    });

    test('המונה רץ על פני כמה הערות', () {
      final out = _convert(
        _doc(r'א{\footnote ראשונה}\par ב{\footnote שנייה}\par'),
      );
      expect(out, contains('<sup class="footnote-marker">1</sup>'));
      expect(out, contains('<sup class="footnote-marker">2</sup>'));
    });

    for (final marker in ['*', '40']) {
      test('חזקה בקבוצה קודמת נשמרת לצד סימן $marker', () {
        final out = _convert(
          _doc(
            ' x${r'{\super 2}{\super '}$marker'
            '${r'{\footnote \pard\plain {\super '}$marker} note}}'
            r'\par',
          ),
        );
        expect(
          out,
          '<h1>ספר</h1>\nx<sup>2</sup>'
          '<sup class="footnote-marker">$marker</sup>'
          '<i class="footnote">note</i>',
        );
        expect(stripInlineNotesForSearch(out), '<h1>ספר</h1>\nx<sup>2</sup> ');
      });
    }

    test('סימן מוסתר אינו מוחק חזקה גלויה קודמת', () {
      final out = _convert(
        _doc(
          r' x{\super 2}{\v\super *{\footnote \pard\super * note}}after\par',
        ),
      );
      expect(out, '<h1>ספר</h1>\nx<sup>2</sup>after');
    });

    test('חזקה וסימן באותה קבוצה מופרדים לפי ההד בגוף ההערה', () {
      final out = _convert(
        _doc(
          r' x{\b\super 2*{\footnote \pard\plain {\super *} note}}\par',
        ),
      );
      expect(
        out,
        '<h1>ספר</h1>\nx<b><sup>2</sup></b>'
        '<sup class="footnote-marker">*</sup><i class="footnote">note</i>',
      );
    });

    test('קבוצות עטיפה ושינוי עיצוב אינם מאבדים את גבול הסימן', () {
      final out = _convert(
        _doc(
          r' x{\super 2}{\super {\b 4}{{\footnote {\super 40} note}}0}\par',
        ),
      );
      expect(
        out,
        '<h1>ספר</h1>\nx<sup>2</sup>'
        '<sup class="footnote-marker">40</sup><i class="footnote">note</i>',
      );
    });

    for (final tail in [
      r'}0 years\par',
      r'}{\super 0 years}\par',
      r'}\par 0 years\par',
      r'\par 0 years}\par',
      r'\nosupersub 0 years}\par',
    ]) {
      test('המשך סימן אינו זולג מחוץ להקשר שלו: $tail', () {
        final out = _convert(
          _doc(
            r' x{\super 4{\footnote {\super 40} note}' + tail,
          ),
        );
        expect(out, contains('0 years'));
        expect(out, contains('<sup class="footnote-marker">40</sup>'));
      });
    }

    test('סימן של הערה ריקה או ללא הד תואם נשאר תוכן', () {
      expect(
        _convert(_doc(r' x{\super 2{\footnote }}\par')),
        '<h1>ספר</h1>\nx<sup>2</sup>',
      );
      expect(
        _convert(_doc(r' x{\super 2{\footnote note}}\par')),
        '<h1>ספר</h1>\nx<sup>2</sup>'
        '<sup class="footnote-marker">1</sup><i class="footnote">note</i>',
      );
    });

    test('קבוצה ללא סימן אינה מאמצת חזקה מקבוצה קודמת גם כשההד זהה', () {
      final out = _convert(
        _doc(
          r' x{\super 2}{\super {\footnote {\super 2} note}}\par',
        ),
      );
      expect(
        out,
        '<h1>ספר</h1>\nx<sup>2</sup>'
        '<sup class="footnote-marker">1</sup><i class="footnote"><sup>2</sup> note</i>',
      );
    });

    test('מועמד שאינו תואם להד נשמר בעיצובו', () {
      final out = _convert(
        _doc(
          r' x{\b\super 2{\footnote {\super *} note}}\par',
        ),
      );
      expect(
        out,
        '<h1>ספר</h1>\nx<b><sup>2</sup></b>'
        '<sup class="footnote-marker">1</sup><i class="footnote"><sup>*</sup> note</i>',
      );
    });

    test('קבוצת הערה קטועה ללא גוף משמרת את המועמד', () {
      expect(
        _convert(r'{\rtf1\ansi x{\super 2{\footnote '),
        '<h1>ספר</h1>\nx<sup>2</sup>',
      );
    });

    test('הערה ריקה אינה מייצרת סימון', () {
      final out = _convert(_doc(r'טקסט{\footnote }\par'));
      expect(out, '<h1>ספר</h1>\nטקסט');
    });

    // בר-אילן מפצל סימן דו-ספרתי סביב ההערה וחוזר עליו בראש גופה.
    test('סימן מילולי אינו מוכפל וגוף ההערה אינו עילי (issue #2685)', () {
      final out = _convert(
        _doc(
          r'{א}{\super 1{\footnote \rtlpar {\super 1} {{\b ראשונה}} רגיל}}'
          r'{ ב}{\super 4{\footnote \rtlpar {\super 40} {{\b ארבעים}}}0}'
          r'{ ג x}{\super 2}{\super\chftn{\footnote {\super\chftn}וורד}}'
          r'{ ד}{\b\super *{\footnote \pard\plain {\super *} כוכבית}}\par',
        ),
      );
      expect(
        out,
        '<h1>ספר</h1>\n'
        'א<sup class="footnote-marker">1</sup>'
        '<i class="footnote"><b>ראשונה</b> רגיל</i>'
        ' ב<sup class="footnote-marker">40</sup>'
        '<i class="footnote"><b>ארבעים</b></i>'
        ' ג x<sup>2</sup><sup class="footnote-marker">1</sup>'
        '<i class="footnote">וורד</i>'
        ' ד<sup class="footnote-marker">*</sup><i class="footnote">כוכבית</i>',
      );
    });
  });

  group('טבלאות', () {
    test('שורה עם תאים מומרת ל-<table>', () {
      final out = _convert(
        _doc(r'\trowd א\cell ב\cell\row'),
      );
      expect(out, contains('<table'));
      expect(out, contains('א'));
      expect(out, contains('ב'));
      expect('<td'.allMatches(out).length, 2);
    });

    test('שתי שורות מרכיבות טבלה אחת ולא שתיים', () {
      // רגרסיה: `\row` סגר טבלה במקום שורה, וכל שורה יצאה כטבלה נפרדת.
      final out = _convert(
        _doc(r'\trowd א\cell\row\trowd ב\cell\row\pard אחרי\par'),
      );
      expect('<table'.allMatches(out).length, 1);
      expect('<tr>'.allMatches(out).length, 2);
      expect(out, contains('א'));
      expect(out, contains('ב'));
    });

    test('טקסט אחרי הטבלה אינו נבלע', () {
      final out = _convert(
        _doc(r'\trowd תא\cell\row\pard אחרי\par'),
      );
      expect(out, contains('תא'));
      expect(out.split('\n').last, 'אחרי');
    });
  });

  group('תמונות', () {
    // PNG 1x1: הבייטים הראשונים מספיקים לזיהוי; ההמרה היא hex→base64.
    const pngHex = '89504e470d0a1a0a';

    test('תמונת PNG מוטמעת כ-data URI', () {
      final out = _convert(_doc('{\\pict\\pngblip $pngHex}\\par'));
      expect(out, contains('<img src="data:image/png;base64,'));
      expect(out, isNot(contains('http')));
    });

    test('embedImages=false משאיר תג ריק', () {
      final out = _convert(
        _doc('{\\pict\\pngblip $pngHex}\\par'),
        embedImages: false,
      );
      expect(out, contains('<img src=""'));
      expect(out, isNot(contains('base64')));
    });

    test('מספר השורות זהה בשני הווריאנטים', () {
      final body = _doc('לפני\\par{\\pict\\pngblip $pngHex}\\par');
      final full = _convert(body);
      final lean = _convert(body, embedImages: false);
      expect(lean.split('\n').length, full.split('\n').length);
    });

    test('pict וקטורי נפלט כתג ריק ולא כ-data URI', () {
      // EMF/WMF הם תמונה שאין לה data URI שהקורא מרנדר. השמטת התג הייתה
      // מזיזה את מספרי השורות, ועמם עוגני ההערות האישיות ותוכן העניינים.
      final out = _convert(_doc('{\\pict\\emfblip $pngHex}\\par'));

      expect(out, contains('<img src=""'));
      expect(out, isNot(contains('base64')));
    });

    test('pict בלי שום סוג אינו נפלט כתמונה', () {
      final out = _convert(_doc('{\\pict $pngHex}\\par'));
      expect(out, isNot(contains('<img')));
    });
  });

  group('עמידות (§52)', () {
    test('פקודה לא מוכרת נבלעת והטקסט סביבה נשמר', () {
      final out = _convert(_doc(r'לפני\madeupcommand42 אחרי\par'));
      expect(out, contains('לפני'));
      expect(out, contains('אחרי'));
      expect(out, isNot(contains('madeupcommand')));
    });

    test('פקודה בסוף הקובץ בלי פרמטר אינה מפילה', () {
      final out = rtfToText(_rtf(r'{\rtf1\ansi טקסט\b'), 'ס');
      expect(out, contains('טקסט'));
    });

    test(r"\'hh קטוע אינו מפיל", () {
      final out = rtfToText(_rtf(r"{\rtf1\ansi טקסט\'f"), 'ס');
      expect(out, contains('טקסט'));
    });

    test('מסמך ריק מחזיר כותרת בלבד', () {
      expect(_convert(_doc('')), '<h1>ספר</h1>');
    });

    test('אין הסרה נאיבית: לוכסן בתוך טקסט אינו מוחק את המשך השורה', () {
      final out = _convert(_doc(r'לפני\\אחרי\par'));
      expect(out, contains('לפני\\אחרי'));
    });

    test('המרה חוזרת דטרמיניסטית', () {
      final bytes = _rtf(_doc(r'\b כותרת\b0\par גוף\par'));
      expect(rtfToText(bytes, 'ס'), rtfToText(bytes, 'ס'));
    });

    test('מסמך גדול מומר בזמן סביר', () {
      final body = StringBuffer(r'{\rtf1\ansi');
      for (var i = 0; i < 5000; i++) {
        body.write('שורה $i\\par ');
      }
      body.write('}');
      final out = rtfToText(_rtf(body.toString()), 'ס');
      expect(out.split('\n').length, 5001);
    });
  });

  group('תווים מיוחדים', () {
    test('קווים מפרידים וגרשיים אינם נמחקים', () {
      final out = _convert(_doc(r'א\emdash ב\endash ג\par'));
      expect(out, contains('א—ב–ג'));
    });

    test('מרכאות טיפוגרפיות ותבליט', () {
      final out = _convert(
        _doc(r'\lquote a\rquote \ldblquote b\rdblquote \bullet\par'),
      );
      expect(out, contains('‘a’“b”•'));
    });

    test('מקף בלתי-שביר נשמר; מקף אופציונלי אינו מוצג', () {
      expect(_convert(_doc(r'א\_ב\par')), contains('א‑ב'));
      expect(_convert(_doc(r'א\-ב\par')), contains('אב'));
    });

    test('פקודה לא מוכרת עדיין מדולגת בלי לפגוע בטקסט', () {
      expect(_convert(_doc(r'לפני\nosuchword אחרי\par')), contains('לפניאחרי'));
    });
  });

  group('טקסט מוסתר', () {
    test(r'\v מסתיר את הטקסט שאחריו', () {
      final out = _convert(_doc(r'גלוי{\v מוסתר}עוד\par'));
      expect(out, contains('גלוי'));
      expect(out, contains('עוד'));
      expect(out, isNot(contains('מוסתר')));
    });

    test(r'\v0 מבטל את ההסתרה', () {
      expect(_convert(_doc(r'{\v\v0 חוזר}\par')), contains('חוזר'));
    });
  });

  group('וריאנטי עיצוב תווים', () {
    test('קו תחתי — כל סוג מקבל את ה-CSS של חוזה ה-markup', () {
      expect(_convert(_doc(r'{\uldb א}\par')), contains('underline double'));
      expect(_convert(_doc(r'{\uld א}\par')), contains('underline dotted'));
      expect(_convert(_doc(r'{\uldash א}\par')), contains('underline dashed'));
      expect(_convert(_doc(r'{\ulwave א}\par')), contains('underline wavy'));
      expect(
        _convert(_doc(r'{\ulth א}\par')),
        contains('text-decoration-thickness: 200%'),
      );
    });

    test('קו תחתי פשוט נשאר <u> — תג קצר שניתן למזג', () {
      expect(_convert(_doc(r'{\ul א}\par')), contains('<u>א</u>'));
      expect(_convert(_doc(r'{\ulw א}\par')), contains('<u>א</u>'));
    });

    test('קו חוצה כפול נבדל מיחיד', () {
      expect(_convert(_doc(r'{\strike א}\par')), contains('<s>א</s>'));
      expect(
        _convert(_doc(r'{\striked1 א}\par')),
        contains('line-through double'),
      );
    });

    test('צבע טקסט ומרקר מטבלת הצבעים', () {
      const table = r'{\colortbl;\red192\green0\blue0;\red255\green255\blue0;}';
      expect(
        _convert(_doc('$table{\\cf1 אדום}\\par')),
        contains('<span style="color:#c00000">אדום</span>'),
      );
      expect(
        _convert(_doc('$table{\\highlight2 מסומן}\\par')),
        contains('<span style="background-color:#ffff00">מסומן</span>'),
      );
    });

    test('cf0 ושחור אינם נפלטים — שחור שובר מצב כהה', () {
      const table = r'{\colortbl;\red0\green0\blue0;}';
      expect(
        _convert(_doc('$table{\\cf1 שחור}\\par')),
        isNot(contains('span')),
      );
      expect(
        _convert(_doc('$table{\\cf0 רגיל}\\par')),
        isNot(contains('span')),
      );
    });

    test('טבלת הצבעים עצמה אינה זולגת לטקסט', () {
      final out = _convert(_doc(r'{\colortbl;\red1\green2\blue3;}גוף\par'));
      expect(out, '<h1>ספר</h1>\nגוף');
    });
  });

  group('יישור מול כיוון הפסקה', () {
    test(r'\rtlpar\qr הוא הכיוון הטבעי — ואינו נעטף ב-div', () {
      // Word כותב את היישור במפורש כמעט בכל פסקה; עטיפת כולן הייתה מבטלת
      // את היישור הדו-צדדי של הקורא לאורך ספר שלם.
      expect(
        _convert(_doc(r'\pard\rtlpar\qr טקסט\par')),
        isNot(contains('<div')),
      );
    });

    test(r'\ltrpar\ql הוא הכיוון הטבעי אף הוא', () {
      expect(
        _convert(_doc(r'\pard\ltrpar\ql טקסט\par')),
        isNot(contains('<div')),
      );
    });

    test('בפסקה RTL נשמר מרכוז בלבד', () {
      // Word כותב `\ql`/`\qr` כמעט בכל פסקה, ומפיקי RTF חלוקים אם הם פיזיים
      // או לוגיים שם. הכרעה שגויה מיישרת ספר עברי שלם לצד ההפוך.
      expect(
        _convert(_doc(r'\pard\rtlpar\ql טקסט\par')),
        isNot(contains('<div')),
      );
      expect(
        _convert(_doc(r'\pard\rtlpar\qr טקסט\par')),
        isNot(contains('<div')),
      );
    });

    test('בפסקה LTR יישור לימין כן נכתב', () {
      expect(
        _convert(_doc(r'\pard\ltrpar\qr טקסט\par')),
        contains('<div style="text-align: right;">'),
      );
    });

    test('מרכוז נשמר בשני הכיוונים', () {
      expect(
        _convert(_doc(r'\pard\rtlpar\qc טקסט\par')),
        contains('<div style="text-align: center;">'),
      );
      expect(
        _convert(_doc(r'\pard\ltrpar\qc טקסט\par')),
        contains('<div style="text-align: center;">'),
      );
    });
  });

  group('מאפייני טבלה', () {
    test(r'\trhdr הופך את השורה ל-<th>', () {
      final out = _convert(
        _doc(r'\trowd\trhdr\cellx100 כותרת\cell\row\pard סוף\par'),
      );
      expect(out, contains('<th'));
      expect(out, isNot(contains('<td')));
    });

    test(r'\clcbpat ו-\clvertalc נכנסים ל-style של התא', () {
      final out = _convert(
        _doc(
          r'{\colortbl;\red221\green235\blue247;}'
          r'\trowd\clcbpat1\clvertalc\cellx100 תא\cell\row\pard סוף\par',
        ),
      );
      expect(out, contains('background-color: #ddebf7'));
      expect(out, contains('vertical-align: middle'));
    });

    test(r'\clmrg מתמזג לתא הקודם כ-colspan', () {
      final out = _convert(
        _doc(
          r'\trowd\clmgf\cellx100\clmrg\cellx200 א\cell ב\cell\row\pard ס\par',
        ),
      );
      expect(out, contains('colspan="2"'));
    });

    test(r'\clvmrg מתמזג לשורה שמעליה כ-rowspan', () {
      final out = _convert(
        _doc(
          r'\trowd\clvmgf\cellx100 א\cell\row'
          r'\trowd\clvmrg\cellx100 ב\cell\row\pard ס\par',
        ),
      );
      expect(out, contains('rowspan="2"'));
    });

    test(r'\rtlrow מסמן את הטבלה כ-RTL', () {
      final out = _convert(
        _doc(r'\trowd\rtlrow\cellx100 תא\cell\row\pard סוף\par'),
      );
      expect(out, contains('<table dir="rtl"'));
    });
  });

  group('תיבת טקסט', () {
    test(r'\shptxt נפלט כמסגרת של חוזה ה-markup', () {
      final out = _convert(
        _doc(r'{\*\shpinst{\sp{\sn x}}{\shptxt בתיבה\par}}\par'),
      );
      expect(out, contains('border: 1px solid #999; padding: 8px'));
      expect(out, contains('בתיבה'));
    });

    test('טקסט התיבה אינו נבלע עם שאר מאפייני האובייקט הצף', () {
      final out = _convert(
        _doc(r'{\*\shpinst{\sp{\sn fillColor}{\sv 123}}{\shptxt תוכן}}\par'),
      );
      expect(out, contains('תוכן'));
      expect(out, isNot(contains('fillColor')));
      expect(out, isNot(contains('123')));
    });

    test('קבוצות מקוננות בתיבה אינן מייצרות מסגרת לכל מילה', () {
      // Word עוטף כל שורה בתיבה בקבוצה משלה; פליטה בכל `}` ייצרה עשר
      // מסגרות נפרדות במקום אחת — עמוד השער נראה כטבלת שורות.
      final out = _convert(
        _doc(
          r'{\*\shpinst{\shptxt {\b שורה א}\par {\b שורה ב}\par}}\par',
        ),
      );
      expect(
        'border: 1px solid #999; padding: 8px'.allMatches(out).length,
        1,
      );
      expect(out, contains('שורה א'));
      expect(out, contains('שורה ב'));
    });

    test(r'\sn fLine 0 — תיבה בלי גבול אינה מציירת מסגרת', () {
      final out = _convert(
        _doc(r'{\*\shpinst{\sp{\sn fLine}{\sv 0}}{\shptxt בלי מסגרת}}\par'),
      );
      expect(out, contains('בלי מסגרת'));
      expect(out, isNot(contains('border: 1px solid #999; padding: 8px')));
    });

    test(r'\sn fLine 1 — תיבה עם גבול כן מציירת', () {
      final out = _convert(
        _doc(r'{\*\shpinst{\sp{\sn fLine}{\sv 1}}{\shptxt עם מסגרת}}\par'),
      );
      expect(out, contains('border: 1px solid #999; padding: 8px'));
    });

    test('ערך מאפיין כבד (pib) אינו נצבר ואינו זולג לטקסט', () {
      final out = _convert(
        _doc(r'{\*\shpinst{\sp{\sn pib}{\sv AAAAFFFF}}{\shptxt תוכן}}\par'),
      );
      expect(out, contains('תוכן'));
      expect(out, isNot(contains('AAAAFFFF')));
    });
  });

  group('קבוצות מקוננות אינן מפצלות יחידות', () {
    test('הערת שוליים בקבוצות מקוננות נפלטת פעם אחת', () {
      final out = _convert(_doc(r'גוף{\footnote {\i א}{\b ב}}\par'));
      expect('footnote-marker'.allMatches(out).length, 1);
      expect(out, contains('<i>א</i><b>ב</b>'));
    });

    test('תמונה עם קבוצה מקוננת נפלטת פעם אחת', () {
      final out = _convert(
        _doc(r'{\*\shppict{\pict\pngblip{\*\blipuid 00}89504e47}}\par'),
      );
      expect('<img'.allMatches(out).length, 1);
    });
  });

  group('מיזוג runs', () {
    test('מילים בקבוצות נפרדות באותו עיצוב ממוזגות לתג אחד', () {
      // Word עוטף כל מילה בקבוצה משלה; בלי מיזוג כל מילה קיבלה `<b>` נפרד.
      final out = _convert(_doc(r'{\b {א}{ }{ב}}\par'));
      expect(out, contains('<b>א ב</b>'));
    });

    test('שינוי עיצוב בין קבוצות עדיין מפצל', () {
      final out = _convert(_doc(r'{\b א}{\i ב}\par'));
      expect(out, contains('<b>א</b><i>ב</i>'));
    });
  });
}
