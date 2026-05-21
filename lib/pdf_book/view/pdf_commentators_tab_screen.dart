import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/theme/app_surfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/bookmarks/bloc/bookmark_bloc.dart';
import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/bookmarks/view/bookmark_screen.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/tabs/models/pdf_commentators_tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/pdf_book/view/pdf_commentary_panel.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/widgets/misc/commentators_filter_button.dart';
import 'package:otzaria/widgets/text/rtl_text_field.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' as utils;
import 'package:otzaria/utils/navigation/open_book.dart';
import 'package:otzaria/widgets/layout/adaptive_side_pane.dart';
import 'package:otzaria/widgets/navigation/responsive_action_bar.dart';
import 'package:otzaria/widgets/navigation/search_pane_base.dart';
import 'package:otzaria/widgets/text/otzaria_search_field.dart';

/// מסך כרטסיית המפרשים של PDF — עצמאי לחלוטין, כמו CommentatorsTabScreen.
class PdfCommentatorsTabScreen extends StatefulWidget {
  final PdfCommentatorsTab tab;

  const PdfCommentatorsTabScreen({super.key, required this.tab});

  @override
  State<PdfCommentatorsTabScreen> createState() =>
      _PdfCommentatorsTabScreenState();
}

class _PdfCommentatorsTabScreenState extends State<PdfCommentatorsTabScreen> {
  List<MapEntry<String, int>>? _sortedHeadings;
  int _selectedHeadingIdx = 0;
  int _selectedParagraphIdx = 0;
  List<String>? _textLines;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _navSearchController = TextEditingController();
  final _totalResultsNotifier = ValueNotifier<int>(0);
  final _currentIdxNotifier = ValueNotifier<int>(0);
  final _openFilterNotifier = ValueNotifier<int>(0);
  final _panelKey = GlobalKey<PdfCommentaryPanelState>();
  bool _showNavPanel = false;
  bool _showSearchPanel = false;
  final Set<int> _expandedHeadings = {};

