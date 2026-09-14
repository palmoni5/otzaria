// מצלם את ארבעת מסכי התכונות של המתקין (installer/feature1-4.bmp) מהתוכנה עצמה.
// רץ מ-.github/workflows/installer-screenshots.yml; ההמרה ל-BMP ב-tool/installer_screenshots/.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:integration_test/integration_test.dart';
import 'package:otzaria/app.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/data/data_providers/hive_data_provider.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/main.dart' as app;
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/link_types.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/pdf_book/view/pdf_commentary_panel.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/settings/l10n/settings_language.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/tabs/models/tool_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/view/commentary_list_base.dart';
import 'package:otzaria/tour/models/tour_steps.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' as utils;
import 'package:otzaria/widgets/misc/app_cursors.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

/// תיקייה שמכילה את `books` (עם seforim.db) ואת `index`.
const _libraryRootEnv = 'OTZARIA_SHOTS_LIBRARY';

/// התיקייה שאליה נכתבים feature1.png עד feature4.png.
const _outDirEnv = 'OTZARIA_SHOTS_OUT';

// יחס 400:210 של תמונות המתקין.
const _logicalSize = Size(1920, 1008);
const _pixelRatio = 1.5;

const _textBookTitle = 'בראשית';
const _pdfBookTitle = 'ברכות';
const _searchQuery = 'משה';
const _calendarToolId = 'builtin.calendar';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('צילום מסכי התכונות של המתקין', timeout: Timeout.none, (
    tester,
  ) async {
    final libraryRoot = _requireEnv(_libraryRootEnv);
    final outDir = Directory(_requireEnv(_outDirEnv))
      ..createSync(recursive: true);
    // פלט flutter test מודפס רק בסוף ואובד כשהשלב נקטע; הקובץ שורד ומועלה.
    final progress = File(p.join(outDir.path, 'progress.txt'));
    void mark(String step) => progress.writeAsStringSync(
      '${DateTime.now().toIso8601String()} $step\n',
      mode: FileMode.append,
      flush: true,
    );
    mark('start');

    // שורש נתונים נקי: בלי טאבים משוחזרים ובלי לגעת בהגדרות של המשתמש.
    final dataRoot = Directory(p.join(outDir.path, '_app_data'));
    if (dataRoot.existsSync()) dataRoot.deleteSync(recursive: true);
    dataRoot.createSync(recursive: true);
    await _seedPreferences(dataRoot.path, libraryRoot);
    AppPaths.configureDataRootPathForProcess(dataRoot.path);
    mark('seeded');

    tester.view.physicalSize = _logicalSize * _pixelRatio;
    tester.view.devicePixelRatio = _pixelRatio;
    addTearDown(tester.view.reset);

    AppCursors.skipForTesting = true;
    WidgetsApp.debugAllowBannerOverride = false;
    mark('app.main');
    app.main(const <String>[]);
    // ב-macOS החלון שקוף עד החשיפה, וחלון שאינו נראה לא מקבל vsync — pump נתקע.
    await const MethodChannel('otzaria/splash').invokeMethod<void>('close');
    mark('splash closed');
    await tester.pump();
    mark('first pump');
    await _waitUntil(
      tester,
      'עליית האפליקציה',
      () => find.byType(App).evaluate().isNotEmpty,
      const Duration(minutes: 3),
    );
    mark('App mounted');
    final context = tester.element(find.byType(App));
    final tabsBloc = context.read<TabsBloc>();
    final navigation = context.read<NavigationBloc>();
    final library = await DataRepository.instance.library;
    await _pumpFor(tester, const Duration(seconds: 8));

    Future<void> open(OpenedTab tab, Screen screen) async {
      tabsBloc.add(CloseAllTabs());
      await _pumpFor(tester, const Duration(seconds: 1));
      tabsBloc.add(AddTab(tab));
      navigation.add(NavigateToScreen(screen));
      await _pumpFor(tester, const Duration(seconds: 2));
    }

    // 1. ספר עם מפרשים
    final textBook = library.findBookByTitle(_textBookTitle, TextBook);
    expect(textBook, isNotNull, reason: '$_textBookTitle לא נמצא בספרייה');
    final textTab = TextBookTab(
      book: textBook! as TextBook,
      index: 0,
      openLeftPane: true,
    );
    await open(textTab, Screen.reading);
    await _waitUntil(tester, 'רשימת המפרשים', () {
      final state = textTab.bloc.state;
      return state is TextBookLoaded && state.availableCommentators.isNotEmpty;
    }, const Duration(minutes: 2));
    final available =
        (textTab.bloc.state as TextBookLoaded).availableCommentators;
    textTab.bloc.add(UpdateCommentators(available));
    await _pumpFor(tester, const Duration(seconds: 1));
    textTab.toggleCommentatorsPaneNotifier.value++;
    await _pumpFor(tester, const Duration(seconds: 6));
    // מכווצים כדי שיוצג מגוון המפרשים, ולא הטקסט של הראשון בלבד.
    final commentary = tester.state<CommentaryListBaseState>(
      find.byType(CommentaryListBase).first,
    );
    if (commentary.allExpandedListenable.value) commentary.toggleAllExpanded();
    await _pumpFor(tester, const Duration(seconds: 2));
    await _capture(outDir, 'feature1');
    mark('feature1');

    // 2. לוח שנה
    await open(
      ToolTab(
        toolId: _calendarToolId,
        title: ToolTab.fallbackTitleFor(_calendarToolId),
      ),
      Screen.reading,
    );
    await _pumpFor(tester, const Duration(seconds: 6));
    await _capture(outDir, 'feature2');
    mark('feature2');

    // 3. ספר PDF
    final pdfBook = library
        .getAllBooks()
        .whereType<PdfBook>()
        .where((b) => b.title == _pdfBookTitle && File(b.path).existsSync())
        .firstOrNull;
    expect(pdfBook, isNotNull, reason: '$_pdfBookTitle.pdf לא נמצא בספרייה');
    final pdfTab = PdfBookTab(book: pdfBook!, pageNumber: 1);
    await open(pdfTab, Screen.reading);
    await _waitUntil(
      tester,
      'טעינת ה-PDF',
      () => pdfTab.pdfViewerController.isReady && pdfTab.outline.value != null,
      const Duration(minutes: 2),
    );
    final firstEntryPage = _firstLeafPage(pdfTab.outline.value!);
    if (firstEntryPage != null) {
      // בלי אנימציה: ההמתנה לסיומה תלויה בפריימים שאף אחד לא דוחף בזמן ה-await.
      await pdfTab.pdfViewerController.goToPage(
        pageNumber: firstEntryPage,
        duration: Duration.zero,
      );
    }
    await _waitUntil(
      tester,
      'קישורי ה-PDF',
      () => !pdfTab.linksLoadingNotifier.value && pdfTab.links.isNotEmpty,
      const Duration(minutes: 2),
    );
    // אותה בחירה כמו רשימת המפרשים הזמינים שהמסך בונה מהקישורים.
    pdfTab.activeCommentators = {
      for (final link in pdfTab.links)
        if (LinkTypes.isDependentTextLink(link.connectionType))
          utils.getTitleFromPath(link.path2),
    };
    // חלונית שנפתחה לבד נבנתה עם מפרשי ברירת המחדל; סוגרים ופותחים מחדש.
    if (find.byType(PdfCommentaryPanel).evaluate().isNotEmpty) {
      pdfTab.toggleCommentatorsPaneNotifier.value++;
      await _pumpFor(tester, const Duration(seconds: 1));
    }
    pdfTab.toggleCommentatorsPaneNotifier.value++;
    await _pumpFor(tester, const Duration(seconds: 6));
    tester
        .state<PdfCommentaryPanelState>(find.byType(PdfCommentaryPanel).first)
        .toggleAllExpanded();
    await _pumpFor(tester, const Duration(seconds: 3));
    await _capture(outDir, 'feature3');
    mark('feature3');

    // 4. חיפוש
    final searchTab = SearchingTab('חיפוש', _searchQuery);
    await open(searchTab, Screen.search);
    await _waitUntil(tester, 'תוצאות החיפוש', () {
      final state = searchTab.searchBloc.state;
      return !state.isLoading && state.results.isNotEmpty;
    }, const Duration(minutes: 2));
    await _pumpFor(tester, const Duration(seconds: 4));
    await _capture(outDir, 'feature4');
  });
}

