import 'package:flutter/widgets.dart';
import 'package:otzaria/book_common/selection/commentary_selection.dart';
import 'package:otzaria/book_protection/utils/copy_guard.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/plugins/models/plugin_book_identity.dart';
import 'package:otzaria/plugins/models/plugin_context_menu_item.dart';
import 'package:otzaria/plugins/services/plugin_divine_names_filter.dart';
import 'package:otzaria/plugins/utils/plugin_context_menu_entries.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_display/text_display_exports.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' as utils;
import 'package:otzaria/widgets/misc/app_popup_menu.dart';

/// The commentary line a right click landed on.
typedef CommentaryMenuTarget = ({
  Book book,
  int sectionIndex,
  String? currentRef,
});

/// The book being read. [sectionIndex] is the text line the commentary is
/// linked to (0-based), or the page of a PDF, which also sets [pageNumber].
typedef CommentaryMainBook = ({
  Book book,
  String? currentRef,
  int? sectionIndex,
  int? pageNumber,
});

/// The target of an item in a commentary list.
CommentaryMenuTarget commentaryTargetForLink(Link link) => (
  book: TextBook(
    id: link.targetBookId,
    title: utils.getTitleFromPath(link.path2),
    categoryId: link.targetCategoryId,
    fileType: link.targetFileType,
    source: link.targetSource,
  ),
  sectionIndex: link.index2 - 1,
  currentRef: link.fallbackDisplayReference,
);

/// [text] within the copy limit of [guard]. A selection across several
/// commentaries arrives without line breaks, so its line count says nothing.
String limitCommentarySelection(CommentaryCopyGuard guard, String text) {
  final limited = limitTextToCopySegments(guard.protection, text);
  if (limited == text && !guard.protection.allowsCopyOf(guard.segmentCount)) {
    return '';
  }
  return limited;
}

/// What plugins receive for a right click on a commentary: the commentary is
/// the current book, and `mainBook` is the book being read. Holy names in
/// the selected text follow the commentary display of [readerState].
Map<String, dynamic> buildCommentaryPluginPayload({
  required CommentaryMenuTarget target,
  required CommentaryMainBook mainBook,
  String selectedText = '',
  TextBookLoaded? readerState,
}) {
  final book = target.book;
  PluginDivineNamesDisplay names() => readerState == null
      ? PluginDivineNamesFilter.generalNames(target: TextTarget.commentary)
      : PluginDivineNamesDisplay.of(
          PluginDivineNamesFilter.readerProfile(
            readerState,
            target: TextTarget.commentary,
          ),
        );
  return PluginDivineNamesPayload.text(names).attachTo({
    ...pluginMenuPayload(
      identity: {
        ...PluginBookIdentity.toJson(book),
        // בלי id המפתח נגזר מנתיב הקטגוריה, שחסר בספר שנבנה מקישור.
        if (book.id != null) 'bookUid': PluginBookIdentity.uidOf(book),
      },
      bookTitle: book.title,
      sectionIndex: target.sectionIndex,
      currentRef: target.currentRef,
      text: selectedText,
    ),
    'mainBook': {
      ...PluginBookIdentity.toJsonWithUid(mainBook.book),
      'bookTitle': mainBook.book.title,
      'currentRef': mainBook.currentRef,
      'sectionIndex': ?mainBook.sectionIndex,
      'pageNumber': ?mainBook.pageNumber,
    },
  });
}

/// Plugin entries for a right click on a commentary. The copy limit resolves
/// only asynchronously, so [copyGuard] trims the text on click.
List<AppContextMenuEntry> buildCommentaryPluginMenuEntries({
  required CommentaryMenuTarget target,
  required CommentaryMainBook mainBook,
  required String? selectedText,
  required Future<CommentaryCopyGuard> Function() copyGuard,
  required BuildContext menuContext,
  TextBookLoaded? readerState,
  List<(String, PluginContextMenuItem)>? records,
  PluginSelectionActionDispatcher? selectionActionDispatcher,
}) {
  final text = selectedText?.trim().isNotEmpty == true ? selectedText! : '';
  return buildPluginContextMenuSection(
    context: text.isEmpty ? 'reader-commentary' : 'reader-commentary-selection',
    selection: buildCommentaryPluginPayload(
      target: target,
      mainBook: mainBook,
      selectedText: text,
      readerState: readerState,
    ),
    menuContext: menuContext,
    resolveSelectedText: text.isEmpty
        ? null
        : () async => limitCommentarySelection(await copyGuard(), text),
    records: records,
    selectionActionDispatcher: selectionActionDispatcher,
  );
}