  bool get _isNavigationReady =>
      _sortedHeadings != null && _sortedHeadings!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initHeadings();
    widget.tab.sourceTab.currentTitle.addListener(_syncWithSourceTab);
    _loadTextContent();
  }

  @override
  void didUpdateWidget(covariant PdfCommentatorsTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab.sourceTab != widget.tab.sourceTab) {
      oldWidget.tab.sourceTab.currentTitle.removeListener(_syncWithSourceTab);
      widget.tab.sourceTab.currentTitle.addListener(_syncWithSourceTab);
      _syncWithSourceTab();
    }
  }

  void _initHeadings() {
    final headings = widget.tab.sourceTab.pdfHeadings?.getSortedHeadings();
    if (headings == null || headings.isEmpty) return;
    _sortedHeadings = headings;
    final currentTitle = widget.tab.sourceTab.currentTitle.value;
    final idx = headings.indexWhere((e) => e.key == currentTitle);
    _selectedHeadingIdx = idx >= 0 ? idx : 0;
    _selectedParagraphIdx = 0;
  }

  void _syncWithSourceTab() {
    if (!mounted) return;

    final headings = widget.tab.sourceTab.pdfHeadings?.getSortedHeadings();
    final currentTitle = widget.tab.sourceTab.currentTitle.value;
    var nextSelectedHeadingIdx = _selectedHeadingIdx;

    if (headings != null && headings.isNotEmpty) {
      _sortedHeadings = headings;
      final matchedIndex = headings.indexWhere((e) => e.key == currentTitle);
      if (matchedIndex >= 0) {
        nextSelectedHeadingIdx = matchedIndex;
      }
    }

    setState(() {
      _selectedHeadingIdx = nextSelectedHeadingIdx;
      _selectedParagraphIdx = 0;
    });
  }

  void _openSearchPanel() {
    setState(() {
      _showSearchPanel = !_showSearchPanel;
      _showNavPanel = false;
    });
    if (_showSearchPanel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  Future<void> _loadTextContent() async {
    final tab = widget.tab.sourceTab;
    try {
      final library = await DataRepository.instance.library;
      TextBook? textBook =
          library.findBookByTitle(tab.book.title, TextBook) as TextBook?;
      textBook ??= library.findBookByTitleFlexible(tab.book.title, TextBook)
          as TextBook?;
      if (textBook == null || !mounted) return;
      final text = await textBook.text;
      if (!mounted) return;
      setState(() {
        _textLines = text.split('\n');
      });
    } catch (e) {
      debugPrint('שגיאה בטעינת תוכן טקסט: $e');
    }
  }

  @override
  void dispose() {
    widget.tab.sourceTab.currentTitle.removeListener(_syncWithSourceTab);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _navSearchController.dispose();
    _totalResultsNotifier.dispose();
    _currentIdxNotifier.dispose();
    _openFilterNotifier.dispose();
    super.dispose();
  }

  /// פסקאות (שורות טקסט לא-ריקות) בתוך heading נבחר
  List<({int lineIdx, String text})> _getParagraphs(int headingIdx) {
    final lines = _textLines;
    if (lines == null) return const [];
    final headings = _sortedHeadings;
    if (headings == null || headingIdx >= headings.length) return const [];
    final start = headings[headingIdx].value;
    final headingText = headings[headingIdx].key.trim();
    final end = headingIdx + 1 < headings.length
        ? headings[headingIdx + 1].value - 1
        : lines.length - 1;
    final result = <({int lineIdx, String text})>[];
    for (int i = start; i <= end && i < lines.length; i++) {
      final clean = utils.stripHtmlIfNeeded(lines[i]).trim();
      if (i == start && clean == headingText) {
        continue;
      }
      if (clean.isNotEmpty) result.add((lineIdx: i, text: clean));
    }
    return result;
  }

  /// טווח שורות לחלונית המפרשים
  ({int start, int end}) _getLineRangeForPara(
    int headingIdx,
    List<({int lineIdx, String text})> paragraphs,
    int paraIdx,
  ) {
    if (paragraphs.isNotEmpty && paraIdx < paragraphs.length) {
      final lineIdx = paragraphs[paraIdx].lineIdx;
      final nextLineIdx = paraIdx + 1 < paragraphs.length
          ? paragraphs[paraIdx + 1].lineIdx - 1
          : lineIdx + 1;
      return (start: lineIdx, end: nextLineIdx);
    }
    final headings = _sortedHeadings;
    if (headings == null || headingIdx >= headings.length) {
      final fallback = widget.tab.sourceTab.currentTextLineNumber ?? 0;
      return (
        start: fallback,
        end: widget.tab.sourceTab.currentTextLineNumberEnd ?? fallback + 50,
      );
    }
    final start = headings[headingIdx].value;
    final lastLineIndex = (_textLines?.length ?? 0) - 1;
    final end = headingIdx + 1 < headings.length
        ? headings[headingIdx + 1].value - 1
        : (lastLineIndex >= start ? lastLineIndex : start);
    return (start: start, end: end);
  }

  @override
  Widget build(BuildContext context) {
    if (_sortedHeadings == null) _initHeadings();
    final paragraphs = _getParagraphs(_selectedHeadingIdx);
    final safeParaIdx = paragraphs.isEmpty
        ? 0
        : _selectedParagraphIdx.clamp(0, paragraphs.length - 1);
    final range =
        _getLineRangeForPara(_selectedHeadingIdx, paragraphs, safeParaIdx);

    return Column(
      children: [
        (_isNavigationReady || _textLines != null)
            ? _buildActionBar(context)
            : _buildLoadingActionBar(context),
        Expanded(
          child: AdaptiveSidePane(
            isOpen: _showNavPanel || _showSearchPanel,
            alignment: AlignmentDirectional.centerEnd,
            paneWidth: 280,
            onClose: () => setState(() {
              _showNavPanel = false;
              _showSearchPanel = false;
            }),
            paneContent: _showSearchPanel
                ? _buildSearchPanel()
                : _buildNavPanel(),
            mainContent: ValueListenableBuilder<bool>(
              valueListenable: widget.tab.sourceTab.linksLoadingNotifier,
              builder: (context, linksLoading, _) => PdfCommentaryPanel(
                key: _panelKey,
                tab: widget.tab.sourceTab,
                linksCount: widget.tab.sourceTab.links.length,
                linksLoading: linksLoading,
                isFullScreen: true,
                lineStartOverride: range.start,
                lineEndOverride: range.end,
                openBookCallback: (tab) {
                  if (tab is TextBookTab) {
                    openBook(context, tab.book, tab.index, '',
                        ignoreHistory: false);
                  }
                },
                fontSize: 16.0,
                openFilterNotifier: _openFilterNotifier,
                externalSearchController: _searchController,
                externalTotalResultsNotifier: _totalResultsNotifier,
                externalCurrentIndexNotifier: _currentIdxNotifier,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToPrevParagraph() {
    if (!_isNavigationReady) return;
    final paragraphs = _getParagraphs(_selectedHeadingIdx);
    if (_selectedParagraphIdx > 0 && paragraphs.isNotEmpty) {
      setState(() => _selectedParagraphIdx--);
      return;
    }
    if (_selectedHeadingIdx <= 0) return;
    final prevHeadingIdx = _selectedHeadingIdx - 1;
    final prevParagraphs = _getParagraphs(prevHeadingIdx);
    setState(() {
      _selectedHeadingIdx = prevHeadingIdx;
      _selectedParagraphIdx =
          prevParagraphs.isNotEmpty ? prevParagraphs.length - 1 : 0;
      _expandedHeadings.add(prevHeadingIdx);
    });
  }

  void _navigateToNextParagraph() {
    if (!_isNavigationReady) return;
    final paragraphs = _getParagraphs(_selectedHeadingIdx);
    if (_selectedParagraphIdx + 1 < paragraphs.length) {
      setState(() => _selectedParagraphIdx++);
      return;
    }
    if (_sortedHeadings == null ||
        _selectedHeadingIdx + 1 >= _sortedHeadings!.length) {
      return;
    }
    final nextHeadingIdx = _selectedHeadingIdx + 1;
    setState(() {
      _selectedHeadingIdx = nextHeadingIdx;
      _selectedParagraphIdx = 0;
      _expandedHeadings.add(nextHeadingIdx);
    });
  }

  void _showBookmarksForCurrentBook(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => BookmarksDialog(bookFilter: widget.tab.sourceTab.book),
    );
  }

  void _addBookmark(BuildContext context) {
    final page = widget.tab.sourceTab.pdfViewerController.isReady
        ? (widget.tab.sourceTab.pdfViewerController.pageNumber ??
            widget.tab.sourceTab.pageNumber)
        : widget.tab.sourceTab.pageNumber;
    final heading = widget.tab.sourceTab.currentTitle.value.trim();
    final ref = heading.isNotEmpty
        ? '${widget.tab.sourceTab.book.title} $heading'
        : '${widget.tab.sourceTab.book.title} עמוד $page';

    final added = context.read<BookmarkBloc>().addBookmark(
          ref: 'מפרשים | $ref',
          book: widget.tab.sourceTab.book,
          index: page,
          commentatorsToShow: widget.tab.sourceTab.activeCommentators.toList(),
          targetKind: BookmarkTargetKind.commentators,
        );
    UiSnack.show(added ? 'הסימניה נוספה בהצלחה' : 'הסימניה כבר קיימת');
  }

  Widget _buildActionBar(BuildContext context) {
    final currentHeading = _sortedHeadings != null &&
            _sortedHeadings!.isNotEmpty &&
            _selectedHeadingIdx >= 0 &&
            _selectedHeadingIdx < _sortedHeadings!.length
        ? _sortedHeadings![_selectedHeadingIdx].key
        : widget.tab.sourceTab.currentTitle.value;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                FluentIcons.navigation_24_regular,
                color: _showNavPanel
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              tooltip: 'ניווט',
              onPressed: () => setState(() {
                _showNavPanel = !_showNavPanel;
                _showSearchPanel = false;
              }),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.tab.sourceTab.book.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (currentHeading.isNotEmpty)
                    Text(
                      currentHeading,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            ResponsiveActionBar(
              alwaysInMenu: [
                ActionButtonData(
                  widget: IconButton(
                    icon: const Icon(FluentIcons.bookmark_multiple_24_regular),
                    tooltip: 'סימניות בספר זה',
                    onPressed: () => _showBookmarksForCurrentBook(context),
                  ),
                  icon: FluentIcons.bookmark_multiple_24_regular,
                  tooltip: 'סימניות בספר זה',
                  onPressed: () => _showBookmarksForCurrentBook(context),
                ),
              ],
              maxVisibleButtons: 999,
              actions: [
                ActionButtonData.simple(
                  icon: FluentIcons.bookmark_add_24_regular,
                  tooltip: 'הוסף סימניה',
                  compact: true,
                  onPressed: () => _addBookmark(context),
                ),
                ActionButtonData.simple(
                  icon: FluentIcons.search_24_regular,
                  tooltip: 'חיפוש',
                  compact: true,
                  selected: _showSearchPanel,
                  onPressed: _openSearchPanel,
                ),
                ActionButtonData(
                  widget: CommentatorsFilterButton(
                    isActive: false,
                    onPressed: () => _openFilterNotifier.value++,
                  ),
                  icon: FluentIcons.apps_list_24_regular,
                  tooltip: 'בחירת מפרשים',
                  onPressed: () => _openFilterNotifier.value++,
                ),
                ActionButtonData.simple(
                  icon: FluentIcons.chevron_left_24_regular,
                  tooltip: 'הקטע הקודם',
                  compact: true,
                  onPressed: _navigateToPrevParagraph,
                ),
                ActionButtonData.simple(
                  icon: FluentIcons.chevron_right_24_regular,
                  tooltip: 'הקטע הבא',
                  compact: true,
                  onPressed: _navigateToNextParagraph,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingActionBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainer,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            const IconButton(
              icon: Icon(FluentIcons.navigation_24_regular),
              tooltip: 'ניווט',
              onPressed: null,
            ),
            Expanded(
              child: Text(
                widget.tab.sourceTab.book.title,
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            ResponsiveActionBar(
              alwaysInMenu: const [],
              maxVisibleButtons: 999,
              actions: const [
                ActionButtonData(
                  widget: IconButton(
                    icon: Icon(FluentIcons.bookmark_add_24_regular),
                    tooltip: 'הוסף סימניה',
                    onPressed: null,
                  ),
                  icon: FluentIcons.bookmark_add_24_regular,
                  tooltip: 'הוסף סימניה',
                  onPressed: null,
                ),
                ActionButtonData(
                  widget: IconButton(
                    icon: Icon(FluentIcons.search_24_regular),
                    tooltip: 'חיפוש',
                    onPressed: null,
                  ),
                  icon: FluentIcons.search_24_regular,
                  tooltip: 'חיפוש',
                  onPressed: null,
                ),
                ActionButtonData(
                  widget: IconButton(
                    icon: Icon(FluentIcons.apps_list_24_regular),
                    tooltip: 'בחירת מפרשים',
                    onPressed: null,
                  ),
                  icon: FluentIcons.apps_list_24_regular,
                  tooltip: 'בחירת מפרשים',
                  onPressed: null,
                ),
                ActionButtonData(
                  widget: IconButton(
                    icon: Icon(FluentIcons.chevron_left_24_regular),
                    tooltip: 'הקטע הקודם',
                    onPressed: null,
                  ),
                  icon: FluentIcons.chevron_left_24_regular,
                  tooltip: 'הקטע הקודם',
                  onPressed: null,
                ),
                ActionButtonData(
                  widget: IconButton(
                    icon: Icon(FluentIcons.chevron_right_24_regular),
                    tooltip: 'הקטע הבא',
                    onPressed: null,
                  ),
                  icon: FluentIcons.chevron_right_24_regular,
                  tooltip: 'הקטע הבא',
                  onPressed: null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavPanel() {
    final headings = _sortedHeadings;
    if (headings == null || headings.isEmpty) {
      return const Center(child: Text('אין ניווט'));
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _navSearchController,
      builder: (context, val, _) {
        final query = val.text.trim();
        final filteredIdx = query.isEmpty
            ? List<int>.generate(headings.length, (i) => i)
            : List<int>.generate(headings.length, (i) => i)
                .where((i) => headings[i].key.contains(query))
                .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: RtlTextField(
                controller: _navSearchController,
                decoration: InputDecoration(
                  hintText: 'איתור כותרת...',
                  prefixIcon: const Icon(FluentIcons.search_24_regular),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(FluentIcons.dismiss_24_regular),
                          onPressed: () => _navSearchController.clear(),
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredIdx.length,
                itemBuilder: (context, listIdx) {
                  final idx = filteredIdx[listIdx];
                  final isSelected = idx == _selectedHeadingIdx;
                  final isExpanded = _expandedHeadings.contains(idx);
                  final paras = _getParagraphs(idx);

                  final headingRow = _buildHeadingRow(
                    context: context,
                    headingText: headings[idx].key,
                    isSelected: isSelected,
                    isExpanded: isExpanded,
                    hasChildren: paras.isNotEmpty,
                    onTap: () {
                      if (paras.isNotEmpty) {
                        setState(() {
                          if (isExpanded) {
                            _expandedHeadings.remove(idx);
                          } else {
                            _expandedHeadings.add(idx);
                          }
                        });
                      }
                      setState(() {
                        _selectedHeadingIdx = idx;
                        _selectedParagraphIdx = 0;
                        _searchController.clear();
                      });
                    },
                  );

                  if (paras.isEmpty || !isExpanded) {
                    return headingRow;
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      headingRow,
                      ...List.generate(paras.length, (pi) {
                        final words = paras[pi]
                            .text
                            .split(RegExp(r'\s+'))
                            .where((w) => w.isNotEmpty)
                            .take(4)
                            .join(' ');
                        final isParaSelected =
                            isSelected && _selectedParagraphIdx == pi;
                        return _buildParagraphRow(
                          context: context,
                          text: words,
                          isSelected: isParaSelected,
                          onTap: () {
                            setState(() {
                              _selectedHeadingIdx = idx;
                              _selectedParagraphIdx = pi;
                              _searchController.clear();
                            });
                          },
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeadingRow({
    required BuildContext context,
    required String headingText,
    required bool isSelected,
    required bool isExpanded,
    required bool hasChildren,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppSurfaces.selectedItem(colorScheme)
              : null,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.only(right: 16, left: 8, top: 12, bottom: 12),
        child: Row(
          children: [
            Icon(
              FluentIcons.book_24_regular,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                headingText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                textDirection: TextDirection.rtl,
              ),
            ),
            if (hasChildren)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  isExpanded
                      ? FluentIcons.chevron_up_24_regular
                      : FluentIcons.chevron_down_24_regular,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParagraphRow({
    required BuildContext context,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(
            right: 16.0 + 24.0, left: 16, top: 10, bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppSurfaces.selectedItem(colorScheme)
              : null,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              FluentIcons.text_bullet_list_24_regular,
              color: colorScheme.secondary,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, val, __) {
        final hasQuery = val.text.isNotEmpty;
        return ValueListenableBuilder<int>(
          valueListenable: _totalResultsNotifier,
          builder: (context, total, _) => ValueListenableBuilder<int>(
            valueListenable: _currentIdxNotifier,
            builder: (context, currentIdx, _) => SearchPaneBase(
              searchController: _searchController,
              focusNode: _searchFocusNode,
              hintText: 'חיפוש במפרשים...',
              isNoResults: hasQuery && total == 0,
              resetSearchCallback: _searchController.clear,
              resultCountString: hasQuery && total > 0
                  ? 'תוצאה ${currentIdx + 1} מתוך $total'
                  : null,
              resultToolbar: hasQuery && total > 0
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OtzariaSearchAction.prevResult(
                          onPressed: currentIdx > 0
                              ? () =>
                                  _panelKey.currentState?.navigateSearchPrev()
                              : null,
                        ),
                        OtzariaSearchAction.nextResult(
                          onPressed: currentIdx < total - 1
                              ? () =>
                                  _panelKey.currentState?.navigateSearchNext()
                              : null,
                        ),
                      ],
                    )
                  : null,
              resultsWidget: const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
