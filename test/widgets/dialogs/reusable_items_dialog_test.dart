import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/dialogs/reusable_items_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ReusableItemsDialog משתמש ב-MediaQuery.of(context).size כדי לחשב את הרוחב.
  // בטסטים `setSurfaceSize` לא תמיד מתפשט ל-MediaQuery של דיאלוגים, לכן עוטפים
  // ידנית ב-MediaQuery עם הגודל הרצוי. הקונטיינר הפנימי של הדיאלוג הוא היחיד
  // עם padding מפורש של 16 (Dialog/Material עוטפים אותו ב-Containers נוספים
  // ללא ה-padding הזה).
  Container findInnerContainer() {
    return find
        .descendant(
          of: find.byType(ReusableItemsDialog),
          matching: find.byType(Container),
        )
        .evaluate()
        .map((e) => e.widget as Container)
        .singleWhere((c) => c.padding == const EdgeInsets.all(16));
  }

  Future<void> pumpDialog(WidgetTester tester, Size mediaSize) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: mediaSize),
        child: const Material(
          child: ReusableItemsDialog(
            title: 'כותרת',
            child: SizedBox.shrink(),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  group('ReusableItemsDialog — רוחב רספונסיבי', () {
    testWidgets('מסך רחב: הדיאלוג מבקש רוחב של 50% מהמסך', (tester) async {
      await pumpDialog(tester, const Size(1200, 800));

      final requested = findInnerContainer().constraints!.maxWidth;
      expect(requested, closeTo(600, 0.5),
          reason: '1200 * 0.5 = 600 — שמירה על ההתנהגות במסך רחב');
    });

    testWidgets('מסך צר: הדיאלוג מבקש רוחב של 95% מהמסך', (tester) async {
      await pumpDialog(tester, const Size(400, 800));

      final requested = findInnerContainer().constraints!.maxWidth;
      expect(requested, closeTo(380, 0.5),
          reason:
              '400 * 0.95 = 380 — בלי תיקון היה 200 (50%) והטקסט היה קורס לתו-לשורה');
    });

    testWidgets('הכותרת מוצגת', (tester) async {
      await pumpDialog(tester, const Size(800, 600));
      expect(find.text('כותרת'), findsOneWidget);
    });
  });
}
