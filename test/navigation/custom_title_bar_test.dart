import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/navigation/view/custom_title_bar.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/commentators_tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/widgets/navigation/scrollable_tab_bar.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../helpers/memory_settings_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  testWidgets('tooltip של TextBookTab כולל את כותרת המיקום בפועל',
      (tester) async {
    final tab = _makeTextTab('ספר א', currentTitle: 'פרק א');
    final tabsBloc = _TestTabsBloc(
      TabsState(tabs: [tab], currentTabIndex: 0),
    );
    final navigationBloc = _TestNavigationBloc(
      const NavigationState(currentScreen: Screen.reading),
    );
    final settingsBloc = _TestSettingsBloc(SettingsState.initial());

    addTearDown(() async {
      tab.dispose();
      await tabsBloc.close();
      await navigationBloc.close();
      await settingsBloc.close();
    });

    await _setSurfaceSize(tester, const Size(1200, 800));
    await _pumpTitleBar(
      tester,
      tabsBloc: tabsBloc,
      navigationBloc: navigationBloc,
      settingsBloc: settingsBloc,
    );

    expect(find.byTooltip('ספר א, פרק א'), findsOneWidget);
    expect(find.byTooltip(r'${tab.title}, $currentTitleValue'), findsNothing);
  });

  testWidgets(
      'סגירת טאב פנימי במצב יישור לימין דוחה את כיווץ רוחב הטאבים לשתי שניות',
      (tester) async {
    final first = _makeTextTab('ספר א');
    final middle = _makeTextTab('ספר ב');
    final last = _makeTextTab('ספר ג');
    final tabsBloc = _TestTabsBloc(
      TabsState(tabs: [first, middle, last], currentTabIndex: 0),
    );
    final navigationBloc = _TestNavigationBloc(
      const NavigationState(currentScreen: Screen.reading),
    );
    final settingsBloc = _TestSettingsBloc(
      SettingsState.initial().copyWith(alignTabsToRight: true),
    );

    addTearDown(() async {
      first.dispose();
      middle.dispose();
      last.dispose();
      await tabsBloc.close();
      await navigationBloc.close();
      await settingsBloc.close();
    });

    await _setSurfaceSize(tester, const Size(900, 800));
    await _pumpTitleBar(
      tester,
      tabsBloc: tabsBloc,
      navigationBloc: navigationBloc,
      settingsBloc: settingsBloc,
    );

    final initialWidths = _tabWidthsInScrollableBar(tester);
    expect(initialWidths, hasLength(3));
    final initialWidth = initialWidths.first;

    tabsBloc.emit(TabsState(tabs: [first, last], currentTabIndex: 0));
    await tester.pump();
    await tester.pump();

    final immediateWidths = _tabWidthsInScrollableBar(tester);
    expect(immediateWidths, hasLength(2));
    expect(immediateWidths.first, closeTo(initialWidth, 0.01));

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();

    final delayedWidths = _tabWidthsInScrollableBar(tester);
    expect(delayedWidths, hasLength(2));
    expect(delayedWidths.first, greaterThan(initialWidth));
  });

  testWidgets('ביישור לימין טאב יחיד נשאר ברוחב טבעי ולא מקבל רוחב אחיד',
      (tester) async {
    final tab = _makeTextTab('ספר א');
    final tabsBloc = _TestTabsBloc(
      TabsState(tabs: [tab], currentTabIndex: 0),
    );
    final navigationBloc = _TestNavigationBloc(
      const NavigationState(currentScreen: Screen.reading),
    );
    final settingsBloc = _TestSettingsBloc(
      SettingsState.initial().copyWith(alignTabsToRight: true),
    );

    addTearDown(() async {
      tab.dispose();
      await tabsBloc.close();
      await navigationBloc.close();
      await settingsBloc.close();
    });

    await _setSurfaceSize(tester, const Size(1200, 800));
    await _pumpTitleBar(
      tester,
      tabsBloc: tabsBloc,
      navigationBloc: navigationBloc,
      settingsBloc: settingsBloc,
    );

    expect(_tabWidthsInScrollableBar(tester), isEmpty);
  });

  testWidgets('ביישור לימין כמה טאבים עדיין מציגים את הכותרות שלהם',
      (tester) async {
    final first = _makeTextTab('ספר א');
    final second = _makeTextTab('ספר ב');
    final tabsBloc = _TestTabsBloc(
      TabsState(tabs: [first, second], currentTabIndex: 0),
    );
    final navigationBloc = _TestNavigationBloc(
      const NavigationState(currentScreen: Screen.reading),
    );
    final settingsBloc = _TestSettingsBloc(
      SettingsState.initial().copyWith(alignTabsToRight: true),
    );

    addTearDown(() async {
      first.dispose();
      second.dispose();
      await tabsBloc.close();
      await navigationBloc.close();
      await settingsBloc.close();
    });

    await _setSurfaceSize(tester, const Size(1200, 800));
    await _pumpTitleBar(
      tester,
      tabsBloc: tabsBloc,
      navigationBloc: navigationBloc,
      settingsBloc: settingsBloc,
    );

    expect(find.text('ספר א'), findsOneWidget);
    expect(find.text('ספר ב'), findsOneWidget);
  });

  testWidgets('ביישור לימין hover על טאב לא יוצר overflow',
      (tester) async {
    final first = _makeTextTab('ספר א');
    final second = _makeTextTab('ספר ב');
    final third = _makeTextTab('ספר ג');
    final fourth = _makeTextTab('ספר ד');
    final tabsBloc = _TestTabsBloc(
      TabsState(tabs: [first, second, third, fourth], currentTabIndex: 0),
    );
    final navigationBloc = _TestNavigationBloc(
      const NavigationState(currentScreen: Screen.reading),
    );
    final settingsBloc = _TestSettingsBloc(
      SettingsState.initial().copyWith(alignTabsToRight: true),
    );

    addTearDown(() async {
      first.dispose();
      second.dispose();
      third.dispose();
      fourth.dispose();
      await tabsBloc.close();
      await navigationBloc.close();
      await settingsBloc.close();
    });

    await _setSurfaceSize(tester, const Size(820, 800));
    await _pumpTitleBar(
      tester,
      tabsBloc: tabsBloc,
      navigationBloc: navigationBloc,
      settingsBloc: settingsBloc,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('ספר ג')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('CommentatorsTab לא מפיל את שורת הכותרת', (tester) async {
    final sourceTab = _makeTextTab('ספר א', currentTitle: 'פרק א');
    final tab = CommentatorsTab(sourceTab: sourceTab);
    final tabsBloc = _TestTabsBloc(
      TabsState(tabs: [tab], currentTabIndex: 0),
    );
    final navigationBloc = _TestNavigationBloc(
      const NavigationState(currentScreen: Screen.reading),
    );
    final settingsBloc = _TestSettingsBloc(SettingsState.initial());

    addTearDown(() async {
      tab.dispose();
      sourceTab.dispose();
      await tabsBloc.close();
      await navigationBloc.close();
      await settingsBloc.close();
    });

    await _setSurfaceSize(tester, const Size(1200, 800));
    await _pumpTitleBar(
      tester,
      tabsBloc: tabsBloc,
      navigationBloc: navigationBloc,
      settingsBloc: settingsBloc,
    );

    expect(find.text('מפרשים | ספר א'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpTitleBar(
  WidgetTester tester, {
  required TabsBloc tabsBloc,
  required NavigationBloc navigationBloc,
  required SettingsBloc settingsBloc,
}) async {
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<TabsBloc>.value(value: tabsBloc),
        BlocProvider<NavigationBloc>.value(value: navigationBloc),
        BlocProvider<SettingsBloc>.value(value: settingsBloc),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: CustomTitleBar(
              onReadingSettingsPressed: () {},
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

List<double> _tabWidthsInScrollableBar(WidgetTester tester) {
  return tester
      .widgetList<SizedBox>(
        find.descendant(
          of: find.byType(ScrollableTabBarWithArrows),
          matching: find.byType(SizedBox),
        ),
      )
      .where((box) => box.child is Listener)
      .map((box) => box.width)
      .whereType<double>()
      .where((width) => width >= 72 && width <= 200)
      .toList();
}

TextBookTab _makeTextTab(String title, {String currentTitle = ''}) {
  final book = TextBook(title: title);
  final bloc = _TestTextBookBloc(
    TextBookLoaded(
      book: book,
      showLeftPane: false,
      content: const ['שורה א'],
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
      removePunctuation: false,
      visibleIndices: const [0],
      selectedIndex: 0,
      pinLeftPane: false,
      searchText: '',
      currentTitle: currentTitle,
      scrollController: ItemScrollController(),
      positionsListener: ItemPositionsListener.create(),
    ),
  );

  final tab = TextBookTab(
    book: book,
    index: 0,
    blocOverride: bloc,
  );
  tab.currentTitle.value = currentTitle;
  return tab;
}

class _TestTextBookBloc extends Bloc<TextBookEvent, TextBookState>
    implements TextBookBloc {
  _TestTextBookBloc(super.initialState) {
    on<TextBookEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestTabsBloc extends Cubit<TabsState> implements TabsBloc {
  _TestTabsBloc(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestNavigationBloc extends Cubit<NavigationState>
    implements NavigationBloc {
  _TestNavigationBloc(super.initialState);

  @override
  void add(NavigationEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _TestSettingsBloc(super.initialState) {
    on<SettingsEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
