import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/navigation/commentators_filter_header.dart';

void main() {
  testWidgets('חץ החזרה בבחירת מפרשים מצביע החוצה מהכותרת', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: CommentatorsFilterHeader(
              onBack: _noop,
            ),
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(IconButton),
        matching: find.byType(Icon),
      ),
    );

    expect(icon.icon, FluentIcons.arrow_left_24_regular);
  });
}

void _noop() {}
