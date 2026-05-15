import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/feedback/scrollable_positioned_list_scrollbar.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  testWidgets('פס הגלילה שומר רצועה נפרדת מהתוכן כשצריך לגלול', (tester) async {
    final listener = ItemPositionsListener.create();
    final controller = ItemScrollController();
    const contentKey = Key('scroll-content');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrollablePositionedListScrollbar(
            scrollController: controller,
            itemPositionsListener: listener,
            itemCount: 10,
            child: Container(key: contentKey),
          ),
        ),
      ),
    );

    // מדמה תוכן שדורש גלילה — רק 2 פריטים מתוך 10 גלויים.
    (listener.itemPositions as ValueNotifier<Iterable<ItemPosition>>).value =
        const [
      ItemPosition(index: 0, itemLeadingEdge: 0, itemTrailingEdge: 0.5),
      ItemPosition(index: 1, itemLeadingEdge: 0.5, itemTrailingEdge: 1.0),
    ];
    await tester.pump();

    expect(tester.getTopLeft(find.byKey(contentKey)).dx, 12.0);
  });

  testWidgets('פס הגלילה מוסתר כשכל התוכן נראה במסך', (tester) async {
    final listener = ItemPositionsListener.create();
    final controller = ItemScrollController();
    const contentKey = Key('scroll-content');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrollablePositionedListScrollbar(
            scrollController: controller,
            itemPositionsListener: listener,
            itemCount: 2,
            child: Container(key: contentKey),
          ),
        ),
      ),
    );

    // כל הפריטים גלויים בתוך המסך — אין מה לגלול, ולכן ה-12px צריכים להיעלם.
    (listener.itemPositions as ValueNotifier<Iterable<ItemPosition>>).value =
        const [
      ItemPosition(index: 0, itemLeadingEdge: 0, itemTrailingEdge: 0.4),
      ItemPosition(index: 1, itemLeadingEdge: 0.4, itemTrailingEdge: 0.8),
    ];
    await tester.pump();

    expect(tester.getTopLeft(find.byKey(contentKey)).dx, 0.0);
  });

  testWidgets('listener ישן לא מעדכן State אחרי החלפת widget ו-dispose',
      (tester) async {
    final firstListener = ItemPositionsListener.create();
    final secondListener = ItemPositionsListener.create();
    final controller = ItemScrollController();

    Widget build(ItemPositionsListener listener) {
      return MaterialApp(
        home: ScrollablePositionedListScrollbar(
          scrollController: controller,
          itemPositionsListener: listener,
          itemCount: 10,
          child: const SizedBox.expand(),
        ),
      );
    }

    await tester.pumpWidget(build(firstListener));
    await tester.pumpWidget(build(secondListener));

    (secondListener.itemPositions as ValueNotifier<Iterable<ItemPosition>>)
        .value = const [
      ItemPosition(index: 1, itemLeadingEdge: 0, itemTrailingEdge: 0.5),
    ];

    await tester.pumpWidget(const SizedBox.shrink());

    (firstListener.itemPositions as ValueNotifier<Iterable<ItemPosition>>)
        .value = const [
      ItemPosition(index: 1, itemLeadingEdge: 0, itemTrailingEdge: 0.5),
    ];

    expect(tester.takeException(), isNull);
  });
}
