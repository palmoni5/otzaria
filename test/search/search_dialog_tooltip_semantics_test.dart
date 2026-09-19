// issue #1399: כפתור ברירות המחדל יושב בתוך MenuAnchor.builder עם tooltip.
// כשה-Tooltip עוטף את הכפתור מבחוץ, עוגן הבלון ועוגן התפריט מתמזגים לצומת
// סמנטיקה אחד, ובריחוף הבלון נשלח למערכת ההפעלה בלי אב — Windows דוחה את
// עדכון עץ הנגישות, העץ קופא והתוכנה קורסת במעבר הפוקוס הבא.
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/history/bloc/history_state.dart';
import 'package:otzaria/indexing/bloc/indexing_bloc.dart';
import 'package:otzaria/indexing/bloc/indexing_event.dart';
import 'package:otzaria/indexing/bloc/indexing_state.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/library/bloc/library_event.dart';
import 'package:otzaria/library/bloc/library_state.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/search/view/search_dialog.dart';

import '../helpers/semantics_update_recorder.dart';
import '../support/search_engine_test_init.dart';
import '../test_helpers/memory_cache_provider.dart';

class _MockHistoryBloc extends MockBloc<HistoryEvent, HistoryState>
    implements HistoryBloc {}

class _MockIndexingBloc extends MockBloc<IndexingEvent, IndexingState>
    implements IndexingBloc {}

class _MockNavigationBloc extends MockBloc<NavigationEvent, NavigationState>
    implements NavigationBloc {}

class _MockLibraryBloc extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

Future<void> main() async {
  // ה-binding המקליט חייב להיווצר לפני כל binding אחר.
  SemanticsRecordingBinding.ensure();
  final recorder = SemanticsRecordingBinding.recorder;

  // הדיאלוג קורא ל-splitQueryWords שמאציל למנוע ה-Rust; בלי הספרייה
  // הנייטיבית הבדיקה מדולגת כמו יתר בדיקות החיפוש התלויות בה.
  final engineReady = await tryInitSearchEngine();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  testWidgets(
    'ריחוף על כפתור ברירות המחדל בתוך MenuAnchor אינו שולח צומת נגישות '
    'יתום (issue #1399)',
    (tester) async {
      recorder.reset();
      final handle = tester.ensureSemantics();
      final historyBloc = _MockHistoryBloc();
      final indexingBloc = _MockIndexingBloc();
      final navigationBloc = _MockNavigationBloc();
      final libraryBloc = _MockLibraryBloc();

      whenListen(
        historyBloc,
        const Stream<HistoryState>.empty(),
        initialState: HistoryLoaded([]),
      );
      whenListen(
        indexingBloc,
        const Stream<IndexingState>.empty(),
        initialState: IndexingInitial(),
      );
      whenListen(
        navigationBloc,
        const Stream<NavigationState>.empty(),
        initialState: const NavigationState(currentScreen: Screen.search),
      );
      whenListen(
        libraryBloc,
        const Stream<LibraryState>.empty(),
        initialState: const LibraryState(),
      );

      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        await historyBloc.close();
        await indexingBloc.close();
        await navigationBloc.close();
        await libraryBloc.close();
      });

      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<HistoryBloc>.value(value: historyBloc),
              BlocProvider<IndexingBloc>.value(value: indexingBloc),
              BlocProvider<NavigationBloc>.value(value: navigationBloc),
              BlocProvider<LibraryBloc>.value(value: libraryBloc),
            ],
            child: const Scaffold(body: SearchDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const tooltip = 'ברירות מחדל לחיפוש';
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byTooltip(tooltip)));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(tooltip), findsOneWidget, reason: 'הבלון נפתח');
      expect(
        recorder.violations,
        isEmpty,
        reason: 'עדכוני הסמנטיקה חייבים להתקבל במנוע ללא צומת יתום',
      );

      await mouse.moveTo(const Offset(5, 5));
      await tester.pump(const Duration(seconds: 1));
      expect(recorder.violations, isEmpty);
      handle.dispose();
    },
    skip: !engineReady,
  );
}
