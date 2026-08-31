@Tags(['manual'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/tools/biographies/biographies_screen.dart';
import 'package:otzaria/tools/biographies/repository/biographies_repository.dart';
import 'package:otzaria/tools/biographies/widgets/biography_card.dart';

/// מריץ את מסך הביוגרפיות על קובץ רילייס אמיתי. ידני בלבד:
/// `flutter test test/tools/biographies_screen_test.dart --tags manual`
/// `--dart-define=BIO_OBF_KEY=<המפתח> --dart-define=BIO_FILE=<נתיב הקובץ>`
void main() {
  const path = String.fromEnvironment('BIO_FILE');

  Widget host(BiographiesRepository repository) => MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: BlocProvider<SettingsBloc>(
        create: (_) => _TestSettingsBloc(SettingsState.initial()),
        child: Scaffold(body: BiographiesScreen(repository: repository)),
      ),
    ),
  );

  testWidgets('מציג ערכים אמיתיים ומסנן בחיפוש', (tester) async {
    final repository = BiographiesRepository(
      updatedPathProvider: () async => path,
    );

    await tester.pumpWidget(host(repository));
    // הפענוח רץ ב-isolate אמיתי, ולכן חייב runAsync ולא pumpAndSettle
    // (שנתקע ממילא על אנימציית הטעינה).
    await tester.runAsync(repository.loadAll);
    await tester.pump();
    await tester.pump();

    // נטענו כרטיסים.
    expect(find.byType(BiographyCard), findsWidgets);

    // חיפוש מצמצם לתוצאות רלוונטיות בלבד.
    await tester.enterText(find.byType(TextField).first, 'אונקלוס');
    await tester.pump();
    expect(find.textContaining('אונקלוס'), findsWidgets);

    // שאילתה חסרת תוצאות מציגה מצב ריק.
    await tester.enterText(find.byType(TextField).first, 'זזזזזזז');
    await tester.pump();
    expect(find.text('לא נמצאו תוצאות'), findsOneWidget);
  }, skip: path.isEmpty);
}

class _TestSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _TestSettingsBloc(super.initialState) {
    on<SettingsEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
