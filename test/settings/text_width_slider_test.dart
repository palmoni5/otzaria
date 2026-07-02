// Regression test: סליידר "רוחב הטקסט" חייב לשמור רמה שלילית (-level) ולא
// פיקסלים מוחלטים. שמירת פיקסלים לפי רוחב המסך המלא גרמה לכך שההגדרה לא
// השפיעה כשחלונית המפרשים פתוחה או בחלון צר (העמודה צרה מהערך השמור).

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/settings/tabs/text_settings_tab.dart';

import '../test_helpers/memory_cache_provider.dart';

class MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
    registerFallbackValue(const UpdateTextMaxWidth(0));
  });

  late MockSettingsBloc settingsBloc;

  setUp(() {
    settingsBloc = MockSettingsBloc();
    whenListen(
      settingsBloc,
      const Stream<SettingsState>.empty(),
      initialState: SettingsState.initial(),
    );
  });

  Future<Slider> pumpAndFindWidthSlider(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SettingsBloc>.value(
          value: settingsBloc,
          child: const Scaffold(
            body: PrimaryScrollController.none(child: TextSettingsTab()),
          ),
        ),
      ),
    );
    await tester.pump();

    // סליידר רוחב הטקסט הוא היחיד עם 14 רמות
    final finder = find.byWidgetPredicate(
      (widget) => widget is Slider && widget.max == 14,
    );
    expect(finder, findsOneWidget);
    return tester.widget<Slider>(finder);
  }

  testWidgets('הזזת הסליידר שולחת רמה שלילית, לא פיקסלים', (tester) async {
    final slider = await pumpAndFindWidthSlider(tester);
    slider.onChanged!(4);

    verify(() => settingsBloc.add(const UpdateTextMaxWidth(-4.0))).called(1);
  });

  testWidgets('רמה 0 (רוחב מלא) שולחת 0', (tester) async {
    final slider = await pumpAndFindWidthSlider(tester);
    slider.onChanged!(0);

    verify(() => settingsBloc.add(const UpdateTextMaxWidth(0))).called(1);
  });
}
