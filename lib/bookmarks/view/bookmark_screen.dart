import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/widgets/dialogs/reusable_items_dialog.dart';
import 'package:otzaria/bookmarks/bloc/bookmark_bloc.dart';
import 'package:otzaria/bookmarks/bloc/bookmark_state.dart';
import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/models/commentators_tab.dart';
import 'package:otzaria/tabs/models/pdf_commentators_tab.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/utils/ui/reading_left_pane_policy.dart';
import 'package:otzaria/widgets/lists/items_list_view.dart';

class BookmarksDialog extends StatelessWidget {
  /// אם מסופק, יוצגו רק סימניות של ספר זה (הדיאלוג הופך לתצוגת
  /// "סימניות בספר הנוכחי").
  final Book? bookFilter;

  const BookmarksDialog({super.key, this.bookFilter});

  @override
  Widget build(BuildContext context) {
    return ReusableItemsDialog(
      title: bookFilter == null
          ? 'bookmarks.title'.tr()
          : 'bookmarks.book_title'.tr(),
      child: BookmarkView(bookFilter: bookFilter),
    );
  }
}

class BookmarkView extends StatefulWidget {
  /// אם מסופק, מסונן לרשימה רק סימניות שזהות הספר שלהן זהה לזו של [bookFilter].
  final Book? bookFilter;

  const BookmarkView({super.key, this.bookFilter});

  @override
  State<BookmarkView> createState() => _BookmarkViewState();
}

class _BookmarkViewState extends State<BookmarkView> {
  /// קאש לספירת הסימניות לפי ספר — נמנע מחישוב בכל קריאה ל-build
  /// כשרשימת הסימניות לא משתנה.
  List<Bookmark>? _cachedBookmarks;
  Map<String, int>? _cachedCountPerBook;

  Map<String, int> _getCountPerBook(List<Bookmark> bookmarks) {
    if (identical(_cachedBookmarks, bookmarks)) return _cachedCountPerBook!;
    final counts = <String, int>{};
    for (final bm in bookmarks) {
      final id = bookIdentity(bm.book);
      counts[id] = (counts[id] ?? 0) + 1;
    }
    _cachedBookmarks = bookmarks;
    _cachedCountPerBook = counts;
    return counts;
  }

  static int _compareBookmarks(Bookmark a, Bookmark b) {
    final aPath = a.book.categoryPath ?? '';
    final bPath = b.book.categoryPath ?? '';
    final pathCmp = aPath.compareTo(bPath);
    if (pathCmp != 0) return pathCmp;
    final aCmp = bookIdentity(a.book).compareTo(bookIdentity(b.book));
    if (aCmp != 0) return aCmp;
    return a.index.compareTo(b.index);
  }

  /// בונה את ה-Tab המתאים לסימניה. עבור [BookmarkTargetKind.commentators]
  /// יוצרים sourceTab בלתי-תלוי וגורסה אותו ל-PdfCommentatorsTab/CommentatorsTab,
  /// בדומה לזרימה ב-HistoryScreen.
  OpenedTab _buildTabForBookmark(Bookmark bookmark) {
    final openLeftPane = shouldAutoOpenReadingLeftPane();
    if (bookmark.targetKind == BookmarkTargetKind.commentators) {
      if (bookmark.book is PdfBook) {
        final sourceTab = PdfBookTab(
          book: bookmark.book as PdfBook,
          pageNumber: bookmark.index,
          openLeftPane: openLeftPane,
        )..activeCommentators = bookmark.commentatorsToShow.toSet();
        return PdfCommentatorsTab(sourceTab: sourceTab);
      }

      final sourceTab = OpenedTab.fromBook(
        bookmark.book,
        bookmark.index,
        commentators: bookmark.commentatorsToShow,
        openLeftPane: openLeftPane,
      ) as TextBookTab;
      return CommentatorsTab(sourceTab: sourceTab);
    }

    return OpenedTab.fromBook(
      bookmark.book,
      bookmark.index,
      commentators: bookmark.commentatorsToShow,
      openLeftPane: openLeftPane,
    );
  }

