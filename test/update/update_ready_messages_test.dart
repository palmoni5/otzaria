import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/messages/library_messages.dart';
import 'package:otzaria/update/hebrew_update_widgets.dart';
import 'package:updat/updat.dart';

Widget _chip({required bool awaitingClose}) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: hebrewFlatChip(
        context: context,
        awaitingClose: awaitingClose,
        latestVersion: '0.10.2',
        appVersion: '0.10.1',
        status: UpdatStatus.readyToInstall,
        checkForUpdate: () {},
        openDialog: () {},
        startUpdate: () {},
        launchInstaller: () async {},
        dismissUpdate: () {},
      ),
    ),
  ),
);

void main() {
  group('נוסח העדכון המצומצם לפני האישור', () {
    test('מצביע על הכפתור כמתחיל את ההתקנה', () {
      expect(
        LibraryMessages.smallUpdateDialogContent,
        contains(LibraryMessages.smallUpdateDialogConfirm),
      );
    });

    // המעדכן החיצוני משוגר רק באישור, ולכן הבטחה כזאת לפניו היא שקר.
    test('אינו מבטיח שסגירה ידנית משלימה את העדכון', () {
      expect(
        LibraryMessages.smallUpdateDialogContent,
        isNot(contains('יושלם מעצמו')),
      );
      expect(
        LibraryMessages.smallUpdateDialogContent,
        isNot(contains('סגור את אוצריא לגמרי')),
      );
    });

    testWidgets('הצ\'יפ במצב "מוכן להתקנה" אינו משתנה', (tester) async {
      await tester.pumpWidget(_chip(awaitingClose: false));
      expect(find.text('מוכן להתקנה'), findsOneWidget);
      expect(
        find.text(LibraryMessages.smallUpdateAwaitingCloseChip),
        findsNothing,
      );
    });
  });

  group('נוסח העדכון אחרי האישור, כשהתהליך עוד חי', () {
    test('רק כאן נאמר שהעדכון יושלם מעצמו בסגירה', () {
      expect(
        LibraryMessages.smallUpdateAwaitingCloseMessage,
        contains('יושלם מעצמו'),
      );
    });

    testWidgets('הצ\'יפ מבקש לסגור את החלונות שנותרו', (tester) async {
      await tester.pumpWidget(_chip(awaitingClose: true));
      expect(
        find.text(LibraryMessages.smallUpdateAwaitingCloseChip),
        findsOneWidget,
      );
      expect(find.text('מוכן להתקנה'), findsNothing);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, LibraryMessages.smallUpdateAwaitingCloseMessage);
    });
  });
}
