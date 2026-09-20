import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/link_types.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/services/target_line_links_service.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/widgets/commentary/panel_anchor_links.dart';
import 'package:otzaria/widgets/smart_text/smart_text.dart';

/// הקישור שהקטע שלו מוצג בחלונית: שורה 3 בספר "רש״י".
Link _displayed() => Link(
  heRef: 'רש״י על בראשית א, א',
  index1: 1,
  path2: 'רש״י',
  index2: 3,
  connectionType: LinkTypes.commentary,
  targetCategoryId: 7,
);

Link _anchored({
  required int index1,
  required int charStart,
  int? charEnd,
  String? label,
}) => Link(
  heRef: 'בראשית א, א',
  index1: index1,
  path2: 'בראשית',
  index2: 1,
  connectionType: LinkTypes.linker,
  targetCategoryId: 7,
  anchorStart: charStart,
  anchorEnd: charEnd,
  anchorLabel: label,
);

Future<void> _pumpPanel(
  WidgetTester tester, {
  required List<Link> loaded,
  bool enabled = true,
  void Function(OpenedTab)? onOpen,
}) async {
  TargetLineLinksService.instance = TargetLineLinksService(
    loader: (_, _, _) async => loaded,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: PanelAnchoredText(
        link: _displayed(),
        html: 'אבגדהוזחטיכלמנ',
        settings: const RenderSettings(),
        enabled: enabled,
        openBookCallback: onOpen ?? (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _renderedHtml(WidgetTester tester) =>
    tester.widget<SmartTextWidget>(find.byType(SmartTextWidget)).text;

void main() {
  tearDown(TargetLineLinksService.resetInstanceForTesting);

  testWidgets('ציטוט בשורה המוצגת נעטף כקישור לחיץ', (tester) async {
    await _pumpPanel(
      tester,
      loaded: [_anchored(index1: 3, charStart: 2, charEnd: 6)],
    );

    final html = _renderedHtml(tester);
    expect(html, contains('link-anchor-range'));
    expect(html, contains('otzaria://anchor?ref=2_0&range=1'));
  });

  testWidgets('ציטוט בשורה אחרת של אותו ספר אינו מוזרק', (tester) async {
    await _pumpPanel(
      tester,
      loaded: [_anchored(index1: 4, charStart: 2, charEnd: 6)],
    );

    expect(_renderedHtml(tester), 'אבגדהוזחטיכלמנ');
  });

  testWidgets('סמן-אות של מפרש-על אינו מוזרק בחלונית', (tester) async {
    await _pumpPanel(
      tester,
      loaded: [_anchored(index1: 3, charStart: 2, label: 'א')],
    );

    expect(_renderedHtml(tester), 'אבגדהוזחטיכלמנ');
  });

  testWidgets('כיבוי בפרופיל התצוגה מחזיר את הטקסט כמות שהוא', (tester) async {
    await _pumpPanel(
      tester,
      loaded: [_anchored(index1: 3, charStart: 2, charEnd: 6)],
      enabled: false,
    );

    expect(_renderedHtml(tester), 'אבגדהוזחטיכלמנ');
  });
}
