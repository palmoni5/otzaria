import 'package:flutter/foundation.dart';

/// מסנכרן בחירת טקסט בין כמה אזורי SelectionArea באותו מסך.
///
/// ל-SelectionArea של Flutter אין API ישיר ל"נקה בחירה באזור אחר",
/// לכן כל אזור מאזין לגרסה (`revision`) ומבצע rebuild מקומי כשהבחירה
/// עברה לאזור אחר.
class SelectionSyncController extends ChangeNotifier {
  int _revision = 0;
  Object? _activeOwner;

  int get revision => _revision;
  Object? get activeOwner => _activeOwner;

  void activate(Object owner) {
    if (identical(_activeOwner, owner)) {
      return;
    }

    _activeOwner = owner;
    _revision++;
    notifyListeners();
  }

  void clear(Object owner) {
    if (!identical(_activeOwner, owner)) {
      return;
    }

    _activeOwner = null;
    _revision++;
    notifyListeners();
  }
}

/// קובע האם צריך לבנות מחדש את ה-SelectionArea של אזור בתגובה לשינוי בעלות
/// ב-[SelectionSyncController]. הבנייה מחדש מתבצעת על-ידי קידום ערך revision
/// ששימש כ-`ValueKey` של ה-SelectionArea — ולכן היא משחזרת את כל עץ הצאצאים.
///
/// מטרת הבנייה היא לנקות בחירה ויזואלית של ה-SelectionArea שלנו כשאזור אחר
/// תפס בעלות. אם אין לנו בחירה משלנו — אין מה לנקות, ו-rebuild רק יהרוס
/// את עץ הצאצאים שלא לצורך (במצב 'מפרשים מתחת' זה גורם לטעינה מחדש של
/// המפרשים בכל פעם שמנסים לסמן בהם טקסט; ב'צורת הדף' זה גורם לאיפוס
/// סטייט פנימי של הצאצאים).
bool shouldRebuildSelectionAreaOnExternalChange({
  required Object? activeOwner,
  required Object selfOwner,
  required bool hasOwnSelection,
}) {
  if (activeOwner == null) return false;
  if (identical(activeOwner, selfOwner)) return false;
  return hasOwnSelection;
}
