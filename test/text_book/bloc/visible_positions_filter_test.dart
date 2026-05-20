import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  group('TextBookBloc.filterBarelyVisiblePositionsForTesting', () {
    test('שומר על position יחיד גם אם גלוי מעט (אין fallback אחר)', () {
      // אחרי גלילה לתחילת/סוף הספר ייתכן שיש רק position אחד גלוי, גם אם
      // גלוי חלקית. לא נסיר אותו - אין מה להחזיר במקום.
      final positions = [
        const ItemPosition(
          index: 5,
          itemLeadingEdge: -2,
          itemTrailingEdge: 0.05,
        ),
      ];

      final filtered =
          TextBookBloc.filterBarelyVisiblePositionsForTesting(positions);

      expect(filtered.length, 1);
      expect(filtered.first.index, 5);
    });

    test('מסיר position שמסיים ב-5% העליונים של ה-viewport', () {
      // הסיטואציה המדויקת אחרי scrollToSourceLine עם alignment=0.05:
      // הקטע הקודם משתרע מ-itemLeadingEdge=-2 עד itemTrailingEdge=0.05
      // (5% מהמסך עליון), בעוד הקטע אליו ניווטו תופס את שאר המסך.
      final positions = [
        const ItemPosition(
          index: 99,
          itemLeadingEdge: -2,
          itemTrailingEdge: 0.05,
        ),
        const ItemPosition(
          index: 100,
          itemLeadingEdge: 0.05,
          itemTrailingEdge: 0.95,
        ),
        const ItemPosition(
          index: 101,
          itemLeadingEdge: 0.95,
          itemTrailingEdge: 1.5,
        ),
      ];

      final filtered =
          TextBookBloc.filterBarelyVisiblePositionsForTesting(positions);

      expect(filtered.map((p) => p.index), [100]);
    });

    test('שומר על segment גדול חצי-גלוי (visibility ratio > 15%)', () {
      // segment שמשתרע מ-leadingEdge=-0.5 עד trailingEdge=0.5: 50% מה-extent
      // גלוי - נשמר.
      final positions = [
        const ItemPosition(
          index: 10,
          itemLeadingEdge: -0.5,
          itemTrailingEdge: 0.5,
        ),
        const ItemPosition(
          index: 11,
          itemLeadingEdge: 0.5,
          itemTrailingEdge: 1.5,
        ),
      ];

      final filtered =
          TextBookBloc.filterBarelyVisiblePositionsForTesting(positions);

      expect(filtered.length, 2);
      expect(filtered.map((p) => p.index), [10, 11]);
    });

    test('שומר על שורה קצרה הגלויה במלואה גם אם תופסת מעט מה-viewport', () {
      // במצב לא-רציף, שורה קצרה תופסת רק ~3% מה-viewport. כל ה-extent גלוי,
      // visibilityRatio = 100% > 15% - תיכלל.
      final positions = [
        const ItemPosition(
          index: 50,
          itemLeadingEdge: 0.02,
          itemTrailingEdge: 0.05,
        ),
        const ItemPosition(
          index: 51,
          itemLeadingEdge: 0.05,
          itemTrailingEdge: 0.95,
        ),
      ];

      final filtered =
          TextBookBloc.filterBarelyVisiblePositionsForTesting(positions);

      expect(filtered.length, 2);
    });

    test('מסיר גם position שמתחיל ב-95% התחתונים של ה-viewport', () {
      // הסימטריה ההפוכה: segment שמתחיל ב-leadingEdge=0.97 ונמשך החוצה - גלוי
      // רק 3% מה-extent שלו - יוסר.
      final positions = [
        const ItemPosition(
          index: 100,
          itemLeadingEdge: 0.05,
          itemTrailingEdge: 0.97,
        ),
        const ItemPosition(
          index: 101,
          itemLeadingEdge: 0.97,
          itemTrailingEdge: 2,
        ),
      ];

      final filtered =
          TextBookBloc.filterBarelyVisiblePositionsForTesting(positions);

      expect(filtered.map((p) => p.index), [100]);
    });

    test('fallback: אם כל ה-positions מתחת לסף, חוזרים למקור', () {
      // edge case שלא אמור לקרות בפועל - שני positions גלויים פחות מ-15%.
      // כדי לא להחזיר רשימה ריקה (שתשבש visibleIndices לגמרי), חוזרים למקור.
      final positions = [
        const ItemPosition(
          index: 1,
          itemLeadingEdge: -10,
          itemTrailingEdge: 0.05,
        ),
        const ItemPosition(
          index: 2,
          itemLeadingEdge: 0.95,
          itemTrailingEdge: 10,
        ),
      ];

      final filtered =
          TextBookBloc.filterBarelyVisiblePositionsForTesting(positions);

      expect(filtered.length, 2);
    });
  });
}
