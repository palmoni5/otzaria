import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_event.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_state.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/view/combined_view/combined_book_screen.dart';
import 'package:otzaria/text_book/view/selection/enhanced_gesture_detector.dart';
import 'package:otzaria/text_book/view/selection/selection_sync_controller.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../test_helpers/memory_cache_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  group('buildCombinedViewContextMenuLinksForParagraph', () {
    test('מחזירה רק קישורים רגילים של הפסקה שנלחצה', () {
      final linksByLine = <int, List<Link>>{
        3: [
          Link(
            heRef: 'בראשית ג ב',
            index1: 3,
            path2: 'zfoo/zzz.txt',
            index2: 10,
            connectionType: 'REFERENCE',
          ),
          Link(
            heRef: 'בראשית ג',
            index1: 3,
            path2: 'foo/bar.txt',
            index2: 7,
            connectionType: 'REFERENCE',
          ),
          Link(
            heRef: 'רש"י על בראשית ג',
            index1: 3,
            path2: 'commentary/rashi.txt',
            index2: 7,
            connectionType: 'COMMENTARY',
          ),
          Link(
            heRef: 'בראשית ג inline',
            index1: 3,
            path2: 'foo/inline.txt',
            index2: 8,
            connectionType: 'REFERENCE',
            start: 1,
            end: 4,
          ),
        ],
        4: [
          Link(
            heRef: 'בראשית ד',
            index1: 4,
            path2: 'foo/other.txt',
            index2: 9,
            connectionType: 'REFERENCE',
          ),
        ],
      };

      final result = buildCombinedViewContextMenuLinksForParagraph(
        linksByLine: linksByLine,
        paragraphIndex: 2,
      );

      expect(result, hasLength(2));
      expect(result.map((link) => link.heRef), ['בראשית ג', 'בראשית ג ב']);
    });

    test('מחזירה רשימה ריקה כשאין קישורים לפסקה', () {
      final result = buildCombinedViewContextMenuLinksForParagraph(
        linksByLine: const <int, List<Link>>{},
        paragraphIndex: 10,
      );

      expect(result, isEmpty);
    });
  });

  group('shouldShowOpenCommentatorsPaneEntry', () {
    test('מחזירה true כשיש מפרשים נבחרים, החלונית בצד וטאב המפרשים אינו פעיל',
        () {
      expect(
        shouldShowOpenCommentatorsPaneEntry(
          hasSelectedCommentators: true,
          showCommentaryAsExpansionTiles: false,
          isCommentatorsTabActive: false,
        ),
        isTrue,
      );
    });

    test('מחזירה false כשאין מפרשים נבחרים', () {
      expect(
        shouldShowOpenCommentatorsPaneEntry(
          hasSelectedCommentators: false,
          showCommentaryAsExpansionTiles: false,
          isCommentatorsTabActive: false,
        ),
        isFalse,
      );
    });

    test('מחזירה false כשהמפרשים מוצגים כהרחבה מתחת לטקסט', () {
      expect(
        shouldShowOpenCommentatorsPaneEntry(
          hasSelectedCommentators: true,
          showCommentaryAsExpansionTiles: true,
          isCommentatorsTabActive: false,
        ),
        isFalse,
      );
    });

    test('מחזירה false כשטאב המפרשים כבר פעיל', () {
      expect(
        shouldShowOpenCommentatorsPaneEntry(
          hasSelectedCommentators: true,
          showCommentaryAsExpansionTiles: false,
          isCommentatorsTabActive: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldShowOpenLinksPaneEntry', () {
    test('מחזירה true כשיש קישורים וטאב הקישורים אינו פעיל', () {
      expect(
        shouldShowOpenLinksPaneEntry(
          hasLinks: true,
          isLinksTabActive: false,
        ),
        isTrue,
      );
    });

    test('מחזירה false כשאין קישורים', () {
      expect(
        shouldShowOpenLinksPaneEntry(
          hasLinks: false,
          isLinksTabActive: false,
        ),
        isFalse,
      );
    });

    test('מחזירה false כשטאב הקישורים כבר פעיל', () {
      expect(
        shouldShowOpenLinksPaneEntry(
          hasLinks: true,
          isLinksTabActive: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldShowSelectCommentatorsEntry', () {
    test('מחזירה true כשיש callback וטאב המפרשים אינו פעיל', () {
      expect(
        shouldShowSelectCommentatorsEntry(
          hasOpenCommentatorsPaneWithFilterCallback: true,
          isCommentatorsTabActive: false,
        ),
        isTrue,
      );
    });

    test('מחזירה false כשטאב המפרשים פעיל', () {
      expect(
        shouldShowSelectCommentatorsEntry(
          hasOpenCommentatorsPaneWithFilterCallback: true,
          isCommentatorsTabActive: true,
        ),
        isFalse,
      );
    });

    test('מחזירה false כשאין callback', () {
      expect(
        shouldShowSelectCommentatorsEntry(
          hasOpenCommentatorsPaneWithFilterCallback: false,
          isCommentatorsTabActive: false,
        ),
        isFalse,
      );
    });

    test(
        'בניגוד ל-shouldShowOpenCommentatorsPaneEntry, מציג גם בלי מפרשים נבחרים',
        () {
      // הלוגיקה כאן לא תלויה ב-hasSelectedCommentators כלל — היחס בין
      // שני ה-predicates אמור להישאר עקבי גם כשהבחירה ריקה.
      expect(
        shouldShowOpenCommentatorsPaneEntry(
          hasSelectedCommentators: false,
          showCommentaryAsExpansionTiles: false,
          isCommentatorsTabActive: false,
        ),
        isFalse,
      );
      expect(
        shouldShowSelectCommentatorsEntry(
          hasOpenCommentatorsPaneWithFilterCallback: true,
          isCommentatorsTabActive: false,
        ),
        isTrue,
      );
    });
  });

  group('shouldRebuildSelectionAreaOnExternalChange', () {
    test('מחזירה false כש-activeOwner הוא null (ניקוי בעלות)', () {
      // אחרי clear ה-controller מודיע עם activeOwner=null — אסור לבנות מחדש,
      // אחרת ניקוי בחירה גורם לקפיצה בגלילה.
      final selfOwner = Object();
      expect(
        shouldRebuildSelectionAreaOnExternalChange(
          activeOwner: null,
          selfOwner: selfOwner,
          hasOwnSelection: true,
        ),
        isFalse,
      );
    });

    test('מחזירה false כש-activeOwner זהה ל-selfOwner', () {
      final selfOwner = Object();
      expect(
        shouldRebuildSelectionAreaOnExternalChange(
          activeOwner: selfOwner,
          selfOwner: selfOwner,
          hasOwnSelection: true,
        ),
        isFalse,
      );
    });

    test(
        "מחזירה false כשאזור חיצוני מקבל בעלות אבל אין לנו בחירה משלנו לנקות "
        "(תרחיש 'מפרשים מתחת': בחירת טקסט במפרש המקונן לא צריכה להרוס את עץ הצאצאים)",
        () {
      // הבאג שתוקן: במצב 'מפרשים מתחת' ה-CommentaryListBase מקונן בעץ
      // ה-SelectionArea של ה-CombinedView. כשהמשתמש מסמן טקסט במפרש,
      // ה-controller מעביר בעלות לאזור המפרש. לפני התיקון, ה-CombinedView
      // היה מעלה את revision ובונה את ה-SelectionArea מחדש — מה שהשמיד את
      // ה-CommentaryListBase וגרם לטעינה מחדש של המפרש.
      final selfOwner = Object();
      final commentaryOwner = Object();
      expect(
        shouldRebuildSelectionAreaOnExternalChange(
          activeOwner: commentaryOwner,
          selfOwner: selfOwner,
          hasOwnSelection: false,
        ),
        isFalse,
      );
    });

    test('מחזירה true כשאזור חיצוני מקבל בעלות ויש לנו בחירה משלנו לנקות', () {
      final selfOwner = Object();
      final externalOwner = Object();
      expect(
        shouldRebuildSelectionAreaOnExternalChange(
          activeOwner: externalOwner,
          selfOwner: selfOwner,
          hasOwnSelection: true,
        ),
        isTrue,
      );
    });
  });

  group('תרחישים חוצי-טאב בחלונית הצד', () {
    test('"פתח מפרשים" מוצגת כשהחלונית פתוחה על טאב הקישורים', () {
      expect(
        shouldShowOpenCommentatorsPaneEntry(
          hasSelectedCommentators: true,
          showCommentaryAsExpansionTiles: false,
          isCommentatorsTabActive: false,
        ),
        isTrue,
      );
    });

    test('"פתח קישורים" מוצגת כשהחלונית פתוחה על טאב המפרשים', () {
      expect(
        shouldShowOpenLinksPaneEntry(
          hasLinks: true,
          isLinksTabActive: false,
        ),
        isTrue,
      );
    });

    test('"פתח מפרשים" מסתתרת כשאין מפרשים נבחרים אפילו אם זמינים בספר', () {
      expect(
        shouldShowOpenCommentatorsPaneEntry(
          hasSelectedCommentators: false,
          showCommentaryAsExpansionTiles: false,
          isCommentatorsTabActive: false,
        ),
        isFalse,
      );
    });
  });

  testWidgets('לחיצה על פסקה לא שולחת event ל-bloc סגור', (tester) async {
    final textBookBloc = _ClosedTextBookBloc(_loadedState());
    final personalNotesBloc = _TestPersonalNotesBloc(
      PersonalNotesState(
        isLoading: false,
        bookId: 'ספר בדיקה',
        locatedNotes: const [],
        missingNotes: const [],
        errorMessage: null,
        filteredLocatedNotes: const [],
        filteredMissingNotes: const [],
      ),
    );
    final settingsBloc = _TestSettingsBloc(SettingsState.initial());
    final tab = TextBookTab(
      book: TextBook(title: 'ספר בדיקה'),
      index: 0,
    );

    addTearDown(tab.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<TextBookBloc>.value(value: textBookBloc),
            BlocProvider<PersonalNotesBloc>.value(value: personalNotesBloc),
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
          ],
          child: Scaffold(
            body: CombinedView(
              data: const ['שורה א'],
              openBookCallback: (_) {},
              openLeftPaneTab: (_, {searchText}) {},
              textSize: 18,
              showCommentaryAsExpansionTiles: false,
              tab: tab,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.byType(EnhancedGestureDetector).first);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));

    expect(textBookBloc.addWasCalled, isFalse);
    expect(tester.takeException(), isNull);
  });
}

TextBookLoaded _loadedState() {
  return TextBookLoaded(
    book: TextBook(title: 'ספר בדיקה'),
    showLeftPane: false,
    content: const ['שורה א'],
    fontSize: 18,
    showSplitView: false,
    showPageShapeView: false,
    activeCommentators: const [],
    commentatorGroups: const [],
    availableCommentators: const [],
    links: const [],
    visibleLinks: const [],
    linksByLine: const {},
    tableOfContents: const [],
    removeNikud: false,
    visibleIndices: const [0],
    selectedIndex: null,
    pinLeftPane: false,
    searchText: '',
    scrollController: ItemScrollController(),
    positionsListener: ItemPositionsListener.create(),
  );
}

class _ClosedTextBookBloc extends Bloc<TextBookEvent, TextBookState>
    implements TextBookBloc {
  _ClosedTextBookBloc(super.initialState) {
    on<TextBookEvent>((event, emit) {});
  }

  bool addWasCalled = false;

  @override
  bool get isClosed => true;

  @override
  void add(TextBookEvent event) {
    addWasCalled = true;
    throw StateError('add לא אמור להיקרא כשה-bloc סגור');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestPersonalNotesBloc
    extends Bloc<PersonalNotesEvent, PersonalNotesState>
    implements PersonalNotesBloc {
  _TestPersonalNotesBloc(super.initialState) {
    on<PersonalNotesEvent>((event, emit) {});
  }

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
