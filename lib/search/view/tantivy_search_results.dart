import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/bloc/search_bloc.dart';
import 'package:otzaria/search/bloc/search_event.dart';
import 'package:otzaria/search/bloc/search_state.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/search/utils/snippet_builder.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' as utils;
import 'package:otzaria/widgets/controls/action_buttons.dart';

class TantivySearchResults extends StatefulWidget {
  final SearchingTab tab;
  final VoidCallback? onEditSearch;
  const TantivySearchResults({
    super.key,
    required this.tab,
    this.onEditSearch,
  });

  @override
  State<TantivySearchResults> createState() => _TantivySearchResultsState();
}

class _TantivySearchResultsState extends State<TantivySearchResults> {
  static const int _maxUnbrokenWordLength = 12;
  static const double _loadMoreThreshold = 200;
  final ScrollController _scrollController = ScrollController();
  final Map<String, List<InlineSpan>> _snippetCache = {};
  bool _isAutoLoadInFlight = false;

  /// חתימת החיפוש האחרון (שאילתה + קטגוריות) שעבורו כבר גללנו לראש הרשימה.
  /// משמשת להבחנה בין חיפוש חדש (חתימה משתנה → גלילה לראש) לבין טעינת המשך
  /// (אותה חתימה → שימור מיקום הגלילה).
  String? _lastSearchSignature;

