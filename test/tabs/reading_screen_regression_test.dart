import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// טסטי רגרסיה לתיקונים בקובץ `lib/tabs/reading_screen.dart`:
///
/// 1. החלפת `TabBarView` ב-`PageView` עם `ValueKey(tab)` על כל ילד —
///    שומרת על ה-`Element` של טאב פעיל כשטאב לידו נסגר/מוזז, כך
///    שמצב ה-PDF/Bloc לא נטען מחדש (קומיט `74702ae15`).
///
/// 2. שימוש ב-`ValueKey(tab)` (ולא ב-`PageStorageKey(tab)`) על העטיפה
///    החיצונית — מונע התנגשות נתיב PageStorage בין `ScrollablePositionedList`
///    הפנימי, שכותב `ItemPosition`, לבין `PageView` הפנימי של `TabBarView`
///    בחלונית השמאלית, שקורא `double?` מאותו תא ונופל ב-cast error.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reading_screen — שימור Element של ילד טאב בהזזת טאב סמוך', () {
    testWidgets(
      'reconciliation לפי ValueKey לא מאתחל מחדש ילד כשנסגר ילד שלפניו',
      (tester) async {
        // הבדיקה ברמת ה-reconciliation של רשימת ילדים עם מפתחות. זוהי
        // אותה לוגיקה שמשמשת את ה-`SliverChildListDelegate` של ה-PageView
        // ב-reading_screen — Element נשמר על פי המפתח של הילד, לא על פי
        // האינדקס שלו. הטסט משתמש ב-`Stack` רק כי הוא מאלץ את כל הילדים
        // להבנות בעץ (`PageView` מבנה רק את העמוד הפעיל ולכן Elementים
        // של עמודים אחרים פשוט לא קיימים — אין מה לשמר). הקריטריון הוא
        // אותו קריטריון: ValueKey יציב לכל טאב.
        _InitCounter.reset();

        Widget build(List<String> labels) {
          return MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  for (final label in labels)
                    _InitCounter(key: ValueKey(label), label: label),
                ],
              ),
            ),
          );
        }

        await tester.pumpWidget(build(['a', 'b', 'c']));
        await tester.pumpAndSettle();
        expect(_InitCounter.counts, {'a': 1, 'b': 1, 'c': 1},
            reason: 'כל ילד עבר initState פעם אחת בלבד בעת ה-mount הראשון');

        // הסרת 'a' מקדמת הרשימה — מדמה סגירה/הזזה של טאב משמאל לטאב הפעיל.
        // אם reconciliation היה לפי אינדקס (כפי שמתנהג ה-`KeyedSubtree.wrap`
        // הפנימי של `TabBarView`), 'b' היה מקבל את האינדקס הקודם של 'a'
        // ועובר remount. עם `ValueKey('b')` המפתח לא משתנה — Element נשמר.
        await tester.pumpWidget(build(['b', 'c']));
        await tester.pumpAndSettle();

        expect(_InitCounter.counts, {'a': 1, 'b': 1, 'c': 1},
            reason: 'אסור שייקרא initState נוסף ל-"b" או ל-"c"');
      },
    );

    testWidgets(
      'index-keyed wrappers (כמו TabBarView) זורקים State בהסרת טאב מהקדמה',
      (tester) async {
        // טסט "שלילה" — משחזר את שורש הבאג שתואר בקומיט `74702ae15`:
        // "TabBarView עוטף ילדים ב-KeyedSubtree.wrap הפנימי שמקבע מפתח לפי
        // אינדקס. בהזזה/סגירה של טאב לפני ה-PDF, ה-reconciliation מצליח
        // חיצונית אך נכשל ב-type-mismatch בילד הפנימי ויוצר מחדש את ה-State."
        // כאן אנו מדמים את אותו דפוס ידנית: עטיפת KeyedSubtree עם
        // `ValueKey<int>(index)` סביב כל ילד.
        _PdfMock.initCount = 0;

        Widget buildIndexKeyed(List<Widget> children) {
          return MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  for (var i = 0; i < children.length; i++)
                    KeyedSubtree(key: ValueKey<int>(i), child: children[i]),
                ],
              ),
            ),
          );
        }

        await tester.pumpWidget(buildIndexKeyed([
          const _InitCounter(label: 'text'),
          const _PdfMock(),
        ]));
        await tester.pumpAndSettle();
        expect(_PdfMock.initCount, 1);

        // הסרת הילד הראשון. ה-KeyedSubtree במיקום 0 שומר על אותו מפתח
        // חיצוני (`ValueKey<int>(0)`) — כך שה-Element החיצוני שלו ממוחזר,
        // אבל סוג הילד הפנימי משתנה מ-_InitCounter ל-_PdfMock → ה-Element
        // הפנימי מוחלף, וה-State של _PdfMock נזרק → initState נקרא שוב.
        await tester.pumpWidget(buildIndexKeyed([
          const _PdfMock(),
        ]));
        await tester.pumpAndSettle();

        expect(_PdfMock.initCount, 2,
            reason: 'index-keyed wrap (כפי שעושה TabBarView) גורם ל-_PdfMock '
                'לאבד State כשטאב לפניו נסגר. זו הרגרסיה של 74702ae15.');
      },
    );

    testWidgets(
      'value-keyed wrappers (התיקון) שומרים State גם בהסרת טאב מהקדמה',
      (tester) async {
        // משלים את הטסט הקודם: אותו מבנה בדיוק, אבל עם `ValueKey(tag)` יציב
        // על העטיפה במקום `ValueKey<int>(index)`. עכשיו ה-Element עוקב אחרי
        // המפתח, לא אחרי המיקום — בדיוק מה שהקומיט עשה כשעטף את הילדים
        // ב-`ValueKey(tab)`.
        _PdfMock.initCount = 0;

        Widget buildValueKeyed(List<(String tag, Widget child)> children) {
          return MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  for (final (tag, child) in children)
                    KeyedSubtree(key: ValueKey(tag), child: child),
                ],
              ),
            ),
          );
        }

        await tester.pumpWidget(buildValueKeyed([
          ('text', const _InitCounter(label: 'text')),
          ('pdf', const _PdfMock()),
        ]));
        await tester.pumpAndSettle();
        expect(_PdfMock.initCount, 1);

        await tester.pumpWidget(buildValueKeyed([
          ('pdf', const _PdfMock()),
        ]));
        await tester.pumpAndSettle();

        expect(_PdfMock.initCount, 1,
            reason: 'עם ValueKey יציב, ה-Element של "pdf" עוקב אחרי המפתח גם '
                'כשטאב "text" שלפניו נסגר. ה-State נשמר.');
      },
    );
  });

  group('reading_screen — מניעת התנגשות נתיב PageStorage', () {
    Widget buildTree({
      required Key wrapperKey,
      required bool showPageView,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: KeyedSubtree(
            key: wrapperKey,
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: ScrollablePositionedList.builder(
                    itemCount: 50,
                    itemBuilder: (_, i) => SizedBox(
                      height: 40,
                      child: Text('item-$i'),
                    ),
                  ),
                ),
                if (showPageView)
                  SizedBox(
                    height: 200,
                    child: PageView(
                      children: const [
                        Center(child: Text('p0')),
                        Center(child: Text('p1')),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    Future<Object?> scrollListThenMountPageView(
      WidgetTester tester, {
      required Key wrapperKey,
    }) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // שלב 1: עליית ה-SPL לבדה.
      await tester.pumpWidget(
        buildTree(wrapperKey: wrapperKey, showPageView: false),
      );
      await tester.pumpAndSettle();

      // שלב 2: גלילה שמפעילה
      // `PageStorage.of(context).writeState(context, itemPosition)`
      // (שורה 646 בחבילת scrollable_positioned_list — כותב `ItemPosition`).
      await tester.drag(find.text('item-0'), const Offset(0, -200));
      await tester.pumpAndSettle();

      // שלב 3: הוספת ה-PageView לעץ — fresh mount. הבנאי של
      // `_PagePosition` קורא `restoreScrollOffset` שמושך מ-PageStorage
      // ומבצע cast ל-`double?`. אם הנתיב של ה-PageView מתנגש עם זה של
      // ה-SPL, התא מכיל `ItemPosition` והקריסה מתרחשת כאן.
      await tester.pumpWidget(
        buildTree(wrapperKey: wrapperKey, showPageView: true),
      );
      await tester.pumpAndSettle();

      return tester.takeException();
    }

    testWidgets(
      'עטיפה עם ValueKey לא קורסת לאחר כתיבת ItemPosition ל-PageStorage',
      (tester) async {
        final exception = await scrollListThenMountPageView(
          tester,
          wrapperKey: const ValueKey('tab-1'),
        );
        expect(exception, isNull,
            reason: 'ValueKey לא משתתפת בנתיב PageStorage, לכן ה-SPL '
                'וה-PageView הפנימי לא חולקים תא ולא מתרחשת התנגשות');
      },
    );

    testWidgets(
      'עטיפה עם PageStorageKey מובילה ל-cast error (תרחיש הרגרסיה)',
      (tester) async {
        // טסט "שלילה" — מתעד בדיוק את הסיבה ש-PageStorageKey הוחלף ב-ValueKey.
        // אם מישהו יחזיר את העטיפה ל-PageStorageKey, הטסט בכוונה ינפץ.
        final exception = await scrollListThenMountPageView(
          tester,
          wrapperKey: const PageStorageKey('tab-1'),
        );
        expect(exception, isA<TypeError>(),
            reason: 'PageStorageKey יוצרת נתיב PageStorage משותף בין SPL '
                'ל-PageView הפנימי → ItemPosition נקרא במקום double?');
        expect(exception.toString(), contains('ItemPosition'));
      },
    );
  });
}

/// וידג'ט בדיקה שסופר כמה פעמים נקרא ה-initState שלו לכל label.
class _InitCounter extends StatefulWidget {
  final String label;
  const _InitCounter({super.key, required this.label});

  static final Map<String, int> counts = {};
  static void reset() => counts.clear();

  @override
  State<_InitCounter> createState() => _InitCounterState();
}

class _InitCounterState extends State<_InitCounter> {
  @override
  void initState() {
    super.initState();
    _InitCounter.counts[widget.label] =
        (_InitCounter.counts[widget.label] ?? 0) + 1;
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

/// וידג'ט עם runtimeType שונה כדי לדמות PdfBookScreen ↔ TextBookViewerBloc:
/// בלי מפתחות, החלפת טאב טקסט בטאב PDF באותו מיקום גורמת ל-remount כי
/// ה-runtimeType שונה. עם `ValueKey(tab)`, ה-Element עוקב אחרי המפתח.
class _PdfMock extends StatefulWidget {
  const _PdfMock();

  static int initCount = 0;

  @override
  State<_PdfMock> createState() => _PdfMockState();
}

class _PdfMockState extends State<_PdfMock> {
  @override
  void initState() {
    super.initState();
    _PdfMock.initCount += 1;
  }

  @override
  Widget build(BuildContext context) => const Text('pdf');
}
