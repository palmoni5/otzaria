import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_event.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_state.dart';
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/personal_notes/widgets/personal_notes_sidebar.dart';
import 'package:otzaria/widgets/feedback/scrollable_positioned_list_scrollbar.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../test_helpers/memory_cache_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  PersonalNote note(int index) => PersonalNote(
    id: 'note-$index',
    bookId: 'ספר בדיקה',
    lineNumber: index + 1,
    displayTitle: 'הערה בשורה ${index + 1}',
    lastKnownLineNumber: index + 1,
    status: PersonalNoteStatus.located,
    content: 'תוכן הערה $index',
    contentPlain: 'תוכן הערה $index',
    contentFormat: PersonalNoteContentFormat.plain,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<void> pumpSidebar(
    WidgetTester tester, {
    int noteCount = 30,
    List<PersonalNote>? notes,
  }) async {
    final notesBloc = _StubNotesBloc(notes ?? List.generate(noteCount, note));
    addTearDown(notesBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          // האפליקציה כולה RTL (locale he_IL); בלי זה הצד נמדד הפוך.
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: BlocProvider<PersonalNotesBloc>.value(
              value: notesBloc,
              child: PersonalNotesSidebar(
                bookId: 'ספר בדיקה',
                onNavigateToLine: (_, {note}) {},
                visibleLineIndices: const [],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('המסילה בקצה ימין של החלונית, לא בשמאל', (tester) async {
    await pumpSidebar(tester);

    final barRect = tester.getRect(
      find.byType(ScrollablePositionedListScrollbar),
    );
    final listRect = tester.getRect(find.byType(ScrollablePositionedList));

    expect(
      listRect.right,
      lessThan(barRect.right),
      reason: 'המסילה חייבת לתפוס את הקצה הימני והרשימה להצטמצם לפניה',
    );
    expect(
      listRect.left,
      barRect.left,
      reason: 'אין מסילה בקצה השמאלי — הרשימה מגיעה עד לשם',
    );
  });

  testWidgets('המסילה והרשימה חולקות offsetController', (tester) async {
    await pumpSidebar(tester);

    final bar = tester.widget<ScrollablePositionedListScrollbar>(
      find.byType(ScrollablePositionedListScrollbar),
    );
    final list = tester.widget<ScrollablePositionedList>(
      find.byType(ScrollablePositionedList),
    );

    expect(bar.offsetController, isNotNull);
    expect(bar.offsetController, same(list.scrollOffsetController));
  });

  testWidgets('גרירת המסילה גוללת בתוך הערה יחידה וארוכה', (tester) async {
    final longContent = List.filled(200, 'שורה ארוכה לבדיקה').join('\n');
    final longNote = PersonalNote(
      id: 'long-note',
      bookId: 'ספר בדיקה',
      lineNumber: 1,
      displayTitle: 'הערה ארוכה',
      lastKnownLineNumber: 1,
      status: PersonalNoteStatus.located,
      content: longContent,
      contentPlain: longContent,
      contentFormat: PersonalNoteContentFormat.plain,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await pumpSidebar(tester, notes: [longNote]);

    await tester.tap(find.byTooltip('פתח'));
    await tester.pumpAndSettle();

    final scrollbar = find.byType(ScrollablePositionedListScrollbar);
    final scrollbarRect = tester.getRect(scrollbar);
    final listFinder = find.byType(ScrollablePositionedList);
    final list = tester.widget<ScrollablePositionedList>(listFinder);
    expect(
      tester.getRect(listFinder).right,
      lessThan(scrollbarRect.right),
      reason: 'הערה גבוהה מציגה מסילה ותופסת לה מקום בפריסה',
    );
    expect(
      list.itemPositionsNotifier!.itemPositions.value.single.itemLeadingEdge,
      closeTo(0, 0.01),
    );

    await tester.dragFrom(
      Offset(scrollbarRect.right - 6, scrollbarRect.top + 20),
      Offset(0, scrollbarRect.height - 40),
    );
    await tester.pumpAndSettle();

    expect(
      list.itemPositionsNotifier!.itemPositions.value.single.itemLeadingEdge,
      lessThan(-0.1),
      reason: 'ה־offsetController מאפשר למסילה לגלול בתוך אותו פריט',
    );
  });

  testWidgets('אין מה לגלול — אין מסילה ואין צמצום של הרשימה', (tester) async {
    await pumpSidebar(tester, noteCount: 1);

    final barRect = tester.getRect(
      find.byType(ScrollablePositionedListScrollbar),
    );
    final listRect = tester.getRect(find.byType(ScrollablePositionedList));

    expect(listRect.right, barRect.right);
  });
}

class _StubNotesBloc extends Bloc<PersonalNotesEvent, PersonalNotesState>
    implements PersonalNotesBloc {
  _StubNotesBloc(this.notes) : super(const PersonalNotesState.initial()) {
    on<PersonalNotesEvent>((event, emit) {
      if (event is LoadPersonalNotes) {
        emit(
          state.copyWith(
            bookId: event.bookId,
            locatedNotes: notes,
            isLoading: false,
          ),
        );
      }
    });
  }

  final List<PersonalNote> notes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