  Widget _buildInformativeEmptyState({
    required IconData icon,
    required String title,
    required String message,
    bool showEditButton = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 52,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (showEditButton && widget.onEditSearch != null) ...[
              const SizedBox(height: 16),
              NeutralActionButton(
                text: 'ערוך חיפוש',
                onPressed: widget.onEditSearch!,
                icon: FluentIcons.edit_24_regular,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    // אתחול החתימה מה-state הנוכחי כדי שהשינוי הראשון (למשל טעינת המשך בטאב
    // חיפוש משוחזר) לא ייחשב בטעות ל"חיפוש חדש" ויאפס את הגלילה.
    _lastSearchSignature = _searchSignature(context.read<SearchBloc>().state);
  }

  /// חתימת חיפוש: שאילתה + קטגוריות. זהה בין chunks של אותו חיפוש ובטעינת
  /// המשך, ומשתנה רק בחיפוש חדש (שינוי שאילתה או קטגוריה).
  String _searchSignature(SearchState state) =>
      '${state.searchQuery} ${state.currentFacets.join('')}';

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    if (_scrollController.position.extentAfter > _loadMoreThreshold) {
      return;
    }

    _maybeLoadMore();
  }

  void _maybeLoadMore() {
    if (!mounted || _isAutoLoadInFlight) {
      return;
    }

    final state = context.read<SearchBloc>().state;
    final hasMoreResults = state.results.length < state.totalResults;

    if (state.isLoading || !hasMoreResults) {
      return;
    }

    _isAutoLoadInFlight = true;
    context.read<SearchBloc>().add(
          LoadMoreResults(
            customSpacing: widget.tab.spacingValues,
            alternativeWords: widget.tab.alternativeWords,
            searchOptions: widget.tab.effectiveSearchOptions(
              query: context.read<SearchBloc>().state.searchQuery,
            ),
          ),
        );
  }

  String _searchResultDedupeKey({
    required String title,
    required String reference,
    required int segment,
    required bool isPdf,
  }) {
    return 'search:${isPdf ? 'pdf' : 'text'}|$title|$reference|$segment';
  }

  String _formatTitleForWrapping(String title) {
    return title.split(' ').map(_insertBreakOpportunities).join(' ');
  }

  String _insertBreakOpportunities(String word) {
    if (word.characters.length <= _maxUnbrokenWordLength) {
      return word;
    }

    final buffer = StringBuffer();
    var currentLength = 0;

    for (final character in word.characters) {
      buffer.write(character);
      currentLength++;

      if (currentLength >= _maxUnbrokenWordLength) {
        buffer.write('\u200B');
        currentLength = 0;
      }
    }

    return buffer.toString();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constrains) {
      return BlocListener<SearchBloc, SearchState>(
        listenWhen: (previous, current) =>
            previous.isLoading != current.isLoading ||
            previous.results.length != current.results.length ||
            previous.totalResults != current.totalResults ||
            previous.searchQuery != current.searchQuery ||
            previous.currentFacets.join('|') != current.currentFacets.join('|'),
        listener: (context, state) {
          if (!state.isLoading) {
            _isAutoLoadInFlight = false;
          }

          // חיפוש חדש (שינוי שאילתה או קטגוריה) — מאפס את הגלילה לראש הרשימה.
          // טעינת המשך (LoadMore) שומרת על אותה חתימה ולכן לא נוגעת בגלילה,
          // וכך גם chunks עוקבים של אותו חיפוש (החתימה זהה).
          final signature = _searchSignature(state);
          if (signature != _lastSearchSignature) {
            _lastSearchSignature = signature;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _scrollController.hasClients) {
                _scrollController.jumpTo(0);
              }
            });
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _handleScroll();
            }
          });
        },
        child: BlocBuilder<SearchBloc, SearchState>(
          builder: (context, state) {
            // עכשיו רק מציגים את התוצאות - השורה התחתונה מוצגת במקום אחר
            return _buildResultsContent(state, constrains);
          },
        ),
      );
    });
  }

  Widget _buildResultsContent(SearchState state, BoxConstraints constrains) {
    // חשוב: בעת טעינה אנחנו לא רוצים לפרק את ה-ListView,
    // אחרת הגלילה מתאפסת לראש. לכן ספינר מרכזי מוצג רק כשאין עדיין תוצאות.
    if (state.isLoading && state.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.searchQuery.isEmpty) {
      return _buildInformativeEmptyState(
        icon: FluentIcons.search_24_regular,
        title: 'search.no_search_done'.tr(),
        message: 'search.no_search_done_hint'.tr(),
      );
    }
    if (state.results.isEmpty && !state.isLoading) {
      // הבחנה בין חיפוש ריק לגיטימי לבין כשל בחיפוש: אם errorMessage קיים,
      // תקלת מנוע (או FFI) הסתיימה בלי תוצאות — מציגים את ההודעה בצבע שגיאה
      // במקום "אין תוצאות" המטעה.
      if (state.errorMessage != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
      }
      return _buildInformativeEmptyState(
        icon: FluentIcons.document_search_24_regular,
        title: 'search.no_results'.tr(),
        message: 'search.no_results_hint'.tr(),
        showEditButton: true,
      );
    }

    // תמיד נשתמש ב-ListView גם לתוצאה אחת - כך היא תופיע למעלה
    final hasMoreResults = state.results.length < state.totalResults;
    final showInlineLoadingIndicator =
        state.isLoading && state.results.isNotEmpty && !hasMoreResults;
    final showLoadMoreButton = hasMoreResults;

    // אפשרויות אפקטיביות זהות לכל איטם ב-build הנוכחי -
    // מחשבים פעם אחת מחוץ ל-itemBuilder כדי לחסוך עבודה
    final effectiveOptions = widget.tab.effectiveSearchOptions(
      query: state.searchQuery,
    );

    return ListView.builder(
      key: PageStorageKey(widget.tab),
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: state.results.length +
          ((showInlineLoadingIndicator || showLoadMoreButton) ? 1 : 0),
      itemBuilder: (context, index) {
        // האיטם האחרון מציג אינדיקטור טעינה בזמן הזרמה,
        // או כפתור pagination כשיש עוד תוצאות בשרת.
        if (index == state.results.length) {
          if (showInlineLoadingIndicator) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text('search.loading_results'.tr()),
                  ],
                ),
              ),
            );
          }

          final remainingText = 'search.load_more_results'.tr(namedArgs: {
            'count': (state.totalResults - state.results.length).toString(),
          });
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: NeutralActionButton(
                  text: state.isLoading ? 'search.loading'.tr() : remainingText,
                  onPressed: () {
                    context.read<SearchBloc>().add(
                          LoadMoreResults(
                            customSpacing: widget.tab.spacingValues,
                            alternativeWords: widget.tab.alternativeWords,
                            searchOptions: effectiveOptions,
                          ),
                        );
                  },
                  isLoading: state.isLoading,
                  icon: state.isLoading
                      ? null
                      : FluentIcons.arrow_download_24_regular,
                ),
              ),
            ),
          );
        }
        final result = state.results[index];
        return BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            final colorScheme = Theme.of(context).colorScheme;
            String titleText = result.reference;
            String rawHtml = result.text;
            // Debug info removed for production
            if (settingsState.replaceHolyNames) {
              titleText = utils.replaceHolyNames(titleText);
              rawHtml = utils.replaceHolyNames(rawHtml);
            }

            final wrappedTitleText = _formatTitleForWrapping(titleText);

            // ההדגשה מגיעה מוכנה מהמנוע בתוך rawHtml, ולכן המפתח תלוי רק
            // ב-HTML ובסגנון התצוגה — לא בפרמטרי החיפוש.
            final snippetCacheKey = [
              result.id,
              result.segment,
              rawHtml.hashCode,
              settingsState.fontSize,
              settingsState.fontFamily,
              settingsState.replaceHolyNames,
              colorScheme.onSurface.toARGB32(),
            ].join('|');

            // Create the snippet using the new robust function
            // שימוש בגופן וגודל של המשתמש מההגדרות
            final snippetSpans = _snippetCache.putIfAbsent(
              snippetCacheKey,
              () {
                if (_snippetCache.length > 300) {
                  _snippetCache.clear();
                }
                return SnippetBuilder.fromHighlightedHtml(
                  html: rawHtml,
                  defaultStyle: TextStyle(
                    fontSize: settingsState.fontSize,
                    fontFamily: settingsState.fontFamily,
                    color: colorScheme.onSurface,
                    height: 1.5,
                  ),
                  highlightStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: settingsState.fontSize + 2,
                    fontFamily: settingsState.fontFamily,
                    color: colorScheme.error,
                  ),
                );
              },
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  final rawQuery = widget.tab.queryController.text;
                  final hasEnabledOptions = effectiveOptions.values
                      .any((m) => m.values.any((v) => v == true));
                  final hasAlternativeWords = widget.tab.alternativeWords.values
                      .any((alts) => alts.any((w) => w.trim().isNotEmpty));
                  final hasSpacingValues = widget.tab.spacingValues.values
                      .any((v) => v.trim().isNotEmpty);
                  final looksLikeRegex =
                      RegExp(r'[\\.\*\+\?\|\(\)\[\]\{\}\^\$]')
                          .hasMatch(rawQuery);
                  final currentMode =
                      widget.tab.searchBloc.state.configuration.searchMode;

                  final shouldUseSimpleInBook = !hasEnabledOptions &&
                      !hasAlternativeWords &&
                      !hasSpacingValues &&
                      !looksLikeRegex &&
                      currentMode != SearchMode.fuzzy;

                  final inBookMode =
                      shouldUseSimpleInBook ? SearchMode.exact : currentMode;

                  if (result.isPdf) {
                    final pageNumber = result.segment.toInt() + 1;
                    context.read<TabsBloc>().add(
                          OpenOrFocusTab(
                            PdfBookTab(
                              book: PdfBook(
                                  title: result.title, path: result.filePath),
                              pageNumber: pageNumber,
                              dedupeKey: _searchResultDedupeKey(
                                title: result.title,
                                reference: result.reference,
                                segment: result.segment.toInt(),
                                isPdf: true,
                              ),
                              searchText: rawQuery,
                              searchOptions: effectiveOptions,
                              alternativeWords: widget.tab.alternativeWords,
                              spacingValues: widget.tab.spacingValues,
                              searchMode: inBookMode,
                              openLeftPane:
                                  (Settings.getValue<bool>('key-pin-sidebar') ??
                                          false) ||
                                      (Settings.getValue<bool>(
                                              'key-default-sidebar-open') ??
                                          false),
                              requiresStableLayout: true,
                            ),
                            targetTitle: result.reference,
                            insertAdjacent: true,
                          ),
                        );
                  } else {
                    context.read<TabsBloc>().add(
                          OpenOrFocusTab(
                            TextBookTab(
                              book: TextBook(
                                title: result.title,
                              ),
                              index: result.segment.toInt(),
                              dedupeKey: _searchResultDedupeKey(
                                title: result.title,
                                reference: result.reference,
                                segment: result.segment.toInt(),
                                isPdf: false,
                              ),
                              searchText: rawQuery,
                              searchOptions: effectiveOptions,
                              alternativeWords: widget.tab.alternativeWords,
                              spacingValues: widget.tab.spacingValues,
                              searchMode: inBookMode,
                              openLeftPane:
                                  (Settings.getValue<bool>('key-pin-sidebar') ??
                                          false) ||
                                      (Settings.getValue<bool>(
                                              'key-default-sidebar-open') ??
                                          false),
                            ),
                            targetTitle: result.reference,
                            insertAdjacent: true,
                          ),
                        );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // מספר התוצאה
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // תוכן התוצאה
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // נתיב (כותרת + הפניה)
                            Row(
                              children: [
                                if (result.isPdf)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Icon(
                                      FluentIcons.document_pdf_24_regular,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    wrappedTitleText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.right,
                                    softWrap: true,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    FluentIcons.copy_24_regular,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                  tooltip: 'search.copy_text'.tr(),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  onPressed: () {
                                    final plainText =
                                        utils.stripHtmlIfNeeded(rawHtml);
                                    Clipboard.setData(
                                        ClipboardData(text: plainText));
                                    UiSnack.show(UiSnack.textCopied);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // הטקסט שנמצא
                            RichText(
                              textAlign: TextAlign.justify,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  height: 1.5,
                                ),
                                children: snippetSpans,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
