import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:otzaria/widgets/text/otzaria_search_field.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_event.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_state.dart';
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/personal_notes/repository/personal_notes_repository.dart';
import 'package:otzaria/personal_notes/services/personal_notes_import_export_service.dart';
import 'package:otzaria/personal_notes/storage/personal_notes_database.dart';
import 'package:otzaria/personal_notes/widgets/personal_note_content_view.dart';
import 'package:otzaria/personal_notes/widgets/personal_note_editor.dart';
import 'package:otzaria/personal_notes/widgets/personal_note_editor_dialog.dart';
import 'package:otzaria/personal_notes/widgets/personal_notes_export_dialog.dart';
import 'package:otzaria/personal_notes/utils/note_location_ref.dart';
import 'package:otzaria/widgets/dialogs/dialogs_exports.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/library/bloc/library_state.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/widgets/lists/navigation_tree_tile.dart';
import 'package:otzaria/utils/navigation/open_book.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/shortcuts/shortcut_helper.dart';
import 'package:otzaria/shortcuts/shortcut_validator.dart';
import 'package:otzaria/widgets/navigation/app_top_bar.dart';
import 'package:otzaria/widgets/controls/action_buttons.dart';
import 'package:otzaria/widgets/layout/adaptive_side_pane.dart';
import 'package:otzaria/widgets/layout/app_card.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/tools/calendar/helpers/calendar_date_helpers.dart';

class PersonalNotesManagerScreen extends StatefulWidget {
  const PersonalNotesManagerScreen({
    super.key,
    this.repository,
    this.importExportService,
  });

  final PersonalNotesRepository? repository;
  final PersonalNotesImportExportService? importExportService;

  @override
  State<PersonalNotesManagerScreen> createState() =>
      _PersonalNotesManagerScreenState();
}

