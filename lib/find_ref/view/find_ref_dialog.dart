import 'dart:async';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/find_ref/bloc/find_ref_bloc.dart';
import 'package:otzaria/find_ref/bloc/find_ref_event.dart';
import 'package:otzaria/find_ref/bloc/find_ref_state.dart';
import 'package:otzaria/find_ref/repository/db_reference_result.dart';
import 'package:otzaria/core/focus_repository.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/utils/navigation/open_book.dart';
import 'package:otzaria/tour/tour_target_keys.dart';
import 'package:otzaria/library/view/grid_items.dart';
import 'package:otzaria/widgets/text/rtl_text_field.dart';

class FindRefDialog extends StatefulWidget {
  const FindRefDialog({super.key});

  /// מפתח הגדרה לשמירת מצב הטוגל "כלול ספרים אישיים" בין פתיחות הדיאלוג.
  static const String _keyIncludePersonalBooks =
      'key-find-ref-include-personal-books';

  @override
  State<FindRefDialog> createState() => _FindRefDialogState();
}

/// רשומת מפרש מוכנה לפתיחה ישירה ללא שאילתות נוספות.
/// נוצרת בעת טעינת רשימת המפרשים — מאחדת את ה-`title` ו-`targetSegment`
/// מה-DB עם ה-[Book] המתאים מתוך הספרייה.
///
/// `targetSegment` הוא ה-`targetLineIndex` שהחזיר ה-DB — המיקום המקביל הראשון
/// בספר המפרש על פני הקטע. הוא nullable רק כאמצעי הגנה (row חריג בלי
/// `targetLineIndex`); במקרה כזה הקליק נופל לתחילת ספר המפרש (segment 0).
class _CommentatorEntry {
  final String title;
  final int? targetSegment;
  final Book book;

  const _CommentatorEntry({
    required this.title,
    required this.targetSegment,
    required this.book,
  });
}

/// מאתר את ה-`Book` הנכון בעץ הספרייה לפי [bookId] אם נמסר, ולפי [title]
/// אם לא. הסיבה: שני ספרים יכולים לחלוק כותרת זהה (למשל גרסאות שונות של
/// פירוש), וה-link שייצא משאילתת המפרשים יודע בדיוק לאיזה ספר ללכת —
/// פתרון רק לפי title היה פותח את הראשון שנמצא בעץ.
Book? _resolveCommentatorBook(
  Category library,
  String title, {
  required int? bookId,
}) {
  if (bookId != null && bookId > 0) {
    final byId = _findBookInLibraryById(library, bookId);
    if (byId != null) return byId;
  }
  // fallback ל-title (תאימות לאחור עם DB שלא מחזיר targetBookId).
  return _findBookInLibraryByTitle(library, title, preferTextBook: true);
}

Book? _findBookInLibraryById(Category category, int bookId) {
  for (final b in category.books) {
    if (b.id == bookId) return b;
  }
  for (final subCat in category.subCategories) {
    final found = _findBookInLibraryById(subCat, bookId);
    if (found != null) return found;
  }
  return null;
}

Book? _findBookInLibraryByTitle(Category category, String title,
    {bool preferTextBook = false}) {
  // עוברים פעמיים אם preferTextBook: ראשונה — רק TextBook; שנייה — כל סוג.
  for (final passOnlyText in preferTextBook ? [true, false] : [false]) {
    final result = _findBookInLibraryByTitlePass(category, title,
        onlyTextBook: passOnlyText);
    if (result != null) return result;
  }
  return null;
}

Book? _findBookInLibraryByTitlePass(Category category, String title,
    {required bool onlyTextBook}) {
  for (final b in category.books) {
    if (b.title != title) continue;
    if (onlyTextBook && b is! TextBook) continue;
    return b;
  }
  for (final subCat in category.subCategories) {
    final found = _findBookInLibraryByTitlePass(subCat, title,
        onlyTextBook: onlyTextBook);
    if (found != null) return found;
  }
  return null;
}