String _requireEnv(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) fail('חסר משתנה הסביבה $name');
  return value;
}

Future<void> _seedPreferences(String dataRoot, String libraryRoot) async {
  final box = await Hive.openBox<dynamic>(HiveCache.keyName, path: dataRoot);
  await box.putAll(<String, Object>{
    SettingsRepository.keyLibraryPath: p.join(libraryRoot, 'books'),
    SettingsRepository.keyLibraryFolderName: '',
    SettingsRepository.keyIndexPath: p.join(libraryRoot, 'index'),
    // עדכונים והסיור המודרך היו נפתחים מעל המסך המצולם.
    SettingsRepository.keySoftwareAndBookUpdatesEnabled: false,
    SettingsRepository.keyAutoUpdateIndex: false,
    SettingsRepository.keyFollowSystemTheme: false,
    SettingsRepository.keyDarkMode: false,
    // ברירת המחדל עוקבת אחרי שפת המערכת, וב-runner היא אנגלית.
    SettingsRepository.keySettingsLanguage: SettingsLanguage.hebrew.code,
    TourSteps.statusKey: TourSteps.completed,
  });
  await box.close();
}

int? _firstLeafPage(List<PdfOutlineNode> nodes) {
  for (final node in nodes) {
    final page = node.children.isEmpty
        ? node.dest?.pageNumber
        : _firstLeafPage(node.children);
    if (page != null) return page;
  }
  return null;
}

Future<void> _capture(Directory outDir, String name) async {
  final view = RendererBinding.instance.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final image = await layer.toImage(view.paintBounds);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(
    p.join(outDir.path, '$name.png'),
  ).writeAsBytesSync(png!.buffer.asUint8List());
}

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
}

Future<void> _waitUntil(
  WidgetTester tester,
  String what,
  bool Function() condition,
  Duration timeout,
) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('פג הזמן בהמתנה ל$what');
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
