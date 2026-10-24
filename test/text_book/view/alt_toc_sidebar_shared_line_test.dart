import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/settings/engine/app_settings_store.dart';
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
import 'package:otzaria/widgets/lists/nav_tree_tile.dart';
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

const _firstPage = 'דף ו';
const _lastPage = 'דף ז';

/// #3181: כמה דפים פותחים באותה פסקה, והשורה ממופה במסד לאחרון שבהם.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final provider = DatabaseLibraryProvider.instance;
  final previousDataRoot = AppPaths.cachedDataRootPath;
  late Directory tempDir;

  setUp(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
    tempDir = await Directory.systemTemp.createTemp('otzaria_alt_shared');
    final libraryPath = p.join(tempDir.path, 'library');
    Directory(libraryPath).createSync();
    final dbPath = p.join(libraryPath, DatabaseConstants.databaseFileName);
    File(
      SeforimFixtureDb.create(
        Directory(libraryPath),
        SeforimFixtureVariant.full,
      ),
    ).renameSync(dbPath);
    // שני דפים אחים על שורה 2, ו-line_alt_toc ממפה אותה לאחרון — כמו המחולל.
    final db = sqlite3.sqlite3.open(dbPath);
    db.execute("UPDATE alt_toc_structure SET key = 'Dapim' WHERE id = 1");
    db.execute('INSERT INTO tocText VALUES (3, ?), (4, ?)', [
      _firstPage,
      _lastPage,
    ]);
    db.execute(
      'INSERT INTO alt_toc_entry (id, structureId, parentId, textId, level, '
      'lineId, hasChildren) VALUES (2, 1, NULL, 3, 1, 2, 0), '
      '(3, 1, NULL, 4, 1, 2, 0)',
    );
    db.execute('INSERT INTO line_alt_toc VALUES (2, 1, 3)');
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

  bool isSelected(WidgetTester tester, String title) => tester
      .widget<NavTreeTile>(
        find.ancestor(of: find.text(title), matching: find.byType(NavTreeTile)),
      )
      .isSelected;

  testWidgets('הדף שנלחץ נשאר מסומן כשהגלילה מגיעה לשורה המשותפת', (
    tester,
  ) async {
    final book = TextBook(
      title: SeforimFixtureIds.bereshitTitle,
      categoryId: SeforimFixtureIds.torahCategoryId,
    );
    LibraryProviderManager.instance.seedMappingsForTesting(
      mapping: {BookCompositeKey.fromBook(book)!: provider},
      providers: [provider],
    );
    final bloc = _TestTextBookBloc(_loadedState(book, visibleLine: 0));
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

    await tester.tap(find.text(_firstPage));
    await _settleRealAsync(tester);
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    bloc.emit(_loadedState(book, visibleLine: 1));
    await _settleRealAsync(tester);
    await tester.pumpAndSettle();

    expect(isSelected(tester, _firstPage), isTrue);
    expect(isSelected(tester, _lastPage), isFalse);
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

TextBookLoaded _loadedState(TextBook book, {required int visibleLine}) {
  return TextBookLoaded(
    book: book,
    showLeftPane: true,
    content: const ['בראשית א', 'א [דף ו טור א] ב [דף ז טור א] ג', 'שורה ג'],
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
    visibleIndices: [visibleLine],
    selectedIndex: null,
    pinLeftPane: false,
    searchText: '',
  );
}