class _FindRefDialogState extends State<FindRefDialog> {
  int _selectedIndex = 0;
  bool _includePersonalBooks = Settings.getValue<bool>(
        FindRefDialog._keyIncludePersonalBooks,
        defaultValue: false,
      ) ??
      false;
  final Map<int, GlobalKey> _itemKeys = {};
  final Map<int, GlobalKey> _commentatorsButtonKeys = {};
  // המפתח כולל את כל הפרמטרים המבדילים בין refs (bookId/sourceLineId/isAltToc/
  // level/segment) — TOC רגיל ו-AltToc יכולים לחלוק שורת התחלה ולחשב טווח שונה.
  // value=null → טעינה בתהליך.
  // value=[] → אין מפרשים זמינים (לא יוצג כפתור).
  // value=[...] → רשומות מוכנות לפתיחה ישירה (כולל targetSegment ו-Book).
  final Map<String, List<_CommentatorEntry>?> _commentatorsByRef = {};
  final ScrollController _resultsScrollController = ScrollController();
  // `true` כשיש תוצאות מתחת לאזור הנראה. מעודכן משני מקורות:
  //   1. listener על ה-ScrollController — מטפל בגלילה ע"י המשתמש.
  //   2. NotificationListener<ScrollMetricsNotification> — מטפל בחיבור ראשון
  //      של ה-ListView ובשינוי maxScrollExtent (סט תוצאות חדש).
  // ScrollController.attach לבדו לא קורא notifyListeners, ולכן בלי ה-
  // metrics notification ה-arrow היה נשאר מוסתר עד גלילה ידנית.
  final ValueNotifier<bool> _hasMoreBelow = ValueNotifier<bool>(false);
  FocusRestorer? _focusRestorer;

  @override
  void initState() {
    super.initState();

    // בחירת הטקסט הקיים כאשר חוזרים למסך
    // מבוצע מיד ולא ב-postFrameCallback כדי למנוע אובדן פוקוס באנדרואיד
    final controller = FocusRepository().findRefSearchController;
    if (controller.text.isNotEmpty) {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    }

    // רישום כ-active restorer כדי שהדיאלוג יקבל שחזור פוקוס לאחר אירועי חלון
    _focusRestorer = FocusRepository().registerActiveRestorer(
      restore: () {
        if (mounted) FocusRepository().findRefSearchFocusNode.requestFocus();
      },
      canRestore: () =>
          mounted &&
          FocusRepository().findRefSearchFocusNode.canRequestFocus &&
          (ModalRoute.of(context)?.isCurrent ?? false),
    );

    // listener מטפל בגלילה ידנית של המשתמש. עבור חיבור ראשון ולכל שינוי
    // ב-maxScrollExtent (סט תוצאות חדש) משתמשים ב-NotificationListener
    // ליד ה-ListView (ב-build).
    _resultsScrollController.addListener(_updateHasMoreBelow);
  }

  @override
  void dispose() {
    _resultsScrollController.removeListener(_updateHasMoreBelow);
    _resultsScrollController.dispose();
    _hasMoreBelow.dispose();
    final restorer = _focusRestorer;
    if (restorer != null) FocusRepository().unregisterActiveRestorer(restorer);
    super.dispose();
  }

  /// מעדכן את [_hasMoreBelow] לפי המצב הנוכחי של ה-ScrollController.
  /// בטוח לקריאה בכל זמן — הוא חסום על `hasClients` ועל `hasContentDimensions`.
  void _updateHasMoreBelow() {
    final bool next;
    if (!_resultsScrollController.hasClients) {
      next = false;
    } else {
      final pos = _resultsScrollController.position;
      // hasContentDimensions=false לפני שה-ListView סיים מדידה ראשונית.
      next = pos.hasContentDimensions &&
          // 8 פיקסלים של סף — מונע flicker כשהמשתמש כמעט בתחתית.
          pos.maxScrollExtent - pos.pixels > 8;
    }
    if (_hasMoreBelow.value != next) _hasMoreBelow.value = next;
  }

  GlobalKey _getKeyForIndex(int index) {
    if (!_itemKeys.containsKey(index)) {
      _itemKeys[index] = GlobalKey();
    }
    return _itemKeys[index]!;
  }