  void _openBook(
    BuildContext context,
    Bookmark bookmark, {
    String? targetTitle,
  }) {
    final tab = _buildTabForBookmark(bookmark);

    context.read<TabsBloc>().add(
          OpenOrFocusTab(
            tab,
            targetTitle: targetTitle,
            // סימניה מצביעה על מיקום ספציפי. אם הספר כבר פתוח בטאב אחר,
            // נרצה לגלול אותו למיקום של הסימניה ולא רק לתת לו focus.
            navigateToPositionIfReused: true,
          ),
        );
    context.read<NavigationBloc>().add(const NavigateToScreen(Screen.reading));
    // Close the dialog if this view is displayed inside one
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookFilter = widget.bookFilter;
    final filterIdentity = bookFilter == null ? null : bookIdentity(bookFilter);
    return BlocBuilder<BookmarkBloc, BookmarkState>(
      builder: (context, state) {
        // ספר עם 2+ סימניות יקבל קבוצה משלו
        final countPerBook = _getCountPerBook(state.bookmarks);

        String bookmarkGroupKey(Bookmark bm) {
          final id = bookIdentity(bm.book);
          if ((countPerBook[id] ?? 0) > 1) return 'book:$id';
          return 'folder:${bm.book.categoryPath ?? id}';
        }

        String? bookmarkGroupTitle(Bookmark bm) {
          final id = bookIdentity(bm.book);
          if ((countPerBook[id] ?? 0) > 1) return bm.book.title;
          final path = bm.book.categoryPath;
          if (path == null || path.isEmpty) return bm.book.title;
          final segments = path.split(', ').where((s) => s.isNotEmpty).toList();
          return segments.isNotEmpty ? segments.last : bm.book.title;
        }

        return ItemsListView(
          items: state.bookmarks,
          itemSortComparator: (a, b) =>
              _compareBookmarks(b as Bookmark, a as Bookmark),
          additionalFilter: filterIdentity == null
              ? null
              : (item) => bookIdentity(item.book) == filterIdentity,
          groupKeyBuilder: (item) => bookmarkGroupKey(item as Bookmark),
          groupTitleBuilder: (item) => bookmarkGroupTitle(item as Bookmark),
          onItemTap: (ctx, item, originalIndex) => _openBook(
            ctx,
            item,
            targetTitle: item.ref,
          ),
          onDelete: (ctx, originalIndex) {
            ctx.read<BookmarkBloc>().removeBookmark(originalIndex);
            UiSnack.show('bookmarks.deleted'.tr());
          },
          onClearAll: (ctx) {
            if (bookFilter == null) {
              ctx.read<BookmarkBloc>().clearBookmarks();
              UiSnack.show('bookmarks.all_deleted'.tr());
            } else {
              // הודעת ההצלחה תוצג רק אם באמת נמחקה סימניה - בלי זה היה
              // ייתכן שתוצג "סימניות הספר נמחקו" גם כשלא היו לספר סימניות
              // (לחיצת כפתור בעת מצב ריק).
              final removed =
                  ctx.read<BookmarkBloc>().clearBookmarksForBook(bookFilter);
              if (removed) {
                UiSnack.show('bookmarks.book_deleted'.tr());
              }
            }
          },
          hintText: 'bookmarks.search_hint'.tr(),
          emptyText: bookFilter == null
              ? 'bookmarks.empty'.tr()
              : 'bookmarks.book_empty'.tr(),
          notFoundText: 'bookmarks.not_found'.tr(),
          clearAllText: bookFilter == null
              ? 'bookmarks.clear_all'.tr()
              : 'bookmarks.book_clear_all'.tr(),
          leadingIconBuilder: (item) => item.book is PdfBook
              ? const Icon(FluentIcons.document_pdf_24_regular)
              : null,
          subtitleBuilder: (item) => ItemsListView.locationSubtitle(item),
        );
      },
    );
  }
}
