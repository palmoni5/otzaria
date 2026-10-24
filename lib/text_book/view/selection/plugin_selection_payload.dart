import 'package:otzaria/book_common/utils/link_anchor_markers.dart';
import 'package:otzaria/plugins/models/plugin_book_identity.dart';
import 'package:otzaria/plugins/services/plugin_divine_names_filter.dart';
import 'package:otzaria/plugins/services/reader_selection_service.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/book_common/selection/selected_text_restore.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';

/// שורה [lineIndex] של הספר עם סמני השמות, כפי שהקורא מציג אותה.
String readerLineWithDivineNames(
  TextBookLoaded state,
  String line,
  int lineIndex,
) => injectDivineNameMarkers(line, state.divineNames, lineIndex);

/// [payload] (בחירה מעוגנת מול [settings] שעל המסך) עם נספח שמוסר לתוסף את
/// הטקסט לפי הגדרת השמות העדכנית של [state], או כפי שנשמר למי שביקש.
Map<String, dynamic> withReaderSelectionDivineNames(
  Map<String, dynamic> payload, {
  required TextBookLoaded state,
  required RenderSettings settings,
  required String Function(int sectionIndex) markedLineOf,
}) => PluginDivineNamesPayload(
  () =>
      PluginDivineNamesDisplay.of(PluginDivineNamesFilter.readerProfile(state)),
  (payload, names) => const ReaderSelectionService().withDivineNames(
    payload,
    names: names,
    settings: settings,
    rawTextOf: markedLineOf,
  ),
).attachTo(payload);

/// בונה payload של בחירה בפסקה יחידה לתוסף, בדיוק כמו תפריט הלחיצה הימנית.
Map<String, dynamic> buildPluginSelectionPayload({
  required TextBookLoaded state,
  required String rawText,
  required String selectedText,
  required int sectionIndex,
  required int? startHint,
  required RenderSettings settings,
}) {
  const selectionService = ReaderSelectionService();
  final markedText = readerLineWithDivineNames(state, rawText, sectionIndex);
  final renderedLine = renderSelectionLine(
    rawText: markedText,
    settings: settings,
  );
  final localRange = selectionService.locateRenderedRange(
    renderedText: renderedLine,
    selectedText: selectedText,
    startHint: startHint,
  );
  return withReaderSelectionDivineNames(
    selectionService.buildPayload(
      bookId: state.book.title,
      bookTitle: state.book.title,
      sectionIndex: sectionIndex,
      rawText: markedText,
      settings: settings,
      selectedText: selectedText,
      renderedStartUtf16: localRange?.start,
      renderedEndUtf16: localRange?.end,
      currentRef: state.currentTitle,
      bookDbId: state.book.id,
      bookType: PluginBookIdentity.typeOf(state.book),
      bookSource: PluginBookIdentity.sourceOf(state.book),
    ),
    state: state,
    settings: settings,
    markedLineOf: (_) => markedText,
  );
}

/// בונה payload לבחירה חוצת-פסקאות, עם עוגן וטווח עבור כל פסקה.
Map<String, dynamic> buildPluginMultiSectionSelectionPayload({
  required TextBookLoaded state,
  required List<String> rawTexts,
  required String selectedText,
  required int firstSectionIndex,
  required int? startHint,
  required RenderSettings settings,
}) {
  const selectionService = ReaderSelectionService();
  final markedTexts = [
    for (var i = 0; i < rawTexts.length; i++)
      readerLineWithDivineNames(state, rawTexts[i], firstSectionIndex + i),
  ];
  final renderedLines = [
    for (final rawText in markedTexts)
      renderSelectionLine(rawText: rawText, settings: settings),
  ];
  return withReaderSelectionDivineNames(
    selectionService.buildMultiSectionPayload(
      bookId: state.book.title,
      bookTitle: state.book.title,
      firstSectionIndex: firstSectionIndex,
      rawTexts: markedTexts,
      lineRanges:
          locateSelectionRangesPerLine(
            selectedText: selectedText,
            visibleLines: renderedLines,
            startColumnHint: startHint,
          ) ??
          const [],
      settings: settings,
      selectedText: selectedText,
      currentRef: state.currentTitle,
      bookDbId: state.book.id,
      bookType: PluginBookIdentity.typeOf(state.book),
      bookSource: PluginBookIdentity.sourceOf(state.book),
    ),
    state: state,
    settings: settings,
    markedLineOf: (sectionIndex) =>
        markedTexts[sectionIndex - firstSectionIndex],
  );
}
