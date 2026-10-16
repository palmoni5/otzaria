import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/data/data_providers/book_composite_key.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:otzaria/data/data_providers/library_provider_manager.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/view/alt_toc_sidebar_view.dart';
import 'package:otzaria/text_book/view/reading_viewport/line_scroll_controller.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../../helpers/seforim_fixture_db.dart';
import '../../test_helpers/memory_cache_provider.dart';

class _TestTextBookBloc extends Bloc<TextBookEvent, TextBookState>
    implements TextBookBloc {
  _TestTextBookBloc(super.initialState) {
    on<TextBookEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _linklessParent = 'כותרת בלי שורה';
const _linklessChild = 'בן ראשון';
const _linkedParent = 'פרשת בראשית';
const _linkedChild = 'בן של כותרת עם שורה';

/// #2166: לחיצה על שורת כותרת בלי קישור משלה פותחת וסוגרת אותה.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final provider = DatabaseLibraryProvider.instance;
  final previousDataRoot = AppPaths.cachedDataRootPath;
  late Directory tempDir;

  setUp(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
    tempDir = await Directory.systemTemp.createTemp('otzaria_alt_linkless');
    final libraryPath = p.join(tempDir.path, 'library');
    Directory(libraryPath).createSync();
    final dbPath = p.join(libraryPath, DatabaseConstants.databaseFileName);
    File(
      SeforimFixtureDb.create(
        Directory(libraryPath),
        SeforimFixtureVariant.full,
      ),
    ).renameSync(dbPath);
    // במסד: "פרשת בראשית" (1) עם שורה 1. נוספים בן שלה, ואב בלי שורה עם בן.
    final db = sqlite3.sqlite3.open(dbPath);
    db.execute(
      'INSERT INTO tocText VALUES (3, ?), (4, ?), (5, ?)',
      [_linklessParent, _linklessChild, _linkedChild],
    );
    db.execute('UPDATE alt_toc_entry SET hasChildren = 1 WHERE id = 1');
    db.execute(
      'INSERT INTO alt_toc_entry (id, structureId, parentId, textId, level, '
      'lineId, hasChildren) VALUES '
      '(2, 1, 1, 5, 2, 2, 0), (3, 1, NULL, 3, 1, NULL, 1), '
      '(4, 1, 3, 4, 2, 3, 0)',
    );
    db.execute('INSERT INTO line_alt_toc VALUES (2, 1, 2), (3, 1, 4)');
    db.close();

    AppPaths.debugOverrideDataRootPath(p.join(tempDir.path, 'data_root'));
    await Settings.setValue<String>(
      SettingsRepository.keyLibraryPath,
      libraryPath,
    );
    await Settings.setValue<String>(
      SettingsRepository.keyLibraryFolderName,
      '',
    );
    await Settings.setValue<String>(SettingsRepository.keyDbEffectivePath, '');
    await provider.sqliteProvider.dispose();
    provider.clearCache();
    LibraryProviderManager.instance.resetForTesting();
    await provider.initialize();
  });

  tearDown(() async {
    LibraryProviderManager.instance.resetForTesting();
    provider.clearCache();
    await provider.sqliteProvider.dispose();
    AppPaths.debugOverrideDataRootPath(previousDataRoot);
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> pumpSidebar(WidgetTester tester) async {
    final book = TextBook(
      title: SeforimFixtureIds.bereshitTitle,
      categoryId: SeforimFixtureIds.torahCategoryId,
    );
    LibraryProviderManager.instance.seedMappingsForTesting(
      mapping: {BookCompositeKey.fromBook(book)!: provider},
      providers: [provider],
    );
    final bloc = _TestTextBookBloc(_loadedState(book));
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<TextBookBloc>.value(
            value: bloc,
            child: SizedBox(
              width: 400,
              height: 800,
              child: AltTocSidebarView(
                book: book,
                closeLeftPaneCallback: () {},
                lines: LineScrollController(),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleRealAsync(tester);
    await tester.pumpAndSettle();
  }

  Future<void> tapRow(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await _settleRealAsync(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('לחיצה על שורת כותרת בלי קישור פותחת וסוגרת אותה', (
    tester,
  ) async {
    await pumpSidebar(tester);
    expect(find.text(_linklessParent), findsOneWidget);
    expect(find.text(_linklessChild), findsNothing);

    await tapRow(tester, _linklessParent);
    expect(find.text(_linklessChild), findsOneWidget);

    await tapRow(tester, _linklessParent);
    expect(find.text(_linklessChild), findsNothing);
  });

  testWidgets('לחיצה על שורת כותרת עם קישור משלה אינה פותחת אותה', (
    tester,
  ) async {
    await pumpSidebar(tester);
    expect(find.text(_linkedChild), findsNothing);

    await tapRow(tester, _linkedParent);
    expect(find.text(_linkedChild), findsNothing);
  });

  testWidgets('לחיצה על שורת המבנה סוגרת ופותחת אותו', (tester) async {
    await pumpSidebar(tester);
    expect(find.text(_linkedParent), findsOneWidget);

    await tapRow(tester, 'פרשה');
    expect(find.text(_linkedParent), findsNothing);

    await tapRow(tester, 'פרשה');
    expect(find.text(_linkedParent), findsOneWidget);
  });
}

/// שאילתות המסד רצות ב-isolate וזקוקות לזמן אמיתי, בזו אחר זו.
Future<void> _settleRealAsync(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }
}

TextBookLoaded _loadedState(TextBook book) {
  return TextBookLoaded(
    book: book,
    showLeftPane: true,
    content: const ['בראשית א', 'שורה ב', 'שורה ג'],
    fontSize: 18,
    showSplitView: false,
    activeCommentators: const [],
    commentatorGroups: const [],
    availableCommentators: const [],
    links: const [],
    visibleLinks: const [],
    linksByLine: const {},
    tableOfContents: const [],
    removeNikud: false,
    visibleIndices: const [0],
    selectedIndex: 0,
    pinLeftPane: false,
    searchText: '',
  );
}
