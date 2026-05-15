import 'dart:math';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ScrollablePositionedListScrollbar extends StatefulWidget {
  final ItemScrollController scrollController;
  final ItemPositionsListener itemPositionsListener;
  final int itemCount;
  final Widget child;

  const ScrollablePositionedListScrollbar({
    super.key,
    required this.scrollController,
    required this.itemPositionsListener,
    required this.itemCount,
    required this.child,
  });

  @override
  State<ScrollablePositionedListScrollbar> createState() =>
      _ScrollablePositionedListScrollbarState();
}

class _ScrollablePositionedListScrollbarState
    extends State<ScrollablePositionedListScrollbar> {
  static const double _trackWidth = 12.0;

  double _thumbPosition = 0.0;
  double _thumbHeight = 0.1; // יחס גובה ברירת מחדל
  bool _isDragging = false;
  // ברירת מחדל false כדי שלא נציג את ה-track בספרים קטנים שכל תוכנם נכנס במסך.
  // יתעדכן ל-true ברגע שה-positions מראים שיש פריט מחוץ למסך.
  bool _canScroll = false;

  // להחלקת הקפיצות במיקום
  int _lastFirstIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.itemPositionsListener.itemPositions
        .addListener(_updateScrollPosition);
  }

  @override
  void didUpdateWidget(covariant ScrollablePositionedListScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemPositionsListener != widget.itemPositionsListener) {
      oldWidget.itemPositionsListener.itemPositions
          .removeListener(_updateScrollPosition);
      widget.itemPositionsListener.itemPositions
          .addListener(_updateScrollPosition);
    }
  }

  @override
  void dispose() {
    widget.itemPositionsListener.itemPositions
        .removeListener(_updateScrollPosition);
    super.dispose();
  }

  void _updateScrollPosition() {
    if (!mounted || _isDragging) return;

    final positions = widget.itemPositionsListener.itemPositions.value;
    if (positions.isEmpty || widget.itemCount == 0) return;

    // מציאת האינדקסים הראשונים והאחרונים הנראים, יחד עם הקצוות שלהם —
    // הקצוות נחוצים כדי להחליט אם באמת יש מה לגלול (ראה חישוב _canScroll
    // בהמשך הפונקציה).
    int minIndex = positions.first.index;
    int maxIndex = positions.first.index;
    double leadingAtMin = positions.first.itemLeadingEdge;
    double trailingAtMax = positions.first.itemTrailingEdge;

    for (var position in positions) {
      if (position.index < minIndex) {
        minIndex = position.index;
        leadingAtMin = position.itemLeadingEdge;
      }
      if (position.index > maxIndex) {
        maxIndex = position.index;
        trailingAtMax = position.itemTrailingEdge;
      }
    }

    _lastFirstIndex = minIndex;

    // חישוב גובה הפס ביחס לכמות הפריטים
    // מוסיפים 1 כדי למנוע חילוק ב-0
    final visibleItems = (maxIndex - minIndex + 1);
    final proportion = visibleItems / max(widget.itemCount, 1);

    // גובה מינימלי בפיקסלים ל"אגודל" הגלילה הוא בדרך כלל סביב 40-50 פיקסלים במסכים רגילים
    // אבל כאן אנחנו עובדים באחוזים (0.0 עד 1.0)
    // נניח שגובה המסך הוא H, גובה מינימלי h_min. אחוז מינימלי הוא h_min/H
    // נניח באופן שמרני שרצוי לפחות 5%
    final newHeight = proportion.clamp(0.05, 1.0);

    // חישוב המיקום היחסי (0.0 למעלה, 1.0 למטה)
    // האינדקסים הם 0-based.
    // אם minIndex הוא 0 -> top 0.
    // אם maxIndex הוא itemCount-1 -> bottom 1.0 (בערך)

    final maxScrollableIndex = max(widget.itemCount - visibleItems, 1);
    final newPosition =
        (minIndex / maxScrollableIndex).clamp(0.0, 1.0 - newHeight);

    // כל התוכן נראה אם הפריט הראשון מתחיל בתוך המסך, האחרון מסתיים בתוכו,
    // וכל הפריטים בטווח הזה מיוצגים — במצב כזה אין מה לגלול ואין טעם
    // להציג את הפס.
    final allVisible = minIndex == 0 &&
        maxIndex == widget.itemCount - 1 &&
        leadingAtMin >= 0 &&
        trailingAtMax <= 1.0;

    setState(() {
      _thumbHeight = newHeight;
      _thumbPosition = newPosition;
      _canScroll = !allVisible;
    });
  }

  void _onDragUpdate(double delta, double trackHeight) {
    setState(() {
      _isDragging = true;
      _thumbPosition += delta;
      _thumbPosition = _thumbPosition.clamp(0.0, 1.0 - _thumbHeight);
    });

    final int targetIndex = (_thumbPosition * widget.itemCount).round();

    // אופטימיזציה: לא לקפוץ אם השינוי קטן מדי כדי למנוע ריצוד
    if ((targetIndex - _lastFirstIndex).abs() > widget.itemCount * 0.001) {
      widget.scrollController.jumpTo(index: targetIndex);
      _lastFirstIndex = targetIndex;
    }
  }

  void _onDragEnd() {
    setState(() {
      _isDragging = false;
    });
    // עדכון סופי ליתר ביטחון
    _updateScrollPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (widget.itemCount > 0 && _canScroll)
          SizedBox(
            width: _trackWidth,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackHeight = constraints.maxHeight;
                final thumbPixelHeight = trackHeight * _thumbHeight;
                final thumbPixelTop = trackHeight * _thumbPosition;
                final colorScheme = Theme.of(context).colorScheme;

                return GestureDetector(
                  onVerticalDragStart: (details) {
                    setState(() {
                      _isDragging = true;
                    });
                  },
                  onVerticalDragUpdate: (details) {
                    _onDragUpdate(details.delta.dy / trackHeight, trackHeight);
                  },
                  onVerticalDragEnd: (_) => _onDragEnd(),
                  onTapDown: (details) {
                    // קפיצה לנקודה שנלחצה (אופציונלי, מדמה הקלקה על המסילה)
                    final clickPosition =
                        details.localPosition.dy / trackHeight;
                    double newThumbPos = clickPosition - (_thumbHeight / 2);
                    newThumbPos = newThumbPos.clamp(0.0, 1.0 - _thumbHeight);

                    setState(() {
                      _thumbPosition = newThumbPos;
                    });

                    final int targetIndex =
                        (_thumbPosition * widget.itemCount).round();
                    widget.scrollController.jumpTo(index: targetIndex);
                  },
                  child: Container(
                    color: colorScheme.surface.withValues(alpha: 0.92),
                    child: Stack(
                      children: [
                        // ה"אגודל" (Thumb) עצמו
                        Positioned(
                          top: thumbPixelTop,
                          left: 2, // רווח קטן מהקצה
                          right: 2,
                          height: thumbPixelHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _isDragging
                                  ? colorScheme.primary.withValues(alpha: 0.8)
                                  : colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
