import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:otzaria/text_book/utils/toc_unit_label.dart';
import 'package:otzaria/theme/app_surfaces.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/bookmarks/bloc/bookmark_bloc.dart';
import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/bookmarks/view/bookmark_screen.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/tabs/models/commentators_tab.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/view/commentary_list_base.dart';
import 'package:otzaria/utils/text/ref_helper.dart';
import 'package:otzaria/widgets/misc/commentators_filter_button.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/widgets/layout/adaptive_side_pane.dart';
import 'package:otzaria/widgets/navigation/responsive_action_bar.dart';
import 'package:otzaria/widgets/navigation/search_pane_base.dart';
import 'package:otzaria/widgets/text/otzaria_search_field.dart';
import 'package:otzaria/widgets/text/rtl_text_field.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' as utils;
import 'package:otzaria/search/utils/snippet_builder.dart';

const _kAllChapter = -1;

class CommentatorsTabScreen extends StatefulWidget {
  final CommentatorsTab tab;
  final Function(OpenedTab) openBookCallback;

  const CommentatorsTabScreen({
    super.key,
    required this.tab,
    required this.openBookCallback,
  });

  @override
  State<CommentatorsTabScreen> createState() => _CommentatorsTabScreenState();
}

class _CommentatorsTabScreenState extends State<CommentatorsTabScreen>
    with TickerProviderStateMixin {
  TocEntry? _selectedChapter;
  int _selectedVerseIdx = _kAllChapter;

  final _openFilterNotifier = ValueNotifier<int>(0);
  final _commentaryKey = GlobalKey<CommentaryListBaseState>();
  bool _navPaneOpen = false;
  bool _pinLeftPane = false;
  // רשימת המפרשים הנבחרים (עצמאית לחלונית זו, מסונכרנת פעם אחת עם מקור הפתיחה)
  List<String>? _selectedCommentatorsOverride;
  bool _navPaneAutoCloseQueued = false;
  final _commentarySearchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _tocSearchController = TextEditingController();
  final _externalCurrentIndex = ValueNotifier<int>(0);
  final _externalTotalResults = ValueNotifier<int>(0);
  final _externalSearchResultsByPath = ValueNotifier<Map<String, int>>({});
  final _externalSearchSnippets =
      ValueNotifier<List<CommentarySearchSnippet>>([]);
  bool _initialChapterResolved = false;
  final Map<String, List<InlineSpan>> _snippetSpansCache = {};

  late final TabController _navTabController;

  @override
  void initState() {
    super.initState();
    _navTabController = TabController(length: 2, vsync: this);
    _navTabController.addListener(() {
      if (_navTabController.index == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _searchFocusNode.requestFocus();
        });
      }
    });
    // סנכרון חד-פעמי של המפרשים הנבחרים עם חלונית המקור
    final sourceState = widget.tab.sourceTab.bloc.state;
    if (sourceState is TextBookLoaded &&
        sourceState.activeCommentators.isNotEmpty) {
      _selectedCommentatorsOverride =
          List<String>.from(sourceState.activeCommentators);
    }
    // טעינת הספר והמפרשים ב-BLoC העצמאי
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<SettingsBloc>().state;
      widget.tab.bloc.add(LoadContent(
        fontSize: settings.fontSize,
        showSplitView: false,
        removeNikud: settings.defaultRemoveNikud,
        loadCommentators: true,
      ));
    });
  }

  @override
  void dispose() {
    _navTabController.dispose();
    _commentarySearchController.dispose();
    _searchFocusNode.dispose();
    _tocSearchController.dispose();
    _externalCurrentIndex.dispose();
    _externalTotalResults.dispose();
    _externalSearchResultsByPath.dispose();
    _externalSearchSnippets.dispose();
    _openFilterNotifier.dispose();
    super.dispose();
  }

  List<TocEntry> _getChapters(List<TocEntry> toc) {
    final children = toc.expand((e) => e.children).toList();
    return children.isNotEmpty ? children : toc;
  }

  ({TocEntry? chapter, int verseIdx}) _findPos(
      List<TocEntry> chapters, int lineIndex) {
    final currentState = widget.tab.bloc.state;
    final content = currentState is TextBookLoaded
        ? currentState.content
        : const <String>[];
    TocEntry? bestChapter;
    int bestVerseIdx = _kAllChapter;
    for (final ch in chapters) {
      if (ch.index <= lineIndex) {
        bestChapter = ch;
        bestVerseIdx = _kAllChapter;
        for (int i = 0; i < ch.children.length; i++) {
          if (_isDuplicateChapterChild(
            ch,
            ch.children[i],
            _previewForChild(ch, ch.children[i], content),
          )) {
            continue;
          }
          if (ch.children[i].index <= lineIndex) {
            bestVerseIdx = i;
          } else {
            break;
          }
        }
        if (bestVerseIdx == _kAllChapter &&
            _isHeadingOnlyParagraphOffset(ch, 0, chapters, content) &&
            lineIndex == ch.index) {
          bestVerseIdx = _kAllChapter;
        }
      } else {
        break;
      }
    }
    return (chapter: bestChapter, verseIdx: bestVerseIdx);
  }

  List<InlineSpan> _buildSnippetHighlightSpans(
    BuildContext context,
    SettingsState settingsState, {
    required CommentarySearchSnippet snippet,
    required String query,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final cacheKey =
        '${settingsState.commentatorsFontFamily}|${colorScheme.onSurface.toARGB32()}|$query|${snippet.globalIndex}|${snippet.snippet}';
    final cached = _snippetSpansCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final spans = SnippetBuilder.buildHighlightSpans(
      plainText: snippet.snippet,
      query: query,
      defaultStyle: TextStyle(
        fontSize: 14,
        fontFamily: settingsState.commentatorsFontFamily,
        color: colorScheme.onSurface,
        height: 1.5,
      ),
      highlightStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: colorScheme.error,
      ),
      searchOptions: const {},
      alternativeWords: const {},
      searchDistance: 0,
      spacingValues: const {},
      fallbackToIndividualWords: true,
    );

    if (_snippetSpansCache.length > 500) {
      _snippetSpansCache.clear();
    }
    _snippetSpansCache[cacheKey] = spans;
    return spans;
  }

  List<int>? _computeIndexes(
      List<TocEntry> chapters, TocEntry? chapter, int verseIdx) {
    if (chapter == null) return null;

    if (verseIdx != _kAllChapter) {
      if (chapter.children.isNotEmpty) {
        // בחירת פסוק לפי TOC
        if (verseIdx < chapter.children.length) {
          final verse = chapter.children[verseIdx];
          if (verseIdx + 1 < chapter.children.length) {
            final nextIdx = chapter.children[verseIdx + 1].index;
            final count = nextIdx - verse.index;
            if (count > 1 && count <= 200) {
              return List.generate(count, (j) => verse.index + j);
            }
          }
          return [verse.index];
        }
      } else {
        // בחירת שורה/פסקה (ספרים ללא מבנה פסוק ב-TOC)
        // verseIdx = offset מתחילת הפרק
        return [chapter.index + verseIdx];
      }
    }

    // כל הפרק
    final ci = chapters.indexOf(chapter);
    if (ci >= 0 && ci + 1 < chapters.length) {
      final nextStart = chapters[ci + 1].index;
      final count = nextStart - chapter.index;
      if (count > 0) {
        return List.generate(count.clamp(1, 3000), (j) => chapter.index + j);
      }
    }
    if (chapter.children.isNotEmpty) {
      final lastChild = chapter.children.last;
      final count = lastChild.index - chapter.index + 1;
      if (count > 0) {
        return List.generate(count.clamp(1, 3000), (j) => chapter.index + j);
      }
    }
    return [chapter.index];
  }

  /// מחשב כמה שורות יש בפרק (לספרים ללא TOC ברמת פסוק)
  int _chapterLineCount(List<TocEntry> chapters, TocEntry chapter) {
    final ci = chapters.indexOf(chapter);
    final int end;
    if (ci >= 0 && ci + 1 < chapters.length) {
      end = chapters[ci + 1].index - 1;
    } else {
      end = chapter.index + 199;
    }
    return (end - chapter.index + 1).clamp(0, 200);
  }

  /// טוען את כל ה-links עבור הטווח הנוכחי דרך ה-BLoC העצמאי
  void _triggerLinkLoad(List<int> indices) {
    if (indices.isEmpty) return;
    widget.tab.bloc.add(LoadAllLinksForIndices(indices));
  }

  void _onChapterSelected(TocEntry ch, List<TocEntry> chapters) {
    setState(() {
      _selectedChapter = ch;
      _selectedVerseIdx = _kAllChapter;
    });
    // טוען links לכל הפרק
    final ci = chapters.indexOf(ch);
    final int endIdx;
    if (ci + 1 < chapters.length) {
      endIdx = chapters[ci + 1].index - 1;
    } else if (ch.children.isNotEmpty) {
      endIdx = ch.children.last.index;
    } else {
      endIdx = ch.index + 100;
    }
    final count = (endIdx - ch.index + 1).clamp(1, 3000);
    _triggerLinkLoad(List.generate(count, (j) => ch.index + j));
  }

  void _resolveInitialChapter(TextBookLoaded state) {
    if (_initialChapterResolved) return;

    final chapters = _getChapters(state.tableOfContents);
    final lineIndex = state.selectedIndex ??
        (state.visibleIndices.isNotEmpty ? state.visibleIndices.first : 0);

    if (chapters.isEmpty) {
      _initialChapterResolved = true;
      _triggerLinkLoad([lineIndex]);
      return;
    }

    final pos = _findPos(chapters, lineIndex);
    if (pos.chapter == null) return;

    _initialChapterResolved = true;
    _onChapterSelected(pos.chapter!, chapters);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TextBookBloc>.value(
      value: widget.tab.bloc,
      child: Builder(builder: (context) {
        return BlocConsumer<TextBookBloc, TextBookState>(
          listenWhen: (prev, curr) {
            if (prev is! TextBookLoaded || curr is! TextBookLoaded) {
              return false;
            }
            return prev.selectedIndex != curr.selectedIndex;
          },
          listener: (context, state) {
            if (state is! TextBookLoaded) return;
            _resolveInitialChapter(state);
            final idx = state.selectedIndex;
            if (idx == null) return;
            final chapters = _getChapters(state.tableOfContents);
            final pos = _findPos(chapters, idx);
            if (pos.chapter != null) {
              _onChapterSelected(pos.chapter!, chapters);
            }
          },
          buildWhen: (prev, curr) {
            if (prev is TextBookLoaded && curr is TextBookLoaded) {
              return prev.fontSize != curr.fontSize ||
                  prev.tableOfContents != curr.tableOfContents ||
                  prev.links != curr.links ||
                  prev.availableCommentators != curr.availableCommentators ||
                  prev.removeNikud != curr.removeNikud ||
                  prev.removePunctuation != curr.removePunctuation;
            }
            return true;
          },
          builder: (context, state) {
            final colorScheme = Theme.of(context).colorScheme;
            final appBarDecoration = Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant,
                width: 0.3,
              ),
            );

            if (state is! TextBookLoaded) {
              return Scaffold(
                appBar: AppBar(
                  backgroundColor: colorScheme.surfaceContainer,
                  shape: appBarDecoration,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  centerTitle: false,
                  leading: const IconButton(
                    icon: Icon(FluentIcons.navigation_24_regular, size: 20),
                    tooltip: 'ניווט',
                    onPressed: null,
                  ),
                  title: Text(
                    'מפרשים על ${widget.tab.sourceTab.book.title}',
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    ResponsiveActionBar(
                      overflowMenuOffset: const Offset(0, 8),
                      maxVisibleButtons: 999,
                      originalOrder: const [],
                      actions: [
                        for (final action in const [
                          (
                            icon: FluentIcons.text_font_24_regular,
                            tooltip: 'ניקוד',
                          ),
                          (
                            icon: FluentIcons.search_24_regular,
                            tooltip: 'חיפוש',
                          ),
                          (
                            icon: FluentIcons.apps_list_24_regular,
                            tooltip: 'בחירת מפרשים',
                          ),
                          (
                            icon: FluentIcons.bookmark_add_24_regular,
                            tooltip: 'הוסף סימניה',
                          ),
                          (
                            icon: FluentIcons.zoom_in_24_regular,
                            tooltip: 'הגדל את גודל הטקסט',
                          ),
                          (
                            icon: FluentIcons.zoom_out_24_regular,
                            tooltip: 'הקטן את גודל הטקסט',
                          ),
                          (
                            icon: FluentIcons.chevron_left_24_regular,
                            tooltip: 'הקטע הקודם',
                          ),
                          (
                            icon: FluentIcons.chevron_right_24_regular,
                            tooltip: 'הקטע הבא',
                          ),
                        ])
                          ActionButtonData(
                            widget: IconButton(
                              icon: Icon(action.icon),
                              tooltip: action.tooltip,
                              onPressed: null,
                            ),
                            icon: action.icon,
                            tooltip: action.tooltip,
                            onPressed: null,
                          ),
                      ],
                    ),
                  ],
                ),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            final chapters = _getChapters(state.tableOfContents);

            final effectiveIndexes =
                _computeIndexes(chapters, _selectedChapter, _selectedVerseIdx);

            return Scaffold(
              appBar: _buildAppBar(context, state, chapters),
              body: Stack(
                children: [
                  AdaptiveSidePane(
                    isOpen: _navPaneOpen || _pinLeftPane,
                    onClose: () {
                      if (!_pinLeftPane) setState(() => _navPaneOpen = false);
                    },
                    alignment: AlignmentDirectional.centerEnd,
                    paneWidth: 320,
                    minMainContentWidth: 400,
                    mainContent: NotificationListener<UserScrollNotification>(
                      onNotification: (notification) {
                        if (notification.direction != ScrollDirection.idle &&
                            _navPaneOpen &&
                            !_pinLeftPane &&
                            !_navPaneAutoCloseQueued) {
                          _navPaneAutoCloseQueued = true;
                          Future.microtask(() {
                            if (!mounted) {
                              _navPaneAutoCloseQueued = false;
                              return;
                            }
                            if (_navPaneOpen && !_pinLeftPane) {
                              setState(() {
                                _navPaneOpen = false;
                                _navPaneAutoCloseQueued = false;
                              });
                            } else {
                              _navPaneAutoCloseQueued = false;
                            }
                          });
                        }
                        return false;
                      },
                      child: CommentaryListBase(
                        key: _commentaryKey,
                        openBookCallback: widget.openBookCallback,
                        fontSize: state.fontSize,
                        indexes: effectiveIndexes,
                        showSearch: true,
                        useAvailableCommentators:
                            _selectedCommentatorsOverride == null,
                        selectedCommentatorsOverride:
                            _selectedCommentatorsOverride,
                        onSelectedCommentatorsOverrideChanged: (list) {
                          setState(() => _selectedCommentatorsOverride = list);
                        },
                        openFilterNotifier: _openFilterNotifier,
                        externalSearchController: _commentarySearchController,
                        externalCurrentIndexNotifier: _externalCurrentIndex,
                        externalTotalResultsNotifier: _externalTotalResults,
                        externalSearchResultsByPathNotifier:
                            _externalSearchResultsByPath,
                        externalSearchSnippetsNotifier: _externalSearchSnippets,
                      ),
                    ),
                    paneContent: _buildNavPanel(
                      context,
                      state: state,
                      chapters: chapters,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  void _selectVerseAndLoad(int verseIdx, List<TocEntry> chapters) {
    setState(() => _selectedVerseIdx = verseIdx);
    if (verseIdx == _kAllChapter) {
      _onChapterSelected(_selectedChapter!, chapters);
    } else if (_selectedChapter != null &&
        verseIdx < _selectedChapter!.children.length) {
      final verse = _selectedChapter!.children[verseIdx];
      final int endIdx = (verseIdx + 1 < _selectedChapter!.children.length)
          ? _selectedChapter!.children[verseIdx + 1].index - 1
          : verse.index + 50;
      final count = (endIdx - verse.index + 1).clamp(1, 200);
      _triggerLinkLoad(List.generate(count, (j) => verse.index + j));
    }
  }

  void _selectParaAndLoad(int paraIdx, List<TocEntry> chapters) {
    setState(() => _selectedVerseIdx = paraIdx);
    if (paraIdx == _kAllChapter) {
      _onChapterSelected(_selectedChapter!, chapters);
    } else if (_selectedChapter != null) {
      _triggerLinkLoad([_selectedChapter!.index + paraIdx]);
    }
  }

  // ── ניווט בין פרקים ────────────────────────────────────────────────────────

  void _navigateToPrevChapter(List<TocEntry> chapters) {
    if (_selectedChapter == null) return;
    final ci = chapters.indexOf(_selectedChapter!);
    if (ci > 0) _onChapterSelected(chapters[ci - 1], chapters);
  }

  void _navigateToNextChapter(List<TocEntry> chapters) {
    if (_selectedChapter == null) return;
    final ci = chapters.indexOf(_selectedChapter!);
    if (ci >= 0 && ci + 1 < chapters.length) {
      _onChapterSelected(chapters[ci + 1], chapters);
    }
  }

  void _navigateToPrevVerse(List<TocEntry> chapters) {
    final currentState = widget.tab.bloc.state;
    final content = currentState is TextBookLoaded
        ? currentState.content
        : const <String>[];
    final hasVerses = _selectedChapter?.children.isNotEmpty ?? false;
    if (hasVerses) {
      final selectable = _selectableVerseIndices(_selectedChapter!, content);
      final currentPos = _selectedVerseIdx == _kAllChapter
          ? -1
          : selectable.indexOf(_selectedVerseIdx);
      if (currentPos <= -1) return;
      if (currentPos == 0) {
        _selectVerseAndLoad(_kAllChapter, chapters);
        return;
      }
      _selectVerseAndLoad(selectable[currentPos - 1], chapters);
    } else {
      final selectable =
          _selectableParagraphOffsets(chapters, _selectedChapter!, content);
      final currentPos = _selectedVerseIdx == _kAllChapter
          ? -1
          : selectable.indexOf(_selectedVerseIdx);
      if (currentPos <= -1) return;
      if (currentPos == 0) {
        _selectParaAndLoad(_kAllChapter, chapters);
        return;
      }
      _selectParaAndLoad(selectable[currentPos - 1], chapters);
    }
  }

  void _navigateToNextVerse(List<TocEntry> chapters) {
    final currentState = widget.tab.bloc.state;
    final content = currentState is TextBookLoaded
        ? currentState.content
        : const <String>[];
    final hasVerses = _selectedChapter?.children.isNotEmpty ?? false;
    if (hasVerses) {
      final selectable = _selectableVerseIndices(_selectedChapter!, content);
      if (selectable.isEmpty) return;
      if (_selectedVerseIdx == _kAllChapter) {
        _selectVerseAndLoad(selectable.first, chapters);
        return;
      }
      final currentPos = selectable.indexOf(_selectedVerseIdx);
      if (currentPos < 0 || currentPos + 1 >= selectable.length) return;
      _selectVerseAndLoad(selectable[currentPos + 1], chapters);
    } else {
      final selectable =
          _selectableParagraphOffsets(chapters, _selectedChapter!, content);
      if (selectable.isEmpty) return;
      if (_selectedVerseIdx == _kAllChapter) {
        _selectParaAndLoad(selectable.first, chapters);
        return;
      }
      final currentPos = selectable.indexOf(_selectedVerseIdx);
      if (currentPos < 0 || currentPos + 1 >= selectable.length) return;
      _selectParaAndLoad(selectable[currentPos + 1], chapters);
    }
  }

  void _openSearchPane() {
    setState(() => _navPaneOpen = true);
    _navTabController.animateTo(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Future<void> _addBookmark(
    BuildContext context,
    TextBookLoaded state,
    List<int>? effectiveIndexes,
  ) async {
    final fallbackIndex = state.selectedIndex ??
        (state.visibleIndices.isNotEmpty ? state.visibleIndices.first : 0);
    final index = effectiveIndexes?.isNotEmpty == true
        ? effectiveIndexes!.first
        : fallbackIndex;
    final ref = addBookTitleToRef(
      await refFromIndex(index, state.book.tableOfContents),
      state.book.title,
    );
    if (!mounted || !context.mounted) return;

    final commentatorsToShow =
        _selectedCommentatorsOverride ?? state.activeCommentators;
    final added = context.read<BookmarkBloc>().addBookmark(
          ref: 'מפרשים | $ref',
          book: state.book,
          index: index,
          commentatorsToShow: commentatorsToShow,
          targetKind: BookmarkTargetKind.commentators,
        );
    UiSnack.showQuick(added ? 'הסימניה נוספה בהצלחה' : 'הסימניה כבר קיימת');
  }

  void _showBookmarksForCurrentBook(BuildContext context, Book book) {
    showDialog(
      context: context,
      builder: (_) => BookmarksDialog(bookFilter: book),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    TextBookLoaded state,
    List<TocEntry> chapters,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: colorScheme.surfaceContainer,
      shape: Border(
        bottom: BorderSide(
          color: colorScheme.outlineVariant,
          width: 0.3,
        ),
      ),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(FluentIcons.navigation_24_regular, size: 20),
        tooltip: 'ניווט',
        onPressed: () => setState(() => _navPaneOpen = !_navPaneOpen),
      ),
      title: Text(
        'מפרשים על ${state.book.title}',
        style: const TextStyle(fontSize: 16),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        ResponsiveActionBar(
          overflowMenuOffset: const Offset(0, 8),
          maxVisibleButtons: 999,
          actions: [
            // ניקוד
            ActionButtonData(
              widget: IconButton(
                icon: Icon(state.removeNikud
                    ? FluentIcons.text_font_24_regular
                    : FluentIcons.text_font_info_24_regular),
                tooltip: state.removeNikud ? 'הצג ניקוד' : 'הסתר ניקוד',
                onPressed: () => context
                    .read<TextBookBloc>()
                    .add(ToggleNikud(!state.removeNikud)),
              ),
              icon: state.removeNikud
                  ? FluentIcons.text_font_24_regular
                  : FluentIcons.text_font_info_24_regular,
              tooltip: state.removeNikud ? 'הצג ניקוד' : 'הסתר ניקוד',
              onPressed: () => context
                  .read<TextBookBloc>()
                  .add(ToggleNikud(!state.removeNikud)),
            ),
            // פיסוק (רק אם לא תנ"ך)
            if (!state.isTanach)
              ActionButtonData(
                widget: IconButton(
                  icon: Icon(state.removePunctuation
                      ? FluentIcons.text_quote_24_regular
                      : FluentIcons.text_clear_formatting_24_regular),
                  tooltip: state.removePunctuation ? 'הצג פיסוק' : 'הסתר פיסוק',
                  onPressed: () => context
                      .read<TextBookBloc>()
                      .add(TogglePunctuation(!state.removePunctuation)),
                ),
                icon: state.removePunctuation
                    ? FluentIcons.text_quote_24_regular
                    : FluentIcons.text_clear_formatting_24_regular,
                tooltip: state.removePunctuation ? 'הצג פיסוק' : 'הסתר פיסוק',
                onPressed: () => context
                    .read<TextBookBloc>()
                    .add(TogglePunctuation(!state.removePunctuation)),
              ),
            // חיפוש
            ActionButtonData(
              widget: IconButton(
                icon: const Icon(FluentIcons.search_24_regular),
                tooltip: 'חיפוש',
                onPressed: _openSearchPane,
              ),
              icon: FluentIcons.search_24_regular,
              tooltip: 'חיפוש',
              onPressed: _openSearchPane,
            ),
            // בחירת מפרשים
            ActionButtonData(
              widget: CommentatorsFilterButton(
                isActive: false,
                onPressed: () => _openFilterNotifier.value++,
              ),
              icon: FluentIcons.apps_list_24_regular,
              tooltip: 'בחירת מפרשים',
              onPressed: () => _openFilterNotifier.value++,
            ),
            ActionButtonData(
              widget: IconButton(
                icon: const Icon(FluentIcons.bookmark_add_24_regular),
                tooltip: 'הוסף סימניה',
                onPressed: () => _addBookmark(
                    context,
                    state,
                    _computeIndexes(
                      chapters,
                      _selectedChapter,
                      _selectedVerseIdx,
                    )),
              ),
              icon: FluentIcons.bookmark_add_24_regular,
              tooltip: 'הוסף סימניה',
              onPressed: () => _addBookmark(
                context,
                state,
                _computeIndexes(chapters, _selectedChapter, _selectedVerseIdx),
              ),
            ),
            // הגדל טקסט
            ActionButtonData(
              widget: IconButton(
                icon: const Icon(FluentIcons.zoom_in_24_regular),
                tooltip: 'הגדל את גודל הטקסט',
                onPressed: () => context
                    .read<TextBookBloc>()
                    .add(UpdateFontSize((state.fontSize + 3).clamp(15, 50))),
              ),
              icon: FluentIcons.zoom_in_24_regular,
              tooltip: 'הגדל את גודל הטקסט',
              onPressed: () => context
                  .read<TextBookBloc>()
                  .add(UpdateFontSize((state.fontSize + 3).clamp(15, 50))),
            ),
            // הקטן טקסט
            ActionButtonData(
              widget: IconButton(
                icon: const Icon(FluentIcons.zoom_out_24_regular),
                tooltip: 'הקטן את גודל הטקסט',
                onPressed: () => context
                    .read<TextBookBloc>()
                    .add(UpdateFontSize((state.fontSize - 3).clamp(15, 50))),
              ),
              icon: FluentIcons.zoom_out_24_regular,
              tooltip: 'הקטן את גודל הטקסט',
              onPressed: () => context
                  .read<TextBookBloc>()
                  .add(UpdateFontSize((state.fontSize - 3).clamp(15, 50))),
            ),
            // קטע קודם
            ActionButtonData(
              widget: IconButton(
                icon: const Icon(FluentIcons.chevron_left_24_regular),
                tooltip: 'הקטע הקודם',
                onPressed: () => _navigateToPrevVerse(chapters),
              ),
              icon: FluentIcons.chevron_left_24_regular,
              tooltip: 'הקטע הקודם',
              onPressed: () => _navigateToPrevVerse(chapters),
            ),
            // קטע הבא
            ActionButtonData(
              widget: IconButton(
                icon: const Icon(FluentIcons.chevron_right_24_regular),
                tooltip: 'הקטע הבא',
                onPressed: () => _navigateToNextVerse(chapters),
              ),
              icon: FluentIcons.chevron_right_24_regular,
              tooltip: 'הקטע הבא',
              onPressed: () => _navigateToNextVerse(chapters),
            ),
          ],
          alwaysInMenu: [
            ActionButtonData(
              widget: IconButton(
                icon: const Icon(FluentIcons.bookmark_multiple_24_regular),
                tooltip: 'סימניות בספר זה',
                onPressed: () =>
                    _showBookmarksForCurrentBook(context, state.book),
              ),
              icon: FluentIcons.bookmark_multiple_24_regular,
              tooltip: 'סימניות בספר זה',
              onPressed: () =>
                  _showBookmarksForCurrentBook(context, state.book),
            ),
            ActionButtonData(
              widget: IconButton(
                icon: const Icon(FluentIcons.arrow_previous_24_filled),
                tooltip: 'הפרק הקודם',
                onPressed: () => _navigateToPrevChapter(chapters),
              ),
              icon: FluentIcons.arrow_previous_24_filled,
              tooltip: 'הפרק הקודם',
              onPressed: () => _navigateToPrevChapter(chapters),
            ),
            ActionButtonData(
              widget: IconButton(
                icon: const Icon(FluentIcons.arrow_next_24_filled),
                tooltip: 'הפרק הבא',
                onPressed: () => _navigateToNextChapter(chapters),
              ),
              icon: FluentIcons.arrow_next_24_filled,
              tooltip: 'הפרק הבא',
              onPressed: () => _navigateToNextChapter(chapters),
            ),
          ],
        ),
      ],
    );
  }

  // ── פאנל ניווט (paneContent) ───────────────────────────────────────────────

  Widget _buildNavPanel(
    BuildContext context, {
    required TextBookLoaded state,
    required List<TocEntry> chapters,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ─── כותרת TabBar (זהה לטאב הטקסט) ─────────────────────────
        SizedBox(
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _navTabController,
                    tabs: const [
                      Tab(
                        icon: Icon(FluentIcons.navigation_24_regular, size: 16),
                        iconMargin: EdgeInsets.only(bottom: 1),
                        height: 44,
                        child: Text('ניווט', style: TextStyle(fontSize: 11)),
                      ),
                      Tab(
                        icon: Icon(FluentIcons.search_24_regular, size: 16),
                        iconMargin: EdgeInsets.only(bottom: 1),
                        height: 44,
                        child: Text('חיפוש', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    labelColor: colorScheme.primary,
                    unselectedLabelColor:
                        colorScheme.onSurface.withValues(alpha: 0.6),
                    indicatorColor: colorScheme.primary,
                    dividerColor: Colors.transparent,
                    splashBorderRadius: BorderRadius.circular(12),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _pinLeftPane = !_pinLeftPane),
                  icon: AnimatedRotation(
                    turns: _pinLeftPane ? -0.125 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _pinLeftPane
                          ? FluentIcons.pin_24_filled
                          : FluentIcons.pin_24_regular,
                    ),
                  ),
                  color: _pinLeftPane ? colorScheme.primary : null,
                  tooltip: _pinLeftPane ? 'בטל נעיצה' : 'נעץ את הפאנל',
                ),
              ],
            ),
          ),
        ),
        // ─── תוכן TabBarView ──────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _navTabController,
            children: [
              _buildTocList(context,
                  chapters: chapters, content: state.content),
              _buildCommentarySearchPanel(context),
            ],
          ),
        ),
      ],
    );
  }

  // ── פאנל חיפוש ────────────────────────────────────────────────────────────

  Widget _buildCommentarySearchPanel(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _commentarySearchController,
      builder: (_, val, __) {
        final hasQuery = val.text.isNotEmpty;
        return ValueListenableBuilder<int>(
          valueListenable: _externalTotalResults,
          builder: (_, total, __) => ValueListenableBuilder<int>(
            valueListenable: _externalCurrentIndex,
            builder: (_, current, __) =>
                ValueListenableBuilder<List<CommentarySearchSnippet>>(
              valueListenable: _externalSearchSnippets,
              builder: (context, snippets, __) {
                return SearchPaneBase(
                  searchController: _commentarySearchController,
                  focusNode: _searchFocusNode,
                  hintText: 'חפש בתוך המפרשים המוצגים...',
                  isNoResults: hasQuery && total == 0,
                  resetSearchCallback: _commentarySearchController.clear,
                  resultCountString: hasQuery && total > 0
                      ? 'תוצאה ${current + 1} מתוך $total'
                      : null,
                  resultToolbar: hasQuery && total > 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OtzariaSearchAction.prevResult(
                              onPressed: current > 0
                                  ? () => _commentaryKey.currentState
                                      ?.navigateSearchPrev()
                                  : null,
                            ),
                            OtzariaSearchAction.nextResult(
                              onPressed: current < total - 1
                                  ? () => _commentaryKey.currentState
                                      ?.navigateSearchNext()
                                  : null,
                            ),
                          ],
                        )
                      : null,
                  resultsWidget: _buildSearchResultsList(
                    context,
                    query: val.text,
                    snippets: snippets,
                    total: total,
                    currentIdx: current,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsList(
    BuildContext context, {
    required String query,
    required List<CommentarySearchSnippet> snippets,
    required int total,
    required int currentIdx,
  }) {
    if (query.isEmpty) {
      return const SizedBox.shrink();
    }
    if (snippets.isEmpty) {
      // total>0 בלבד מגיע לכאן (אם total==0 מוצג 'אין תוצאות' ע"י SearchPaneBase)
      return Center(
        child: Text(
          'טוען תוצאות...',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    // בניית רשימה מקובצת עם כותרות מפרשים
    final List<_SearchResultItem> items = [];
    String? lastPath;
    for (final snippet in snippets) {
      if (snippet.path != lastPath) {
        items.add(
            _SearchResultItem.header(utils.getTitleFromPath(snippet.path)));
        lastPath = snippet.path;
      }
      items.add(_SearchResultItem.result(snippet));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isHeader) {
          return Padding(
            padding:
                const EdgeInsets.only(top: 8, bottom: 4, right: 4, left: 4),
            child: Row(
              children: [
                Icon(
                  FluentIcons.text_align_right_24_regular,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.header!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }

        final snippet = item.snippet!;
        final isSelected = snippet.globalIndex == currentIdx;
        return BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            final highlightedSpans = _buildSnippetHighlightSpans(
              context,
              settingsState,
              snippet: snippet,
              query: query,
            );
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppSurfaces.selectedItem(
                        Theme.of(context).colorScheme)
                    : null,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
                onTap: () => _commentaryKey.currentState
                    ?.navigateToGlobalIndex(snippet.globalIndex),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text.rich(
                    TextSpan(children: highlightedSpans),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── רשימת פרקים (לשונית ניווט) ────────────────────────────────────────────

  Widget _buildTocList(
    BuildContext context, {
    required List<TocEntry> chapters,
    required List<String> content,
  }) {
    if (chapters.isEmpty) {
      return const Center(child: Text('אין תוכן עניינים'));
    }
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _tocSearchController,
            builder: (_, val, __) => RtlTextField(
              controller: _tocSearchController,
              decoration: InputDecoration(
                hintText: 'איתור כותרת...',
                prefixIcon: const Icon(FluentIcons.search_24_regular),
                suffixIcon: val.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(FluentIcons.dismiss_24_regular),
                        onPressed: () => _tocSearchController.clear(),
                      )
                    : null,
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _tocSearchController,
            builder: (context, val, _) {
              final query = val.text;
              final filteredChapters = query.isEmpty
                  ? chapters
                  : chapters.where((ch) => ch.text.contains(query)).toList();
              final items =
                  _buildVisibleTocItems(filteredChapters, chapters, content);
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  if (item.isChapter) {
                    final ch = item.chapter!;
                    final isSelected = ch == _selectedChapter;

                    return InkWell(
                      onTap: () {
                        if (isSelected) {
                          setState(() => _selectedChapter = null);
                        } else {
                          setState(() {
                            _selectedChapter = ch;
                            _selectedVerseIdx = _kAllChapter;
                          });
                          _onChapterSelected(ch, chapters);
                        }
                      },
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
                        padding: const EdgeInsets.only(
                            right: 16, left: 8, top: 12, bottom: 12),
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
                                ch.text,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: colorScheme.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                isSelected
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

                  return _buildSubItem(
                    context,
                    text: item.text!,
                    isSelected: item.isSelected,
                    onTap: item.onTap!,
                    colorScheme: colorScheme,
                    isAllChapter: item.isAllChapter,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// מחזיר תצוגה מקדימה של ~4 מילים ראשונות של הפסקה
  String _getParaPreview(String rawText) {
    final plain =
        utils.stripHtmlIfNeeded(rawText).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (plain.isEmpty) return '';
    const maxChars = 40;
    if (plain.length <= maxChars) return plain;
    final lastSpace = plain.lastIndexOf(' ', maxChars);
    final cut = lastSpace > 0 ? lastSpace : maxChars;
    return '${plain.substring(0, cut)}...';
  }

  bool _isDuplicateChapterChild(
    TocEntry chapter,
    TocEntry child,
    String preview,
  ) {
    if (child.index != chapter.index) {
      return false;
    }
    final normalizedChapter = chapter.text.trim();
    final normalizedChild = child.text.trim();
    final normalizedPreview = preview.trim();
    return normalizedChild == normalizedChapter ||
        normalizedPreview == normalizedChapter ||
        normalizedPreview.startsWith(normalizedChapter);
  }

  String _previewForChild(
    TocEntry chapter,
    TocEntry child,
    List<String> content,
  ) {
    final textFromContent =
        child.index < content.length ? content[child.index] : '';
    return textFromContent.trim().isNotEmpty
        ? _getParaPreview(textFromContent)
        : child.text;
  }

  bool _isHeadingOnlyParagraphOffset(
    TocEntry chapter,
    int offset,
    List<TocEntry> chapters,
    List<String> content,
  ) {
    if (offset != 0) return false;
    final lineIndex = chapter.index + offset;
    final textFromContent =
        lineIndex < content.length ? content[lineIndex] : '';
    if (textFromContent.trim().isEmpty) return false;
    final preview = _getParaPreview(textFromContent);
    return preview.trim() == chapter.text.trim();
  }

  List<int> _selectableVerseIndices(TocEntry chapter, List<String> content) {
    return chapter.children
        .asMap()
        .entries
        .where((entry) => !_isDuplicateChapterChild(
              chapter,
              entry.value,
              _previewForChild(chapter, entry.value, content),
            ))
        .map((entry) => entry.key)
        .toList();
  }

  List<int> _selectableParagraphOffsets(
    List<TocEntry> chapters,
    TocEntry chapter,
    List<String> content,
  ) {
    final lineCount = _chapterLineCount(chapters, chapter);
    return List<int>.generate(lineCount, (i) => i)
        .where(
          (offset) => !_isHeadingOnlyParagraphOffset(
            chapter,
            offset,
            chapters,
            content,
          ),
        )
        .toList();
  }

  List<_TocListItem> _buildVisibleTocItems(
    List<TocEntry> visibleChapters,
    List<TocEntry> allChapters,
    List<String> content,
  ) {
    final items = <_TocListItem>[];
    for (final chapter in visibleChapters) {
      items.add(_TocListItem.chapter(chapter));
      if (chapter != _selectedChapter) {
        continue;
      }

      items.add(
        _TocListItem.subItem(
          text: allUnitLabel(chapter.text),
          isSelected: _selectedVerseIdx == _kAllChapter,
          isAllChapter: true,
          onTap: () {
            setState(() => _selectedVerseIdx = _kAllChapter);
            _onChapterSelected(chapter, allChapters);
          },
        ),
      );

      if (chapter.children.isNotEmpty) {
        for (final i in _selectableVerseIndices(chapter, content)) {
          final child = chapter.children[i];
          final preview = _previewForChild(chapter, child, content);
          if (preview.isEmpty) continue;
          items.add(
            _TocListItem.subItem(
              text: preview,
              isSelected: _selectedVerseIdx == i,
              onTap: () => _selectVerseAndLoad(i, allChapters),
            ),
          );
        }
        continue;
      }

      for (final i in _selectableParagraphOffsets(
        allChapters,
        chapter,
        content,
      )) {
        final lineIndex = chapter.index + i;
        final textFromContent =
            lineIndex < content.length ? content[lineIndex] : '';
        final preview = textFromContent.trim().isNotEmpty
            ? _getParaPreview(textFromContent)
            : 'פסקה ${i + 1}';
        if (preview.isEmpty) continue;
        items.add(
          _TocListItem.subItem(
            text: preview,
            isSelected: _selectedVerseIdx == i,
            onTap: () => _selectParaAndLoad(i, allChapters),
          ),
        );
      }
    }
    return items;
  }

  Widget _buildSubItem(
    BuildContext context, {
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    bool isAllChapter = false,
  }) {
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
              isAllChapter
                  ? FluentIcons.book_24_regular
                  : FluentIcons.text_bullet_list_24_regular,
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
}

/// פריט עזר לרשימת תוצאות חיפוש מקובצת (כותרת או תוצאה)
class _SearchResultItem {
  final String? header;
  final CommentarySearchSnippet? snippet;

  const _SearchResultItem.header(this.header) : snippet = null;
  const _SearchResultItem.result(this.snippet) : header = null;

  bool get isHeader => header != null;
}

class _TocListItem {
  final TocEntry? chapter;
  final String? text;
  final bool isSelected;
  final bool isAllChapter;
  final VoidCallback? onTap;

  const _TocListItem.chapter(this.chapter)
      : text = null,
        isSelected = false,
        isAllChapter = false,
        onTap = null;

  const _TocListItem.subItem({
    required this.text,
    required this.isSelected,
    required this.onTap,
    this.isAllChapter = false,
  }) : chapter = null;

  bool get isChapter => chapter != null;
}
