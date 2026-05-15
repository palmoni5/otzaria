import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/tools/tools_screen.dart';

void main() {
  group('setActiveToolIdSafely', () {
    setUp(() {
      activeToolIdNotifier.value = null;
    });

    tearDown(() {
      activeToolIdNotifier.value = null;
    });

    testWidgets(
      'עדכון מתוך initState בזמן build של עץ ההורה נדחה ל-post-frame '
      'ומיושם רק בפריים הבא',
      (tester) async {
        // תרחיש הרגרסיה (קומיט 9dafa3427, "הצמדת תוספים לניווט הראשי"):
        // ב-MainWindowScreen קיים ValueListenableBuilder על activeToolIdNotifier
        // (סרגל הניווט). כש-ToolsScreen מורכב בתוך אותו עץ, ה-initState שלו
        // קורא ל-_setSelectedToolId, שמשנה את ה-notifier בזמן שהפריימוורק
        // עדיין באמצע build → markNeedsBuild על מאזין שכבר מורכב → setState-
        // during-build.
        //
        // הטסט מדמה את אותו תרחיש בלי תלות ב-ToolsScreen המלא: ValueListenableBuilder
        // ו-widget שב-initState שלו קורא ל-setActiveToolIdSafely באותו pump.
        // ללא ה-guard, הערך יתעדכן באופן סינכרוני וכבר אחרי pumpWidget המאזין
        // יראה אותו (וגם תיזרק setState-during-build). עם ה-guard, העדכון נדחה.
        String? observed;

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: activeToolIdNotifier,
                  builder: (_, value, __) {
                    observed = value;
                    return const SizedBox.shrink();
                  },
                ),
                const _SetsNotifierFromInitState(toolId: 'builtin.gematria'),
              ],
            ),
          ),
        );

        // בפריים הראשון העדכון נדחה — המאזין עוד לא ראה את הערך החדש.
        expect(
          observed,
          isNull,
          reason: 'setActiveToolIdSafely חייב לדחות עדכון בזמן build phase כדי '
              'למנוע setState-during-build אצל מאזינים שכבר מורכבים.',
        );

        // לאחר post-frame callback הערך מתעדכן והמאזין נבנה מחדש.
        await tester.pump();
        expect(observed, equals('builtin.gematria'));
      },
    );

    testWidgets(
      'עדכון מחוץ לפאזת build מתעדכן באופן סינכרוני',
      (tester) async {
        // pump ריק קודם כדי לסיים את פאזת ה-build הראשונית.
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

        setActiveToolIdSafely('builtin.shamor_zachor');
        expect(activeToolIdNotifier.value, equals('builtin.shamor_zachor'));
      },
    );

    testWidgets(
      'isMounted שמחזיר false מונע את העדכון הנדחה',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: activeToolIdNotifier,
                  builder: (_, __, ___) => const SizedBox.shrink(),
                ),
                const _SetsNotifierFromInitState(
                  toolId: 'builtin.measurement_converter',
                  alwaysUnmounted: true,
                ),
              ],
            ),
          ),
        );

        await tester.pump();
        expect(activeToolIdNotifier.value, isNull);
      },
    );
  });
}

class _SetsNotifierFromInitState extends StatefulWidget {
  const _SetsNotifierFromInitState({
    required this.toolId,
    this.alwaysUnmounted = false,
  });

  final String toolId;
  final bool alwaysUnmounted;

  @override
  State<_SetsNotifierFromInitState> createState() =>
      _SetsNotifierFromInitStateState();
}

class _SetsNotifierFromInitStateState
    extends State<_SetsNotifierFromInitState> {
  @override
  void initState() {
    super.initState();
    setActiveToolIdSafely(
      widget.toolId,
      isMounted: () => widget.alwaysUnmounted ? false : mounted,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