  GlobalKey _getCommentatorsButtonKey(int index) {
    if (!_commentatorsButtonKeys.containsKey(index)) {
      _commentatorsButtonKeys[index] = GlobalKey();
    }
    return _commentatorsButtonKeys[index]!;
  }

  String _commentatorsKey(DbReferenceResult ref) =>
      '${ref.bookId}:${ref.sourceLineId}:${ref.isAltToc ? 1 : 0}'
      ':${ref.tocLevel}:${ref.segment.toInt()}';

  /// טוען את רשימת המפרשים ל-[ref] ברקע אם עוד לא נטענה, יחד עם ה-[Book]
  /// המתאים לכל מפרש. רשומות מלאות נשמרות ב-[_commentatorsByRef] כך שהקליק
  /// על מפרש יוכל לפתוח אותו ישירות, בלי `await` וללא שאילתות.
  void _ensureCommentatorsLoaded(DbReferenceResult ref) {
    final key = _commentatorsKey(ref);
    if (_commentatorsByRef.containsKey(key)) return; // נטען / בתהליך טעינה
    _commentatorsByRef[key] = null; // sentinel: בתהליך
    final repository = context.read<FindRefBloc>().findRefRepository;
    () async {
      try {
        final dbEntries = await repository.getCommentatorsForResult(ref);
        if (!mounted) return;
        if (dbEntries.isEmpty) {
          setState(() {
            _commentatorsByRef[key] = const [];
          });
          return;
        }
        // pre-resolve של ה-Book עבור כל מפרש כדי שהקליק יהיה סינכרוני.
        // `library` מוחזק בקאש ב-DataRepository.
        final library = await DataRepository.instance.library;
        if (!mounted) return;
        final entries = <_CommentatorEntry>[
          for (final e in dbEntries)
            _CommentatorEntry(
              title: e.title,
              targetSegment: e.targetSegment,
              // פתרון לפי `bookId` כשזמין כדי שלא ייפתח ספר בעל אותה כותרת
              // אך מזהה אחר; ה-fallback ל-title שומר על תאימות.
              book:
                  _resolveCommentatorBook(library, e.title, bookId: e.bookId) ??
                      TextBook(title: e.title),
            ),
        ];
        setState(() {
          _commentatorsByRef[key] = entries;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _commentatorsByRef[key] = const [];
        });
      }
    }();
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _getKeyForIndex(_selectedIndex);
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: 0.5, // מרכז המסך
        );
      }
    });
  }

  /// חץ קטן באותה שורה כמו "סגור" שמופיע כשיש תוצאות מתחת לאזור הנראה.
  /// קליק גולל לסוף הרשימה. ה-IconButton נשאר קבוע במקום — רק ה-opacity
  /// משתנה — כך שגודל הדיאלוג לא משתנה כשהחץ נכבה/נדלק.
  ///
  /// המקור הסינגלטוני של "האם יש יותר למטה" הוא [_hasMoreBelow], שמעודכן
  /// משני נקודות (ראה השדה לפרטים).
  Widget _buildScrollToEndArrow() {
    return ValueListenableBuilder<bool>(
      valueListenable: _hasMoreBelow,
      builder: (context, hasMore, _) {
        return AnimatedOpacity(
          opacity: hasMore ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: !hasMore,
            child: IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(FluentIcons.chevron_down_24_regular),
              tooltip: 'find_ref.scroll_to_end_tooltip'.tr(),
              onPressed: () {
                _resultsScrollController.animateTo(
                  _resultsScrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// פותח את התוצאה.
  ///
  /// [initialCommentators] סמנטיקה:
  ///   null  → ברירת מחדל: history fallback (התנהגות onTap הרגילה).
  ///   []    → bypass מפורש: ללא מפרשים, גם אם בעבר היו (= "פתח ללא מפרש").
  ///   [...] → רשימה מפורשת (= "פתח עם רש"י").
  Future<void> _openRef(
    DbReferenceResult ref, {
    List<String>? initialCommentators,
  }) async {
    Book? book;

    if (ref.isPdf && ref.filePath.isNotEmpty) {
      // Use filePath directly — library search may return a same-titled text book
      book = PdfBook(title: ref.title, path: ref.filePath);
    } else {
      try {
        final library = await DataRepository.instance.library;
        // ספרים מסוימים (תלמוד בבלי וכו') מופיעים ב-library כ-PdfBook גם כשה-DB
        // מכיר אותם כ-txt. אם המשתמש ביקש מפרש מסוים — חייבים TextBookTab,
        // כי PdfBookTab אינו מקבל commentators כלל.
        final needsTextBook =
            initialCommentators != null && initialCommentators.isNotEmpty;
        // ספרים אישיים: ה-`bookId` שלהם שייך ל-user_books.db ואין לו תאומים
        // ב-library object, לכן ניפול ל-title; ספר רשמי עם `bookId > 0`
        // נפתח דרך ה-id כדי שלא יחליף שני ספרים בעלי אותה כותרת.
        final officialBookId =
            (ref.bookId > 0 && !ref.isUserBook) ? ref.bookId : null;
        book = _findBookInLibraryByIdThenTitle(library, ref.title,
            bookId: officialBookId, preferTextBook: needsTextBook);
      } catch (e) {
        debugPrint('Error searching library: $e');
      }
      book ??= TextBook(title: ref.title);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    openBook(context, book, ref.segment.toInt(), '',
        ignoreHistory: ref.isPdf,
        requiresStableLayout: ref.isPdf,
        initialCommentators: initialCommentators);
  }

  /// פותח תפריט עם רשימת המפרשים הזמינים (כבר preloaded — כולל `Book` לכל
  /// רשומה). בחירה פותחת את ספר המפרש ישירות במיקומו (ראה [_openCommentator]).
  Future<void> _showCommentatorsMenu(
    GlobalKey buttonKey,
    List<_CommentatorEntry> commentators,
  ) async {
    if (commentators.isEmpty) return;

    final buttonContext = buttonKey.currentContext;
    if (buttonContext == null || !buttonContext.mounted) return;

    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = buttonContext.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero),
        ancestor: overlayBox);

    // אנו רוצים שה-popup ייפתח לכיוון שמאל פיזית: הקצה הימני של ה-popup
    // יסיים בקצה השמאלי של ה-button (=topLeft.dx) וה-popup יתפשט שמאלה.
    // ב-_PopupMenuRouteLayout, fork-1 נבחר כאשר position.left > position.right
    // ואז `x = size.width - position.right - childSize.width`. לכן:
    //   position.right = overlayWidth - topLeft.dx → popup.right == button.left
    //   position.left  = overlayWidth (max possible) → ensures fork-1
    final position = RelativeRect.fromLTRB(
      overlayBox.size.width.toDouble(),
      bottomRight.dy,
      overlayBox.size.width - topLeft.dx,
      overlayBox.size.height - bottomRight.dy,
    );

    final selected = await showMenu<_CommentatorEntry>(
      context: context,
      position: position,
      constraints: const BoxConstraints(maxHeight: 400, minWidth: 220),
      items: [
        for (final e in commentators)
          PopupMenuItem<_CommentatorEntry>(
            value: e,
            child: Text(
              e.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );

    if (selected == null || !mounted) return;
    _openCommentator(selected);
  }

  /// פותח את ספר המפרש מתוך רשומה שהוכנה מראש: ה-`book` כבר ידוע, וה-
  /// `targetSegment` נלקח מה-[entry] (ה-`targetLineIndex` של ה-DB). אם חסר
  /// (row חריג) נפתח בתחילת ספר המפרש — לא ב-`ref.segment`, שהוא אינדקס בספר
  /// המקור וחסר משמעות בספר המפרש. הקליק סינכרוני לחלוטין — אין `await`, אין
  /// שאילתות DB ואין מעבר על עץ הספרייה בזמן הקליק.
  void _openCommentator(_CommentatorEntry entry) {
    final segment = entry.targetSegment ?? 0;
    Navigator.of(context).pop();
    openBook(context, entry.book, segment, '');
  }

  /// מחפש ספר ב-[category] לפי [bookId] כשנמסר, ונופל ל-[title] אם לא נמצא.
  /// פתרון לפי id מונע התנגשות בין שני ספרים בעלי כותרת זהה בעץ.
  Book? _findBookInLibraryByIdThenTitle(
    Category category,
    String title, {
    required int? bookId,
    bool preferTextBook = false,
  }) {
    if (bookId != null) {
      final byId = _findBookInLibraryById(category, bookId);
      if (byId != null) return byId;
    }
    return _findBookInLibraryByTitle(category, title,
        preferTextBook: preferTextBook);
  }

  @override
  Widget build(BuildContext context) {
    final focusRepository = context.read<FocusRepository>();

    return AlertDialog(
      title: Text(
        'find_ref.title'.tr(),
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        key: tourFindRefDialogTargetKey,
        width: 500,
        height: 600,
        child: Column(
          children: [
            BlocBuilder<FindRefBloc, FindRefState>(
              builder: (context, state) {
                final refs = state is FindRefSuccess ? state.refs : [];
                return Focus(
                  onKeyEvent: (node, event) {
                    // טיפול גם ב-KeyDownEvent וגם ב-KeyRepeatEvent (לחיצה רצופה)
                    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                      return KeyEventResult.ignored;
                    }

                    // טיפול בחיצים רק אם יש תוצאות
                    if (refs.isNotEmpty) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        setState(() {
                          _selectedIndex =
                              (_selectedIndex + 1).clamp(0, refs.length - 1);
                        });
                        _scrollToSelected();
                        return KeyEventResult.handled;
                      } else if (event.logicalKey ==
                          LogicalKeyboardKey.arrowUp) {
                        setState(() {
                          _selectedIndex =
                              (_selectedIndex - 1).clamp(0, refs.length - 1);
                        });
                        _scrollToSelected();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: RtlTextField(
                    focusNode: focusRepository.findRefSearchFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText:
                          'find_ref.hint'.tr(),
                      suffixIcon: IconButton(
                        icon: const Icon(FluentIcons.dismiss_24_regular),
                        onPressed: () {
                          focusRepository.findRefSearchController.clear();
                          // קודם מבטלים חיפוש שעדיין רץ (restartable יקטוף
                          // את ה-handler הקודם), ורק אחר-כך מחזירים את
                          // ה-state ל-Initial.
                          BlocProvider.of<FindRefBloc>(context)
                              .add(const SearchRefRequested(''));
                          BlocProvider.of<FindRefBloc>(context)
                              .add(ClearSearchRequested());
                          setState(() {
                            _selectedIndex = 0;
                          });
                        },
                      ),
                    ),
                    controller: focusRepository.findRefSearchController,
                    onChanged: (ref) {
                      setState(() => _selectedIndex = 0);
                      // ההקלדה נשלחת מיידית — ה-debounce עצמו מבוצע בתוך
                      // ה-handler ב-bloc, כך שכל הקלדה חדשה גם מבטלת מיידית
                      // כל handler שכבר רץ (גם אם הוא באמצע fetch).
                      BlocProvider.of<FindRefBloc>(context).add(
                        SearchRefRequested(
                          ref,
                          includePersonalBooks: _includePersonalBooks,
                        ),
                      );
                    },
                    onSubmitted: (value) {
                      // פתיחת המקור הנבחר בלחיצה על אנטר
                      if (refs.isNotEmpty) {
                        _openRef(refs[_selectedIndex]);
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'find_ref.include_personal_books'.tr(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.75,
                  alignment: Alignment.centerRight,
                  child: Switch(
                    value: _includePersonalBooks,
                    onChanged: (v) {
                      setState(() => _includePersonalBooks = v);
                      Settings.setValue<bool>(
                        FindRefDialog._keyIncludePersonalBooks,
                        v,
                      );
                      final text = focusRepository.findRefSearchController.text;
                      if (text.length >= 2) {
                        context.read<FindRefBloc>().add(
                              SearchRefRequested(
                                text,
                                includePersonalBooks: v,
                              ),
                            );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BlocConsumer<FindRefBloc, FindRefState>(
                // ברגע שעוזבים מצב של "Success עם תוצאות" — אין ListView,
                // אין ל-controller clients, ושום notification לא יישלח. בלי
                // איפוס יזום, _hasMoreBelow היה נשאר true מהחיפוש הקודם
                // וה-arrow היה מופיע באמצע spinner / "אין תוצאות" / Initial.
                listener: (context, state) {
                  final hasListView =
                      state is FindRefSuccess && state.refs.isNotEmpty;
                  if (!hasListView && _hasMoreBelow.value) {
                    _hasMoreBelow.value = false;
                  }
                },
                builder: (context, state) {
                  if (state is FindRefLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is FindRefError) {
                    return Text('Error: ${state.message}');
                  } else if (state is FindRefSuccess && state.refs.isEmpty) {
                    if (focusRepository.findRefSearchController.text.length >=
                        3) {
                      return Center(
                        child: Text(
                          'find_ref.no_results'.tr(),
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  } else if (state is FindRefSuccess) {
                    return NotificationListener<ScrollMetricsNotification>(
                      // נכנס לפעולה כאשר ה-ListView מתחבר לראשונה, וגם בכל
                      // שינוי של maxScrollExtent (סט תוצאות חדש שמשנה את
                      // גובה התוכן). מעדכן את _hasMoreBelow אחרי הסיום של
                      // ה-frame הנוכחי כדי שלא נשנה ValueNotifier בזמן build.
                      onNotification: (_) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _updateHasMoreBelow();
                        });
                        return false;
                      },
                      child: ListView.builder(
                        controller: _resultsScrollController,
                        itemCount: state.refs.length,
                        itemBuilder: (context, index) {
                          final ref = state.refs[index];
                          final isSelected = index == _selectedIndex;
                          final eligible =
                              !ref.isPdf && ref.bookId > 0 && !ref.isUserBook;
                          // טעינה lazy בעת רינדור — ListView.builder יפעיל את
                          // ה-itemBuilder רק עבור שורות נראות. ה-cache ב-repository
                          // ימנע קריאות חוזרות.
                          if (eligible) _ensureCommentatorsLoaded(ref);
                          final cached =
                              _commentatorsByRef[_commentatorsKey(ref)];
                          final showButton =
                              eligible && cached != null && cached.isNotEmpty;
                          final menuButtonKey =
                              _getCommentatorsButtonKey(index);
                          return Container(
                            key: _getKeyForIndex(index),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : null,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: ListTile(
                                hoverColor:
                                    showButton ? Colors.transparent : null,
                                leading: ref.isPdf
                                    ? const Icon(
                                        FluentIcons.document_pdf_24_regular)
                                    : null,
                                title: Text(
                                  ref.reference,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: ref.bookPath.isEmpty
                                    ? null
                                    : LibraryOverflowTooltipText(
                                        text: ref.bookPath,
                                        maxLines: 1,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                trailing: showButton
                                    ? IconButton(
                                        key: menuButtonKey,
                                        icon: const Icon(
                                            FluentIcons.library_24_regular),
                                        tooltip:
                                            'find_ref.show_available_commentators'
                                                .tr(),
                                        onPressed: () => _showCommentatorsMenu(
                                            menuButtonKey, cached),
                                      )
                                    : null,
                                onTap: () {
                                  _openRef(ref);
                                }),
                          );
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
      // החץ "גלול לסוף הרשימה" יושב באותה שורה כמו "סגור" (actions), אך עם
      // padding עליון 0 ותחתון מצומצם — צמוד לתחתית התוכן.
      // Stack על מלוא הרוחב: ה-Align מצמיד את "סגור" לקצה (visual left ב-RTL),
      // וה-IconButton ממוקם במרכז ע"י alignment של ה-Stack עצמו.
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('common.close'.tr()),
                ),
              ),
              _buildScrollToEndArrow(),
            ],
          ),
        ),
      ],
    );
  }
}
