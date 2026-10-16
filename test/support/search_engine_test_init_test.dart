import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'search_engine_test_init.dart';

void main() {
  test('הטסטים טוענים עותק, ולא את פלט הבנייה שהבנייה הבאה דורסת', () async {
    final loaded = await tryInitSearchEngine();
    if (!loaded) {
      markTestSkipped(searchEngineSkipReason);
      return;
    }

    final copies = Directory('build/test_engine')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.uri.pathSegments.last.startsWith(
            RegExp(r'(?:lib)?search_engine_'),
          ),
        )
        .toList();

    expect(
      copies,
      hasLength(1),
      reason: 'עותק של בנייה קודמת לא נוקה מ-build/test_engine',
    );
    expect(copies.single.lengthSync(), greaterThan(0));
  });

  test('אתחול חוזר אינו מייצר עותק נוסף', () async {
    final dir = Directory('build/test_engine');
    if (!await tryInitSearchEngine() || !dir.existsSync()) {
      markTestSkipped(searchEngineSkipReason);
      return;
    }
    final before = dir.listSync().length;
    await tryInitSearchEngine();
    expect(dir.listSync(), hasLength(before));
  });

  test(
    'ספרייה שנמצאה ולא נטענה — סיבת הדילוג מציגה את השגיאה (issue #1491)',
    () async {
      final candidates = searchEngineLibraryCandidates();
      if (candidates.isEmpty || await tryInitSearchEngine()) {
        markTestSkipped('נדרשת ספרייה שקיימת אך אינה נטענת');
        return;
      }

      expect(searchEngineSkipReason, contains('נמצאה אך לא נטענה'));
    },
  );

  test('בניית אפליקציית macOS נסרקת כמו בווינדוס ובלינוקס (issue #1493)', () {
    final products = Directory('build/macos/Build/Products/Debug');
    final frameworks = products.existsSync()
        ? [
            for (final app in products.listSync().whereType<Directory>())
              if (app.path.endsWith('.app'))
                '${app.path}/Contents/Frameworks/search_engine.framework/'
                    'search_engine',
          ].where((path) => File(path).existsSync()).toList()
        : const <String>[];
    if (frameworks.isEmpty) {
      markTestSkipped('אין בניית macOS של האפליקציה');
      return;
    }

    expect(searchEngineLibraryCandidates(), contains(frameworks.first));
  });
}
