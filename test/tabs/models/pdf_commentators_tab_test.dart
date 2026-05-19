import 'package:flutter/widgets.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/tabs/models/pdf_commentators_tab.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';

import '../../helpers/memory_settings_cache.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  group('PdfCommentatorsTab', () {
    test('title נגזר מה-sourceTab', () {
      final sourceTab = PdfBookTab(
        book: PdfBook(title: 'PDF בדיקה', path: '/tmp/book.pdf'),
        pageNumber: 5,
      );
      addTearDown(sourceTab.dispose);

      final tab = PdfCommentatorsTab(sourceTab: sourceTab);

      expect(tab.title, 'מפרשים | PDF בדיקה');
      expect(tab.sourceTab, same(sourceTab));
    });

    test('toJson שומר את הסוג וה-pinned בלבד', () {
      final sourceTab = PdfBookTab(
        book: PdfBook(title: 'PDF בדיקה', path: '/tmp/book.pdf'),
        pageNumber: 5,
      );
      addTearDown(sourceTab.dispose);

      final tab = PdfCommentatorsTab(sourceTab: sourceTab)..isPinned = true;
      final json = tab.toJson();

      expect(json, {
        'title': 'מפרשים | PDF בדיקה',
        'type': 'PdfCommentatorsTab',
        'isPinned': true,
      });
    });
  });
}
