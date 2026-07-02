import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/widgets/misc/exit_fullscreen_button.dart';

void main() {
  testWidgets('לחצן היציאה מוצג באופן קבוע עם tooltip ואייקון', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 8,
                right: 8,
                child: ExitFullscreenButton(),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byTooltip('צא ממסך מלא'), findsOneWidget);
    expect(
      find.byIcon(FluentIcons.full_screen_minimize_24_regular),
      findsOneWidget,
    );

    // נשאר מוצג גם לאחר זמן — הלחצן קבוע ואינו נעלם.
    await tester.pump(const Duration(seconds: 5));
    expect(find.byTooltip('צא ממסך מלא'), findsOneWidget);
  });
}
