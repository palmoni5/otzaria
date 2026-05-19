import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/tabs/models/commentators_tab.dart';
import 'package:otzaria/tabs/models/pdf_commentators_tab.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/tabs/tabs_repository.dart';

import '../helpers/memory_settings_cache.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late TabsRepository repository;

  setUpAll(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tabs_repository_test');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>('tabs');
    repository = TabsRepository();
  });

  tearDown(() async {
    await Hive.box('tabs').clear();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TabsRepository', () {
    test('saveTabs/loadTabs משחזרים CommentatorsTab', () async {
      final sourceTab = TextBookTab(
        book: TextBook(title: 'ספר בדיקה'),
        index: 4,
      );
      addTearDown(sourceTab.dispose);

      final commentatorsTab = CommentatorsTab(sourceTab: sourceTab);
      addTearDown(commentatorsTab.dispose);

      await repository.saveTabs([commentatorsTab], 0);

      final loaded = repository.loadTabs();
      addTearDown(() {
        for (final tab in loaded) {
          tab.dispose();
        }
      });

      expect(loaded, hasLength(1));
      expect(loaded.single, isA<CommentatorsTab>());
      expect((loaded.single as CommentatorsTab).sourceTab.book.title, 'ספר בדיקה');
    });

    test('PdfCommentatorsTab לא נשמר לדיסק כלל', () async {
      final pdfSource = PdfBookTab(
        book: PdfBook(title: 'PDF בדיקה', path: '/tmp/book.pdf'),
        pageNumber: 2,
      );
      addTearDown(pdfSource.dispose);

      final pdfCommentatorsTab = PdfCommentatorsTab(sourceTab: pdfSource);
      await repository.saveTabs([pdfCommentatorsTab], 0);

      final loaded = repository.loadTabs();
      expect(loaded, isEmpty);
      expect(repository.loadCurrentTabIndex(), 0);
    });

    test('loadCurrentTabIndex משחזר את האינדקס שנשמר', () async {
      final firstTab = TextBookTab(
        book: TextBook(title: 'ספר בדיקה'),
        index: 1,
      );
      final secondTab = TextBookTab(
        book: TextBook(title: 'ספר בדיקה 2'),
        index: 2,
      );
      final thirdTab = TextBookTab(
        book: TextBook(title: 'ספר בדיקה 3'),
        index: 3,
      );
      final fourthTab = TextBookTab(
        book: TextBook(title: 'ספר בדיקה 4'),
        index: 4,
      );
      addTearDown(firstTab.dispose);
      addTearDown(secondTab.dispose);
      addTearDown(thirdTab.dispose);
      addTearDown(fourthTab.dispose);

      await repository.saveTabs([firstTab, secondTab, thirdTab, fourthTab], 3);

      expect(repository.loadCurrentTabIndex(), 3);
    });

    test('אם הטאב הנוכחי אינו נשמר, האינדקס נשמר לטאב השחזורי הקרוב', () async {
      final textTab = TextBookTab(
        book: TextBook(title: 'ספר בדיקה'),
        index: 1,
      );
      final pdfSource = PdfBookTab(
        book: PdfBook(title: 'PDF בדיקה', path: '/tmp/book.pdf'),
        pageNumber: 2,
      );
      addTearDown(textTab.dispose);
      addTearDown(pdfSource.dispose);

      final pdfCommentatorsTab = PdfCommentatorsTab(sourceTab: pdfSource);
      await repository.saveTabs([textTab, pdfCommentatorsTab], 1);

      final loaded = repository.loadTabs();
      addTearDown(() {
        for (final tab in loaded) {
          tab.dispose();
        }
      });

      expect(loaded, hasLength(1));
      expect(loaded.single, isA<TextBookTab>());
      expect(repository.loadCurrentTabIndex(), 0);
    });
  });
}
