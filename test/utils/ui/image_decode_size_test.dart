import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/splash_screen.dart';
import 'package:otzaria/utils/ui/image_decode_size.dart';

/// גודל הקובץ שמעליו נכס נחשב "כבד" ומחייב הקטנה בפענוח.
const _heavyAssetBytes = 100 * 1024;

/// עותק מוקטן מראש של הלוגו, לתצוגה עד 128 לוגי ב-DPR 2.
const _appLogoAsset = 'assets/icon/iconnew_256.png';

void main() {
  group('imageDecodeSize', () {
    testWidgets('מכפיל את הגודל הלוגי ב-devicePixelRatio', (tester) async {
      late int decoded;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3.0),
          child: Builder(
            builder: (context) {
              decoded = imageDecodeSize(context, 50);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(decoded, 150);
    });

    testWidgets('פענוח cover שומר די פיקסלים גם בצלע הקצרה', (tester) async {
      late ResizeImage provider;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: Builder(
            builder: (context) {
              provider =
                  coverResizeAsset(
                        context,
                        'assets/logos/hatzala_leachim.png',
                        logicalSize: 50,
                        maxSourceAspectRatio: 2,
                      )
                      as ResizeImage;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(provider.width, 300);
      expect(provider.height, 300);
      expect(provider.policy, ResizeImagePolicy.fit);
    });

    testWidgets('מעגל כלפי מעלה כדי לא לפענח מתחת לגודל התצוגה', (
      tester,
    ) async {
      late int decoded;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 1.5),
          child: Builder(
            builder: (context) {
              decoded = imageDecodeSize(context, 17);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(decoded, 26); // 25.5 → 26
    });
  });

  group('מסך הפתיחה', () {
    testWidgets('מפענח את הסמל לפי גודל התצוגה ולא ברזולוציה המלאה', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(devicePixelRatio: 2.0),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SplashIcon(),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, _appLogoAsset);
    });

    test('לוגו האפליקציה לא מוקטן בפענוח (#1747)', () {
      // הקטנה בפענוח מ-1024 היא bilinear בלי mipmaps — הלוגו יוצא מפוקסל
      final offenders = <String>[];
      for (final file in _dartFiles(Directory('lib'))) {
        final src = file.readAsStringSync();
        for (final call in _callSites(src, 'Image.asset(')) {
          final asset = _firstStringLiteral(call.body);
          if (asset == 'assets/icon/iconnew.png' ||
              (asset == _appLogoAsset && call.body.contains('cache'))) {
            offenders.add(file.path);
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'השתמש ב-$_appLogoAsset בלי cacheWidth',
      );
      expect(File(_appLogoAsset).lengthSync(), lessThan(_heavyAssetBytes));
    });
  });

  group('רגרסיה: נכסים כבדים', () {
    test('כל Image.asset על נכס כבד מגדיר cacheWidth', () {
      final offenders = <String>[];
      var heavyCallsScanned = 0;

      for (final file in _dartFiles(Directory('lib'))) {
        final src = file.readAsStringSync();
        for (final call in _callSites(src, 'Image.asset(')) {
          final asset = _firstStringLiteral(call.body);
          if (asset == null || !_isHeavyAsset(asset)) continue;
          heavyCallsScanned++;
          if (call.body.contains('cacheWidth') ||
              call.body.contains('cacheHeight')) {
            continue;
          }
          offenders.add('${file.path}: $asset');
        }
      }

      // בלי זה טסט שלא מוצא דבר (נתיב שגוי, פרסור שבור) עובר בטעות
      expect(
        heavyCallsScanned,
        greaterThan(0),
        reason: 'הסורק לא מצא אף Image.asset על נכס כבד — כנראה שבור',
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'נכס מעל ${_heavyAssetBytes ~/ 1024}KB נטען ברזולוציה המלאה שלו.\n'
            'הוסף cacheWidth: imageDecodeSize(context, <גודל התצוגה>).\n'
            'המקומות: ${offenders.join(', ')}',
      );
    });

    test('לוגואי הארגונים בפופאפ נטענים דרך ResizeImage', () {
      final src = File(
        'lib/widgets/dialogs/ad_popup_dialog.dart',
      ).readAsStringSync();

      // הנתיב מגיע ממשתנה, כך שהסריקה הסטטית שלמעלה לא רואה אותו
      expect(
        RegExp(r"Image\.asset\(\s*widget\.org\['logo'\]").hasMatch(src),
        isFalse,
        reason: 'לוגו של 2480×3508 בריבוע 50 מפוענח ל-35MB בלי הקטנה',
      );
      expect(src.contains('coverResizeAsset('), isTrue);
    });
  });
}

/// כל קבצי הדארט תחת [dir], רקורסיבית.
Iterable<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// האם הנכס [path] גדול מהסף שמעליו חובה להקטין בפענוח.
bool _isHeavyAsset(String path) {
  if (!path.startsWith('assets/')) return false;
  final file = File(path);
  return file.existsSync() && file.lengthSync() > _heavyAssetBytes;
}

class _CallSite {
  final String body;
  const _CallSite(this.body);
}

/// כל הקריאות ל-[opener] ב-[src], כשהגוף הוא הטקסט עד הסוגר התואם.
List<_CallSite> _callSites(String src, String opener) {
  final sites = <_CallSite>[];
  var from = 0;
  while (true) {
    final start = src.indexOf(opener, from);
    if (start < 0) break;
    final open = start + opener.length - 1;
    final close = _matchingParen(src, open);
    if (close < 0) break;
    sites.add(_CallSite(src.substring(open + 1, close)));
    from = close;
  }
  return sites;
}

/// מיקום הסוגר הסוגר התואם ל-'(' שבמיקום [open], או -1 אם אין.
int _matchingParen(String src, int open) {
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    final c = src[i];
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// המחרוזת הראשונה בגרשיים בודדים בתוך [body], או null אם אין.
String? _firstStringLiteral(String body) {
  final match = RegExp(r"'([^']*)'").firstMatch(body);
  return match?.group(1);
}