class _PersonalNotesManagerScreenState
    extends State<PersonalNotesManagerScreen> {
  late final PersonalNotesRepository _repository;
  late final PersonalNotesImportExportService _importExportService;

  List<BookNotesInfo> _books = [];
  String? _selectedFilter; // null = all notes
  bool _isLoadingBooks = true;
  String? _booksError;
  final Map<String, PersonalNotesState> _bookStates = {};
  final Map<String, bool> _expansionState = {};
  // קאש ל-TOC לכל ספר, לחישוב כתובת המיקום של ההערות. נטען עצלן פעם אחת.
  final Map<String, Future<List<TocEntry>?>> _tocFutureByBook = {};
  bool _isNavigationVisible = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _windowFocusNode = FocusNode(skipTraversal: true);
  final ScrollController _contentScrollController = ScrollController();
  String _searchQuery = '';
  double _navigationWidth = 250.0;
  // טווח תאריכים לסינון לפי תאריך עדכון ההערה. null = ללא סינון תאריכים.
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PersonalNotesRepository();
    _importExportService =
        widget.importExportService ?? PersonalNotesImportExportService();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    // בריענון - לא מציגים ספינר אם כבר יש ספרים
    // בטעינה ראשונה - נשאר במצב טעינה
    final isRefresh = _books.isNotEmpty;

    if (!isRefresh) {
      setState(() {
        _isLoadingBooks = true;
        _booksError = null;
      });
    } else if (_booksError != null) {
      setState(() {
        _booksError = null;
      });
    }

    try {
      final books = await _repository.listBooksWithNotes();
      if (!mounted) return;
      setState(() {
        _books = books;
        _isLoadingBooks = false;
        _booksError = null;
      });
      _scheduleNotesLoad(books);
    } catch (e) {
      if (!mounted) return;
      if (_books.isEmpty) {
        setState(() {
          _booksError = e.toString();
          _isLoadingBooks = false;
        });
      } else {
        UiSnack.showError(
            'personal_notes.load_error'.tr(namedArgs: {'error': '$e'}));
      }
    }
  }

  void _scheduleNotesLoad(List<BookNotesInfo> books) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<PersonalNotesBloc>();
      for (final book in books) {
        bloc.add(LoadPersonalNotes(book.bookId));
      }
    });
  }

  void _onFilterChanged(String? filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  /// פתיחת בורר טווח תאריכים לסינון ההערות לפי תאריך עדכון.
  ///
  /// משתמש בשני דיאלוגי [showDatePicker] קומפקטיים ברצף (תחילה תאריך התחלה ואז
  /// תאריך סיום) במקום [showDateRangePicker] מסך-מלא — כך מקבלים דיאלוג קטן רגיל
  /// עם ניווט נוח בין חודשים ושנים.
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(2000);

    final start = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: today,
      initialDate: _dateRange?.start ?? today,
      helpText: 'personal_notes.pick_start_date'.tr(),
      cancelText: 'personal_notes.cancel'.tr(),
      confirmText: 'personal_notes.date_next'.tr(),
    );
    if (!mounted || start == null) return;

    final previousEnd = _dateRange?.end;
    final end = await showDatePicker(
      context: context,
      firstDate: start,
      lastDate: today,
      initialDate: (previousEnd != null && !previousEnd.isBefore(start))
          ? previousEnd
          : today,
      helpText: 'personal_notes.pick_end_date'.tr(),
      cancelText: 'personal_notes.cancel'.tr(),
      confirmText: 'personal_notes.date_filter_apply'.tr(),
    );
    if (!mounted || end == null) return;

    setState(() {
      _dateRange = DateTimeRange(start: start, end: end);
    });
  }

  void _clearDateRange() {
    setState(() {
      _dateRange = null;
    });
  }

  /// פורמט תאריך לועזי קצר להצגה בבאנר הסינון.
  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  void requestKeyboardFocus() {
    if (!mounted || !_windowFocusNode.canRequestFocus) return;
    if (!_windowFocusNode.hasFocus) _windowFocusNode.requestFocus();
  }

  void _focusSearchField() {
    if (!mounted || !_searchFocusNode.canRequestFocus) return;
    if (!_searchFocusNode.hasFocus) _searchFocusNode.requestFocus();
  }

  KeyEventResult _handleWindowKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (FocusManager.instance.primaryFocus != _windowFocusNode) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      _scrollContent(forward: true);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      _scrollContent(forward: false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrollContent({required bool forward}) {
    if (!_contentScrollController.hasClients) return;
    final position = _contentScrollController.position;
    final delta = (position.viewportDimension * 0.85) * (forward ? 1 : -1);
    final target =
        (position.pixels + delta).clamp(0.0, position.maxScrollExtent);
    _contentScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _windowFocusNode.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBooks) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_booksError != null && _books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'personal_notes.load_error_detail'
                  .tr(namedArgs: {'error': _booksError!}),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadBooks,
              child: Text('personal_notes.retry'.tr()),
            ),
          ],
        ),
      );
    }

    final searchShortcutSetting = context.select(
      (SettingsBloc bloc) =>
          bloc.state.shortcuts['key-shortcut-search-current-window'] ??
          ShortcutValidator
              .defaultShortcuts['key-shortcut-search-current-window'] ??
          'ctrl+f',
    );
    return CallbackShortcuts(
      bindings: {
        ShortcutHelper.activatorFromShortcut(searchShortcutSetting) ??
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _focusSearchField();
        },
      },
      child: Focus(
        focusNode: _windowFocusNode,
        autofocus: true,
        onKeyEvent: _handleWindowKeyEvent,
        child: BlocListener<PersonalNotesBloc, PersonalNotesState>(
          listener: (context, state) {
            // Store the state for each book and trigger rebuild
            if (state.bookId != null) {
              setState(() {
                _bookStates[state.bookId!] = state;
              });

              // If this is a new book (not in _books list), refresh the books list
              final bookExists =
                  _books.any((book) => book.bookId == state.bookId);
              if (!bookExists &&
                  (state.locatedNotes.isNotEmpty ||
                      state.missingNotes.isNotEmpty)) {
                _loadBooks();
              }
            }
          },
          child: Column(
            children: [
              // שורת כלים עליונה לכל רוחב העמוד
              _buildTopBar(),
              // תוכן העמוד
              Expanded(
                child: PrimaryScrollController(
                  controller: _contentScrollController,
                  child: AdaptiveSidePane(
                    isOpen: _isNavigationVisible,
                    alignment: AlignmentDirectional
                        .centerEnd, // ימין בעברית (RTL) - סרגל ניווט
                    mainContent: Column(
                      children: [
                        if (_dateRange != null) _buildDateFilterBanner(),
                        Expanded(child: _buildAllNotesList()),
                      ],
                    ),
                    paneWidth: _navigationWidth,
                    minMainContentWidth: 320,
                    onClose: () => setState(() => _isNavigationVisible = false),
                    onOpen: () => setState(() => _isNavigationVisible = true),
                    isResizable: true,
                    minPaneWidth: 150,
                    maxPaneWidth: 500,
                    onPaneWidthChanged: (nextWidth) {
                      _navigationWidth = nextWidth;
                    },
                    paneContent: _buildNotesTree(),
                    wrapPaneInFloatingPanel: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final isCompact = settingsState.compactMenuMode;
        return AppTopBar(
          leadingItems: [
            AppTopBarItem(
              widget: IconButton(
                tooltip: _isNavigationVisible
                    ? 'personal_notes.hide_navigation'.tr()
                    : 'personal_notes.show_navigation'.tr(),
                onPressed: () {
                  setState(() {
                    _isNavigationVisible = !_isNavigationVisible;
                  });
                },
                icon: AnimatedSwitcher(
                  duration: AppTokens.animFast,
                  transitionBuilder: (child, animation) => RotationTransition(
                    turns:
                        Tween<double>(begin: 0.5, end: 0.0).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    _isNavigationVisible
                        ? FluentIcons.panel_right_contract_24_regular
                        : FluentIcons.panel_right_24_regular,
                    key: ValueKey(_isNavigationVisible),
                    size: 24,
                  ),
                ),
                visualDensity: VisualDensity.standard,
                splashRadius: 22,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ],
          center: OtzariaSearchField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            hintText: 'personal_notes.search_hint'.tr(),
            onSubmitted: (_) => requestKeyboardFocus(),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            onClear: () {
              setState(() {
                _searchQuery = '';
              });
            },
          ),
          trailingItems: [
            AppTopBarItem(
              widget: ToolbarActionButton(
                compact: isCompact,
                tooltip: _dateRange != null
                    ? 'personal_notes.date_filter_active'.tr()
                    : 'personal_notes.filter_by_date'.tr(),
                icon: _dateRange != null
                    ? FluentIcons.calendar_checkmark_24_filled
                    : FluentIcons.calendar_24_regular,
                onPressed: _pickDateRange,
              ),
            ),
            AppTopBarItem(
              widget: ToolbarActionButton(
                compact: isCompact,
                tooltip: 'personal_notes.refresh'.tr(),
                icon: FluentIcons.arrow_clockwise_24_regular,
                onPressed: _loadBooks,
              ),
            ),
            AppTopBarItem(
              widget: ToolbarActionButton(
                compact: isCompact,
                tooltip: 'personal_notes.backup_tooltip'.tr(),
                icon: FluentIcons.arrow_download_24_regular,
                onPressed: _exportNotes,
              ),
            ),
            AppTopBarItem(
              widget: ToolbarActionButton(
                compact: isCompact,
                tooltip: 'personal_notes.export_text_tooltip'.tr(),
                icon: FluentIcons.document_text_24_regular,
                onPressed: _exportNotesToText,
              ),
            ),
            AppTopBarItem(
              widget: ToolbarActionButton(
                compact: isCompact,
                tooltip: 'personal_notes.import_tooltip'.tr(),
                icon: FluentIcons.arrow_upload_24_regular,
                onPressed: _importNotes,
              ),
            ),
          ],
        );
      },
    );
  }

  /// טוען (פעם אחת, עם קאש) את ה-TOC של ספר טקסט לפי כותרתו, לחישוב המיקום.
  /// מחזיר Future ל-null כשהספר אינו ספר טקסט או שאינו בספרייה.
  Future<List<TocEntry>?> _tocFor(String bookId) {
    return _tocFutureByBook.putIfAbsent(bookId, () {
      final library = context.read<LibraryBloc>().state.library;
      final book = library?.findBookByTitle(bookId, TextBook);
      if (book is! TextBook) return Future.value(null);
      return book.tableOfContents;
    });
  }

  List<PersonalNote> _collectAllNotes() {
    final allNotes = <PersonalNote>[];
    for (final book in _books) {
      final state = _bookStates[book.bookId];
      if (state == null) continue;
      allNotes.addAll(state.locatedNotes);
      allNotes.addAll(state.missingNotes);
    }
    return allNotes;
  }

  Future<void> _exportNotes() async {
    final selection = await showDialog<NotesExportSelection>(
      context: context,
      builder: (context) => PersonalNotesExportDialog(
        allNotes: _collectAllNotes(),
        title: 'personal_notes.backup_title'.tr(),
        confirmText: 'personal_notes.backup_confirm'.tr(),
      ),
    );
    if (!mounted) return;
    if (selection == null || selection.notes.isEmpty) return;

    final path = await FilePicker.saveFile(
      dialogTitle: 'personal_notes.backup_location_dialog'.tr(),
      fileName: 'otzaria_notes_backup.json',
      allowedExtensions: ['json'],
      type: FileType.custom,
      lockParentWindow: true,
    );
    if (!mounted) return;
    if (path == null) return;

    await _importExportService.exportToFile(
      path: path,
      notes: selection.notes,
      description: selection.description,
    );

    if (!mounted) return;
    UiSnack.show('personal_notes.backup_success'.tr());
  }

  Future<void> _exportNotesToText() async {
    final selection = await showDialog<NotesExportSelection>(
      context: context,
      builder: (context) => PersonalNotesExportDialog(
        allNotes: _collectAllNotes(),
        title: 'personal_notes.export_text_title'.tr(),
        confirmText: 'personal_notes.export_text_confirm'.tr(),
      ),
    );
    if (!mounted) return;
    if (selection == null || selection.notes.isEmpty) return;

    final path = await FilePicker.saveFile(
      dialogTitle: 'personal_notes.export_text_location_dialog'.tr(),
      fileName: 'otzaria_notes.txt',
      allowedExtensions: ['txt'],
      type: FileType.custom,
      lockParentWindow: true,
    );
    if (!mounted) return;
    if (path == null) return;

    await _importExportService.exportToTextFile(
      path: path,
      notes: selection.notes,
      description: selection.description,
    );

    if (!mounted) return;
    UiSnack.show('personal_notes.export_text_success'.tr());
  }

  Future<void> _importNotes() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'personal_notes.select_import_file'.tr(),
      allowedExtensions: ['json'],
      type: FileType.custom,
      lockParentWindow: true,
    );
    if (!mounted) return;
    if (picked == null || picked.files.isEmpty) return;

    final strategy = await showDialog<NotesImportConflictStrategy>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('personal_notes.import_conflicts_title'.tr()),
        content: Text('personal_notes.import_conflicts_content'.tr()),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(NotesImportConflictStrategy.merge),
            child: Text('personal_notes.import_merge'.tr()),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(NotesImportConflictStrategy.skip),
            child: Text('personal_notes.import_skip'.tr()),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(NotesImportConflictStrategy.keepBoth),
            child: Text('personal_notes.import_keep_both'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context)
                .pop(NotesImportConflictStrategy.overwrite),
            child: Text('personal_notes.import_overwrite'.tr()),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (strategy == null) return;

    final summary = await _importExportService.importFromFile(
      path: picked.files.first.path!,
      strategy: strategy,
    );

    if (!mounted) return;
    UiSnack.show(
      'personal_notes.import_summary'.tr(namedArgs: {
        'inserted': '${summary.inserted}',
        'updated': '${summary.updated}',
        'skipped': '${summary.skipped}',
        'duplicated': '${summary.duplicated}',
      }),
    );
    _loadBooks();
  }

  Widget _buildNotesTree() {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, libraryState) {
        if (libraryState.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (libraryState.error != null) {
          return Center(child: Text('Error: ${libraryState.error}'));
        }

        if (libraryState.library == null) {
          return const Center(child: Text('No library data available'));
        }

        final rootCategory = libraryState.library!;
        final totalNotesCount =
            _getNotesCountForCategory(rootCategory) + _getMissingNotesCount();
        final isRootExpanded = _expansionState['/personal_notes_root'] ?? true;
        final isRootSelected = _selectedFilter == null;

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            Column(
              children: [
                // Root "הערות אישיות" folder
                NavigationTreeTile.category(
                  title: 'personal_notes.title'.tr(),
                  level: 0,
                  isSelected: isRootSelected,
                  isExpanded: isRootExpanded,
                  hasChildren: true,
                  count: totalNotesCount > 0 ? totalNotesCount : null,
                  onTap: () => _onFilterChanged(null),
                  onToggleExpand: () {
                    setState(() {
                      _expansionState['/personal_notes_root'] = !isRootExpanded;
                    });
                  },
                ),
                if (isRootExpanded) ...[
                  ..._buildCategoryChildren(rootCategory, 0),
                  _buildMissingNotesTile(),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  int _getMissingNotesCount() {
    int count = 0;
    for (final state in _bookStates.values) {
      count += state.missingNotes.length;
    }
    return count;
  }

  int _getNotesCountForBook(String bookTitle) {
    final state = _bookStates[bookTitle];
    if (state != null) {
      return state.locatedNotes.length + state.missingNotes.length;
    }
    return 0;
  }

  int _getNotesCountForCategory(Category category) {
    int count = 0;

    // Deduplicate books by title to avoid counting notes twice
    // when the same book exists in both PDF and text formats
    final seenTitles = <String>{};
    for (final book in category.books) {
      if (!seenTitles.contains(book.title)) {
        count += _getNotesCountForBook(book.title);
        seenTitles.add(book.title);
      }
    }

    for (final subCat in category.subCategories) {
      count += _getNotesCountForCategory(subCat);
    }
    return count;
  }

  Widget _buildMissingNotesTile() {
    final count = _getMissingNotesCount();
    if (count == 0) return const SizedBox.shrink();

    final isSelected = _selectedFilter == '__missing__';

    return InkWell(
      onTap: () => _onFilterChanged('__missing__'),
      child: Container(
        padding: const EdgeInsets.only(
          right: 16.0 + 24.0,
          left: 16.0,
          top: 12.0,
          bottom: 12.0,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3)
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
              FluentIcons.warning_24_regular,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'personal_notes.missing_notes_section'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (count > 0)
              Text(
                '($count)',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(Category category, int count, int level) {
    if (count == 0) {
      return const SizedBox.shrink();
    }

    final isExpanded = _expansionState[category.path] ?? level <= 1;
    final isSelected = _selectedFilter == category.path;
    final hasChildren =
        category.subCategories.isNotEmpty || category.books.isNotEmpty;

    return Column(
      children: [
        NavigationTreeTile.category(
          title: category.title,
          level: level,
          isSelected: isSelected,
          isExpanded: isExpanded,
          hasChildren: hasChildren,
          count: count > 0 ? count : null,
          onTap: () => _onFilterChanged(category.path),
          onToggleExpand: () {
            setState(() {
              _expansionState[category.path] = !isExpanded;
            });
          },
        ),
        if (isExpanded && category.path != '/__missing__')
          ..._buildCategoryChildren(category, level),
      ],
    );
  }

  List<Widget> _buildCategoryChildren(Category category, int level) {
    final List<Widget> children = [];

    for (final subCategory in category.subCategories) {
      final count = _getNotesCountForCategory(subCategory);
      if (count > 0) {
        children.add(_buildCategoryTile(subCategory, count, level + 1));
      }
    }

    // Deduplicate books by title - keep only first occurrence
    // This handles cases where the same book exists in both PDF and text formats
    final seenTitles = <String>{};
    for (final book in category.books) {
      // Skip if we already added a book with this title
      if (seenTitles.contains(book.title)) {
        continue;
      }

      final count = _getNotesCountForBook(book.title);
      if (count > 0) {
        children.add(_buildBookTile(book, count, level + 1));
        seenTitles.add(book.title);
      }
    }

    return children;
  }

  Widget _buildBookTile(Book book, int count, int level) {
    if (count == 0) {
      return const SizedBox.shrink();
    }

    final isSelected = _selectedFilter == book.title;

    return NavigationTreeTile.book(
      title: book.title,
      level: level,
      isSelected: isSelected,
      count: count > 0 ? count : null,
      onTap: () => _onFilterChanged(book.title),
    );
  }

  List<String> _getBooksInCategory(Category category) {
    final List<String> bookTitles = [];

    void collectBooks(Category cat) {
      for (final book in cat.books) {
        bookTitles.add(book.title);
      }
      for (final subCat in cat.subCategories) {
        collectBooks(subCat);
      }
    }

    collectBooks(category);
    return bookTitles;
  }

  Widget _buildAllNotesList() {
    final allNotes = <_NoteWithBook>[];

    // Collect all notes from all books
    for (final book in _books) {
      final state = _bookStates[book.bookId];
      if (state != null) {
        for (final note in state.locatedNotes) {
          allNotes.add(_NoteWithBook(note: note, bookId: book.bookId));
        }
        if (_selectedFilter == '__missing__' || _selectedFilter == null) {
          for (final note in state.missingNotes) {
            allNotes.add(_NoteWithBook(
                note: note, bookId: book.bookId, isMissing: true));
          }
        }
      }
    }

    // סינון לפי חיפוש
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      allNotes.removeWhere((noteWithBook) {
        final note = noteWithBook.note;
        return !note.contentPlain.toLowerCase().contains(query) &&
            !note.bookId.toLowerCase().contains(query) &&
            !(note.lineNumber?.toString().contains(query) ?? false);
      });
    }

    // סינון לפי טווח תאריכים (לפי תאריך עדכון ההערה, ברמת היום)
    if (_dateRange != null) {
      allNotes.removeWhere(
        (noteWithBook) => !noteWithinDateRange(noteWithBook.note, _dateRange),
      );
    }

    // Filter by selected filter
    List<_NoteWithBook> filteredNotes;

    if (_selectedFilter == null) {
      // Show all notes
      filteredNotes = allNotes;
    } else if (_selectedFilter == '__missing__') {
      // Show only missing notes
      filteredNotes = allNotes.where((n) => n.isMissing).toList();
    } else if (_selectedFilter!.startsWith('/')) {
      // Category selected - find all books in this category
      final libraryState = context.read<LibraryBloc>().state;
      if (libraryState.library != null) {
        Category? findCategory(Category cat, String path) {
          if (cat.path == path) return cat;
          for (final subCat in cat.subCategories) {
            final found = findCategory(subCat, path);
            if (found != null) return found;
          }
          return null;
        }

        final category = findCategory(libraryState.library!, _selectedFilter!);
        if (category != null) {
          final booksInCategory = _getBooksInCategory(category);
          filteredNotes = allNotes
              .where((n) => booksInCategory.contains(n.bookId))
              .toList();
        } else {
          filteredNotes = [];
        }
      } else {
        filteredNotes = [];
      }
    } else {
      // Book selected
      filteredNotes =
          allNotes.where((n) => n.bookId == _selectedFilter).toList();
    }

    // Filter missing notes if not showing missing filter
    final displayNotes =
        _selectedFilter == '__missing__' ? filteredNotes : filteredNotes;

    // Sort by book and line number
    displayNotes.sort((a, b) {
      final bookCompare = a.bookId.compareTo(b.bookId);
      if (bookCompare != 0) return bookCompare;
      return (a.note.lineNumber ?? 0).compareTo(b.note.lineNumber ?? 0);
    });

    if (displayNotes.isEmpty) {
      return Center(
        child: Text('personal_notes.no_notes_to_show'.tr()),
      );
    }

    // Group notes by book for headers - always show book names
    final groupedNotes = <_NotesGroup>[];
    String? currentBookId;
    List<_NoteWithBook> currentGroup = [];

    for (final note in displayNotes) {
      if (note.bookId != currentBookId) {
        if (currentGroup.isNotEmpty) {
          groupedNotes
              .add(_NotesGroup(bookId: currentBookId!, notes: currentGroup));
        }
        currentBookId = note.bookId;
        currentGroup = [note];
      } else {
        currentGroup.add(note);
      }
    }
    if (currentGroup.isNotEmpty) {
      groupedNotes
          .add(_NotesGroup(bookId: currentBookId!, notes: currentGroup));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: groupedNotes.length,
      itemBuilder: (context, groupIndex) {
        final group = groupedNotes[groupIndex];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.bookId != 'all')
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.text_align_right_24_regular,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        group.bookId,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            FutureBuilder<List<TocEntry>?>(
              future: _tocFor(group.bookId),
              builder: (context, tocSnapshot) {
                final toc = tocSnapshot.data;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    const minCardWidth = 280.0;
                    const maxCardsPerRow = 3;
                    const spacing = 12.0;
                    final availableWidth = constraints.maxWidth;
                    int crossAxisCount =
                        ((availableWidth + spacing) / (minCardWidth + spacing))
                            .floor();
                    crossAxisCount = crossAxisCount.clamp(1, maxCardsPerRow);

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        mainAxisExtent: 170,
                      ),
                      itemCount: group.notes.length,
                      itemBuilder: (context, noteIndex) {
                        final item = group.notes[noteIndex];
                        return _buildNoteCard(
                          item.note,
                          item.isMissing,
                          tableOfContents: toc,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// באנר המציג את טווח התאריכים הפעיל לסינון, עם אפשרות ניקוי.
  Widget _buildDateFilterBanner() {
    final cs = Theme.of(context).colorScheme;
    final range = _dateRange!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTokens.radiusMD),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.calendar_24_regular,
            size: 18,
            color: cs.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'personal_notes.showing_range'.tr(namedArgs: {
                'start': _formatDate(range.start),
                'end': _formatDate(range.end),
              }),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'personal_notes.clear_date_filter'.tr(),
            icon: const Icon(FluentIcons.dismiss_24_regular, size: 18),
            color: cs.onSecondaryContainer,
            onPressed: _clearDateRange,
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(
    PersonalNote note,
    bool isMissing, {
    List<TocEntry>? tableOfContents,
  }) {
    final cs = Theme.of(context).colorScheme;
    final hebrewDate = getHebrewDateFormattedAsString(note.updatedAt);
    // שם הספר כבר מוצג ככותרת הקבוצה, לכן כאן מציגים רק את הדף/העמוד.
    final locationRef = isMissing
        ? null
        : personalNoteLocationRef(
            note,
            isPdf: false,
            bookTitle: note.bookId,
            tableOfContents: tableOfContents,
            includeBookTitle: false,
          );

    return AppCard(
      radius: AppTokens.radiusMD,
      onTap: isMissing ? () => _repositionMissing(note) : null,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  isMissing ? 'personal_notes.no_location'.tr() : note.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (locationRef != null) ...[
            const SizedBox(height: 2),
            Text(
              locationRef,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          // תצוגה מקדימה מעוצבת: מרנדרים את ה-Quill Delta במקום טקסט פשוט,
          // כך שהעיצוב (מודגש/נטוי/קו תחתי/קו חוצה וכו') יופיע גם בכרטיס.
          // maxPreviewChars מקצר הערות ארוכות כדי שלא נרנדר אלפי מילים
          // בכל כרטיס (QuillEditor הלא-נגלל מחשב layout לכל הטקסט).
          // הכרטיס בגובה קבוע (mainAxisExtent: 170), לכן עוטפים ב-Expanded +
          // ClipRect + OverflowBox כדי לחתוך את העודף הוויזואלי. maxHeight
          // מוגבל כהגנה כפולה מעל הקיצור התוכני.
          Expanded(
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: 200,
                child: IgnorePointer(
                  child: PersonalNoteContentView(
                    note: note,
                    allowSelection: false,
                    maxPreviewChars: 280,
                    textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _InfoChip(
                      icon: FluentIcons.calendar_24_regular,
                      text: hebrewDate,
                      backgroundColor: cs.secondaryContainer,
                      foregroundColor: cs.onSecondaryContainer,
                    ),
                    if (isMissing && note.lastKnownLineNumber != null)
                      _InfoChip(
                        icon: FluentIcons.location_24_regular,
                        text: 'personal_notes.last_known_line'.tr(
                            namedArgs: {'line': '${note.lastKnownLineNumber}'}),
                        backgroundColor: cs.surfaceContainerHighest,
                        foregroundColor: cs.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ToolbarActionButton(
                    tooltip: 'personal_notes.edit_button'.tr(),
                    icon: FluentIcons.edit_24_regular,
                    onPressed: () => _editNote(note),
                  ),
                  if (isMissing)
                    ToolbarActionButton(
                      tooltip: 'personal_notes.relocate'.tr(),
                      icon: FluentIcons.location_24_regular,
                      onPressed: () => _repositionMissing(note),
                    ),
                  if (!isMissing)
                    ToolbarActionButton(
                      tooltip: 'personal_notes.open_book_at_line'.tr(),
                      icon: FluentIcons.book_open_24_regular,
                      onPressed: () => _openNoteInBook(note),
                    ),
                  ToolbarActionButton(
                    tooltip: 'personal_notes.delete_tooltip'.tr(),
                    icon: FluentIcons.delete_24_regular,
                    onPressed: () => _deleteNote(note),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editNote(PersonalNote note) async {
    final result = await showDialog<PersonalNoteEditorResult>(
      context: context,
      builder: (context) => PersonalNoteEditorDialog(
        title: 'personal_notes.edit_note_title'.tr(),
        initialContent: note.content,
        initialContentFormat: note.contentFormat,
        referenceText: note.displayTitle,
        icon: FluentIcons.edit_24_regular,
        bookId: note.bookId,
        linkableNotes: [
          ...context.read<PersonalNotesBloc>().state.locatedNotes,
          ...context.read<PersonalNotesBloc>().state.missingNotes,
        ],
      ),
    );
    if (result == null) return;

    final trimmed = result.contentPlain.trim();
    if (trimmed.isEmpty) {
      UiSnack.show('personal_notes.note_empty_not_saved'.tr());
      return;
    }

    if (!mounted) return;
    context.read<PersonalNotesBloc>().add(
          UpdatePersonalNote(
            bookId: note.bookId,
            noteId: note.id,
            content: result.content,
            contentPlain: result.contentPlain,
            contentFormat: result.contentFormat,
          ),
        );
    UiSnack.show('personal_notes.updated'.tr());
  }

  Future<void> _deleteNote(PersonalNote note) async {
    final shouldDelete = await showConfirmationDialog(
      context: context,
      title: 'personal_notes.delete_title'.tr(),
      content: 'personal_notes.delete_confirm'.tr(),
      confirmText: 'personal_notes.delete_button'.tr(),
      isDangerous: true,
    );

    if (shouldDelete == true) {
      if (!mounted) return;
      context.read<PersonalNotesBloc>().add(
            DeletePersonalNote(
              bookId: note.bookId,
              noteId: note.id,
            ),
          );
      UiSnack.show('personal_notes.deleted'.tr());
    }
  }

  Future<void> _repositionMissing(PersonalNote note) async {
    final result = await showInputDialog(
      context: context,
      title: 'personal_notes.relocate_title2'.tr(),
      subtitle: note.lastKnownLineNumber != null
          ? 'personal_notes.last_known_line'
              .tr(namedArgs: {'line': '${note.lastKnownLineNumber}'})
          : null,
      labelText: 'personal_notes.new_line_number'.tr(),
      initialValue: (note.lastKnownLineNumber ?? '').toString(),
      keyboardType: TextInputType.number,
    );

    final newLine = result != null ? int.tryParse(result) : null;

    if (newLine != null) {
      if (!mounted) return;
      context.read<PersonalNotesBloc>().add(
            RepositionPersonalNote(
              bookId: note.bookId,
              noteId: note.id,
              lineNumber: newLine,
            ),
          );
      UiSnack.show('personal_notes.moved_to_line'
          .tr(namedArgs: {'line': '$newLine'}));
    }
  }

  Future<void> _openNoteInBook(PersonalNote note) async {
    if (note.lineNumber == null) {
      UiSnack.show('personal_notes.no_location_title'.tr());
      return;
    }

    final libraryState = context.read<LibraryBloc>().state;
    final library = libraryState.library;
    if (library == null) {
      UiSnack.show('personal_notes.library_not_loaded'.tr());
      return;
    }

    final book = library.findBookByTitle(note.bookId, TextBook) ??
        library.findBookByTitle(note.bookId, null);
    if (book == null) {
      UiSnack.show('personal_notes.book_not_found'
          .tr(namedArgs: {'bookId': note.bookId}));
      return;
    }

    final lineIndex = (note.lineNumber! - 1).clamp(0, 1 << 30);
    final tabsBloc = context.read<TabsBloc>();
    final previousSidebarTab =
        Settings.getValue<int>('key-sidebar-tab-index-combined');
    Settings.setValue<int>('key-sidebar-tab-index-combined', 2);
    Settings.setValue<int>('key-sidebar-tab-index-pending', 2);

    openBook(context, book, lineIndex, '',
        ignoreHistory: true, requiresStableLayout: true);

    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final tabsState = tabsBloc.state;
      if (tabsState.tabs.isEmpty) return;
      final currentTab = tabsState.tabs[tabsState.currentTabIndex];
      if (currentTab is TextBookTab) {
        currentTab.bloc.add(UpdateSelectedIndex(lineIndex));
        currentTab.bloc.add(HighlightLine(lineIndex));
        currentTab.bloc.add(const ToggleSplitView(true));
      }

      if (previousSidebarTab != null) {
        Settings.setValue<int>(
            'key-sidebar-tab-index-combined', previousSidebarTab);
      } else {
        Settings.setValue<int>('key-sidebar-tab-index-combined', 0);
      }
    });
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color foregroundColor;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: foregroundColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// בודקת אם הערה נכללת בטווח התאריכים שנבחר לסינון.
///
/// הסינון מתבצע לפי תאריך העדכון [PersonalNote.updatedAt] ברמת היום בלבד
/// (מתעלם משעה). [range] של null פירושו שאין סינון פעיל — כל ההערות נכללות.
@visibleForTesting
bool noteWithinDateRange(PersonalNote note, DateTimeRange? range) {
  if (range == null) return true;
  final noteDay = DateUtils.dateOnly(note.updatedAt);
  return !noteDay.isBefore(range.start) && !noteDay.isAfter(range.end);
}

class _NoteWithBook {
  final PersonalNote note;
  final String bookId;
  final bool isMissing;

  _NoteWithBook({
    required this.note,
    required this.bookId,
    this.isMissing = false,
  });
}

class _NotesGroup {
  final String bookId;
  final List<_NoteWithBook> notes;

  _NotesGroup({
    required this.bookId,
    required this.notes,
  });
}
