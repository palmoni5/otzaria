import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/tabs/models/pdf_commentators_tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/pdf_book/view/pdf_commentary_panel.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/widgets/misc/commentators_filter_button.dart';
import 'package:otzaria/widgets/text/rtl_text_field.dart';
import 'package:otzaria/utils/navigation/open_book.dart';
import 'package:otzaria/widgets/layout/adaptive_side_pane.dart';
import 'package:otzaria/widgets/navigation/responsive_action_bar.dart';

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
  final _totalResultsNotifier = ValueNotifier<int>(0);
  final _currentIdxNotifier = ValueNotifier<int>(0);
  final _openFilterNotifier = ValueNotifier<int>(0);
  final _panelKey = GlobalKey<PdfCommentaryPanelState>();
  bool _showNavPanel = false;
  bool _showSearchPanel = false;
  final Set<int> _expandedHeadings = {};

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
    final end = headingIdx + 1 < headings.length
        ? headings[headingIdx + 1].value - 1
        : lines.length - 1;
    final result = <({int lineIdx, String text})>[];
    for (int i = start; i <= end && i < lines.length; i++) {
      final clean = lines[i]
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .trim();
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
        _buildActionBar(context),
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
                : _buildNavPanel(paragraphs, safeParaIdx),
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
              alwaysInMenu: const [],
              maxVisibleButtons: 999,
              actions: [
                ActionButtonData.simple(
                  icon: FluentIcons.search_24_regular,
                  tooltip: 'חיפוש',
                  compact: true,
                  selected: _showSearchPanel,
                  onPressed: () => setState(() {
                    _showSearchPanel = !_showSearchPanel;
                    _showNavPanel = false;
                  }),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavPanel(
    List<({int lineIdx, String text})> paragraphs,
    int safeParaIdx,
  ) {
    final headings = _sortedHeadings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text('ניווט', style: Theme.of(context).textTheme.titleSmall),
        ),
        const Divider(height: 1),
        Expanded(
          child: headings == null || headings.isEmpty
              ? const Center(child: Text('אין ניווט'))
              : ListView.builder(
                  itemCount: headings.length,
                  itemBuilder: (context, idx) {
                    final isSelected = idx == _selectedHeadingIdx;
                    final isExpanded = _expandedHeadings.contains(idx);
                    final paras = _getParagraphs(idx);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          dense: true,
                          selected: isSelected && paras.isEmpty,
                          title: Text(
                            headings[idx].key,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: paras.isNotEmpty
                              ? Icon(
                                  isExpanded
                                      ? FluentIcons.chevron_up_24_regular
                                      : FluentIcons.chevron_down_24_regular,
                                  size: 16,
                                )
                              : null,
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
                        ),
                        if (paras.isNotEmpty && isExpanded)
                          ...List.generate(paras.length, (pi) {
                            final words = paras[pi]
                                .text
                                .split(RegExp(r'\s+'))
                                .where((w) => w.isNotEmpty)
                                .take(4)
                                .join(' ');
                            return ListTile(
                              dense: true,
                              selected:
                                  isSelected && _selectedParagraphIdx == pi,
                              contentPadding: const EdgeInsetsDirectional.only(
                                  start: 32, end: 16),
                              title: Text(
                                words,
                                overflow: TextOverflow.ellipsis,
                              ),
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
  }

  Widget _buildSearchPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text('חיפוש', style: Theme.of(context).textTheme.titleSmall),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: ValueListenableBuilder<int>(
            valueListenable: _totalResultsNotifier,
            builder: (context, total, _) => ValueListenableBuilder<int>(
              valueListenable: _currentIdxNotifier,
              builder: (context, currentIdx, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RtlTextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'חיפוש...',
                      prefixIcon:
                          const Icon(FluentIcons.search_24_regular, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(FluentIcons.dismiss_24_regular,
                                  size: 16),
                              onPressed: () =>
                                  setState(() => _searchController.clear()),
                            )
                          : null,
                    ),
                  ),
                  if (_searchController.text.isNotEmpty && total > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(FluentIcons.chevron_up_24_regular),
                          onPressed: currentIdx > 0
                              ? () =>
                                  _panelKey.currentState?.navigateSearchPrev()
                              : null,
                        ),
                        Text('${currentIdx + 1}/$total'),
                        IconButton(
                          icon: const Icon(FluentIcons.chevron_down_24_regular),
                          onPressed: currentIdx < total - 1
                              ? () =>
                                  _panelKey.currentState?.navigateSearchNext()
                              : null,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
