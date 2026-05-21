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
      title: bookFilter == null ? 'סימניות' : 'סימניות בספר זה',
      child: BookmarkView(bookFilter: bookFilter),
    );
  }
}

class BookmarkView extends StatelessWidget {
  /// אם מסופק, מסונן לרשימה רק סימניות שזהות הספר שלהן זהה לזו של [bookFilter].
  final Book? bookFilter;

  const BookmarkView({super.key, this.bookFilter});

  OpenedTab _buildTabForBookmark(
    Bookmark bookmark,
  ) {
    if (bookmark.targetKind == BookmarkTargetKind.commentators) {
      if (bookmark.book is PdfBook) {
        final sourceTab = PdfBookTab(
          book: bookmark.book as PdfBook,
          pageNumber: bookmark.index,
          openLeftPane: shouldAutoOpenReadingLeftPane(),
        )..activeCommentators = bookmark.commentatorsToShow.toSet();
        return PdfCommentatorsTab(sourceTab: sourceTab);
      }

      final sourceTab = OpenedTab.fromBook(
        bookmark.book,
        bookmark.index,
        commentators: bookmark.commentatorsToShow,
        openLeftPane: shouldAutoOpenReadingLeftPane(),
      ) as TextBookTab;
      return CommentatorsTab(sourceTab: sourceTab);
    }

    return OpenedTab.fromBook(
      bookmark.book,
      bookmark.index,
      commentators: bookmark.commentatorsToShow,
      openLeftPane: shouldAutoOpenReadingLeftPane(),
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

  String _locationSubtitle(Bookmark bookmark) {
    if (bookmark.book is PdfBook) {
      return bookmark.targetKind == BookmarkTargetKind.commentators
          ? 'כרטיסיית מפרשים · עמוד ${bookmark.index}'
          : 'עמוד ${bookmark.index}';
    }
    return bookmark.targetKind == BookmarkTargetKind.commentators
        ? 'כרטיסיית מפרשים · פסקה ${bookmark.index}'
        : 'פסקה ${bookmark.index}';
  }

  @override
  Widget build(BuildContext context) {
    final filterIdentity =
        bookFilter == null ? null : bookIdentity(bookFilter!);
    return BlocBuilder<BookmarkBloc, BookmarkState>(
      builder: (context, state) {
        return ItemsListView(
          items: state.bookmarks,
          additionalFilter: filterIdentity == null
              ? null
              : (item) => bookIdentity(item.book) == filterIdentity,
          onItemTap: (ctx, item, originalIndex) => _openBook(
            ctx,
            item,
            targetTitle: item.ref,
          ),
          onDelete: (ctx, originalIndex) {
            ctx.read<BookmarkBloc>().removeBookmark(originalIndex);
            UiSnack.show('הסימניה נמחקה');
          },
          onClearAll: (ctx) {
            if (bookFilter == null) {
              ctx.read<BookmarkBloc>().clearBookmarks();
              UiSnack.show('כל הסימניות נמחקו');
            } else {
              // הודעת ההצלחה תוצג רק אם באמת נמחקה סימניה - בלי זה היה
              // ייתכן שתוצג "סימניות הספר נמחקו" גם כשלא היו לספר סימניות
              // (לחיצת כפתור בעת מצב ריק).
              final removed =
                  ctx.read<BookmarkBloc>().clearBookmarksForBook(bookFilter!);
              if (removed) {
                UiSnack.show('סימניות הספר נמחקו');
              }
            }
          },
          hintText: 'חפש בסימניות...',
          emptyText: bookFilter == null ? 'אין סימניות' : 'אין סימניות בספר זה',
          notFoundText: 'לא נמצאו תוצאות',
          clearAllText:
              bookFilter == null ? 'מחק את כל הסימניות' : 'מחק סימניות הספר',
          leadingIconBuilder: (item) => item.book is PdfBook
              ? const Icon(FluentIcons.document_pdf_24_regular)
              : null,
          subtitleBuilder: (item) => _locationSubtitle(item),
        );
      },
    );
  }
}
