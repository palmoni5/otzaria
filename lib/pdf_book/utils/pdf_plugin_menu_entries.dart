import 'package:flutter/widgets.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/plugins/models/plugin_book_identity.dart';
import 'package:otzaria/plugins/models/plugin_context_menu_item.dart';
import 'package:otzaria/plugins/services/plugin_divine_names_filter.dart';
import 'package:otzaria/plugins/utils/plugin_context_menu_entries.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/utils/text/ref_helper.dart';
import 'package:otzaria/widgets/misc/app_popup_menu.dart';

/// The ref of [pageNumber] for plugins: its heading in the PDF outline, or
/// "עמוד N" when the outline has none.
String pdfPageRef(PdfBookTab tab, int pageNumber) {
  final ref = referenceFromPageNumber(
    pageNumber,
    tab.outline.value,
    tab.book.title,
  );
  return ref.isNotEmpty ? ref : 'עמוד $pageNumber';
}

/// What plugins receive for a right click on a PDF page. `sectionIndex` and
/// `currentIndex` are the 1-based page number, as in `reader.getCurrentState`.
/// A PDF has no marked names, so only the holy name follows the settings.
Map<String, dynamic> buildPdfPluginPayload({
  required Book book,
  required int pageNumber,
  required String? currentRef,
  String selectedText = '',
}) =>
    PluginDivineNamesPayload.text(
      PluginDivineNamesFilter.generalNames,
    ).attachTo({
      ...pluginMenuPayload(
        identity: PluginBookIdentity.toJsonWithUid(book),
        bookTitle: book.title,
        sectionIndex: pageNumber,
        currentRef: currentRef,
        text: selectedText,
      ),
      'pageNumber': pageNumber,
    });

/// Plugin entries for a right click on a PDF page. A selection whose pages
/// are not loaded yet ([loadedText] null) is read with [readSelectedText] on
/// click; a document that forbids copying gives the click without the text.
List<AppContextMenuEntry> buildPdfPluginMenuEntries({
  required Book book,
  required int pageNumber,
  required String? currentRef,
  required bool hasSelection,
  required String? loadedText,
  required Future<String> Function() readSelectedText,
  required bool copyAllowed,
  required BuildContext menuContext,
  List<(String, PluginContextMenuItem)>? records,
  PluginSelectionActionDispatcher? selectionActionDispatcher,
}) => buildPluginContextMenuSection(
  context: hasSelection ? 'reader-pdf-selection' : 'reader-pdf',
  selection: buildPdfPluginPayload(
    book: book,
    pageNumber: pageNumber,
    currentRef: currentRef,
    selectedText: copyAllowed ? loadedText ?? '' : '',
  ),
  menuContext: menuContext,
  resolveSelectedText: hasSelection && copyAllowed && loadedText == null
      ? readSelectedText
      : null,
  records: records,
  selectionActionDispatcher: selectionActionDispatcher,
);
