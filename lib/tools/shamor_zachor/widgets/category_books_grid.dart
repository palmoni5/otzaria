import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/widgets/dialogs/dialogs_exports.dart';
import '../providers/shamor_zachor_data_provider.dart';
import '../providers/shamor_zachor_progress_provider.dart';
import '../models/book_model.dart';
import 'book_card_widget.dart'; // Using the rich card
import 'package:otzaria/widgets/feedback/tool_empty_state.dart';

class CategoryBooksGrid extends StatefulWidget {
  final String? categoryName;
  final String? topLevelName;
  final BookCategory? category;
  final List<BookSearchResult>? searchResults;
  final Function(String, String, BookDetails) onBookSelected;
  final String selectedFilter;

  const CategoryBooksGrid({
    super.key,
    this.categoryName,
    this.topLevelName,
    this.category,
    this.searchResults,
    required this.onBookSelected,
    this.selectedFilter = 'all',
  });

  @override
  State<CategoryBooksGrid> createState() => _CategoryBooksGridState();
}

class _CategoryBooksGridState extends State<CategoryBooksGrid> {
  static final Logger _logger = Logger('CategoryBooksGrid');
  final Set<String> _locallyRemovedBookKeys = <String>{};

  String _bookLocalKey(String category, String bookName, BookDetails details) {
    if (details.id != null) {
      return 'id:${details.id}';
    }

    return '$category::$bookName';
  }

  bool _isBookLocallyRemoved(
      String category, String bookName, BookDetails details) {
    return _locallyRemovedBookKeys
        .contains(_bookLocalKey(category, bookName, details));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.category == null &&
        widget.searchResults == null &&
        widget.categoryName != 'custom_books_virtual') {
      return ToolEmptyState(
        icon: FluentIcons.library_24_regular,
        message: 'shamor_zachor.select_category_to_view'.tr(),
      );
    }

    return Column(
      children: [
        // Grid Content
        Expanded(
          child:
              Consumer2<ShamorZachorDataProvider, ShamorZachorProgressProvider>(
            builder: (context, dataProvider, progressProvider, child) {
              // Debug log
              _logger.fine(
                  'CategoryBooksGrid builder called for category: ${widget.categoryName}');

              if (widget.searchResults != null) {
                final searchBooks = widget.searchResults!
                    .map(
                      (result) => {
                        'name': result.bookName,
                        'details': result.bookDetails,
                        'category': result.topLevelCategoryName,
                        'categoryPath': result.bookDetails.categoryPath ??
                            result.categoryName,
                      },
                    )
                    .toList(growable: false);
                final filteredBooks =
                    _filterBooks(searchBooks, progressProvider);

                if (filteredBooks.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildBooksGrid(filteredBooks, progressProvider,
                    shrinkWrap: false);
              }

              if (widget.category != null) {
                final effectiveTopLevelName =
                    widget.topLevelName ?? widget.category!.name;

                // Check if this is the virtual "All Books" category
                final isAllBooksVirtual =
                    widget.topLevelName == 'all_books_virtual';

                // Check if we should group by subcategories
                if (widget.category!.subcategories != null &&
                    widget.category!.subcategories!.isNotEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. Direct books in this category (only if NOT "All Books")
                      if (!isAllBooksVirtual)
                        Builder(builder: (context) {
                          final directBooks = _getAllBooksRecursive(
                              BookCategory(
                                  name: widget.category!.name,
                                  books: widget.category!.books,
                                  subcategories: null, // Only direct books
                                  isCustom: widget.category!.isCustom,
                                  sourceFile: widget.category!.sourceFile,
                                  schemaVersion: widget.category!.schemaVersion,
                                  contentType: widget.category!.contentType,
                                  defaultStartPage:
                                      widget.category!.defaultStartPage),
                              effectiveTopLevelName);
                          final filtered =
                              _filterBooks(directBooks, progressProvider);
                          if (filtered.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                  'shamor_zachor.books_in_category'.tr(
                                      namedArgs: {
                                    'category': widget.category!.name
                                  })),
                              _buildBooksGrid(filtered, progressProvider,
                                  shrinkWrap: true),
                              const SizedBox(height: 24),
                            ],
                          );
                        }),

                      // 2. Subcategories - using natural order from DataProvider
                      ...widget.category!.subcategories!.map((sub) {
                        // For "All Books", use the subcategory's own name as topLevelName
                        final subTopLevelName = isAllBooksVirtual
                            ? sub.name
                            : effectiveTopLevelName;
                        final subBooks =
                            _getAllBooksRecursive(sub, subTopLevelName);
                        final filtered =
                            _filterBooks(subBooks, progressProvider);

                        if (filtered.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(sub.name),
                            _buildBooksGrid(filtered, progressProvider,
                                shrinkWrap: true),
                            const SizedBox(height: 32),
                          ],
                        );
                      }),
                    ],
                  );
                } else {
                  // Leaf category - Flat Grid
                  final allBooks = _getAllBooksRecursive(
                      widget.category!, effectiveTopLevelName);
                  final filteredBooks =
                      _filterBooks(allBooks, progressProvider);

                  if (filteredBooks.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildBooksGrid(filteredBooks, progressProvider,
                      shrinkWrap: false);
                }
              }

              return _buildEmptyState();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ToolEmptyState(
      icon: FluentIcons.book_24_regular,
      message: 'shamor_zachor.no_books_to_show'.tr(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(FluentIcons.folder_24_regular,
              color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Expanded(child: Divider(indent: 16)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterBooks(List<Map<String, dynamic>> books,
      ShamorZachorProgressProvider progressProvider) {
    return books.where((book) {
      final name = book['name'] as String;
      final details = book['details'] as BookDetails;
      final category = book['category'] as String;

      if (_isBookLocallyRemoved(category, name, details)) {
        return false;
      }

      final bookId = details.id;
      final bool isCompleted;
      final bool isInProgress;

      if (bookId != null) {
        isCompleted = progressProvider.isBookCompletedById(bookId, details);
        isInProgress =
            progressProvider.isBookConsideredInProgressById(bookId, details);
      } else {
        isCompleted = false;
        isInProgress = false;
      }

      if (widget.selectedFilter == 'in_progress') {
        return isInProgress && !isCompleted;
      }
      if (widget.selectedFilter == 'completed') {
        return isCompleted;
      }
      return true;
    }).toList();
  }

  Widget _buildBooksGrid(List<Map<String, dynamic>> books,
      ShamorZachorProgressProvider progressProvider,
      {bool shrinkWrap = false}) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: GridView.builder(
        padding: shrinkWrap ? EdgeInsets.zero : const EdgeInsets.all(16),
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        shrinkWrap: shrinkWrap,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 350,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 192,
        ),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          final name = book['name'] as String;
          final details = book['details'] as BookDetails;
          final category = book['category'] as String;
          final categoryPath = book['categoryPath'] as String?;

          return BookCardWidget(
            key: ValueKey('${details.id ?? 'no-id'}::$category::$name'),
            topLevelCategoryKey: category,
            categoryName: categoryPath ?? widget.categoryName ?? '',
            bookName: name,
            bookDetails: details,
            onTap: () {
              widget.onBookSelected(category, name, details);
            },
            onDelete: details.isCustom
                ? () => _confirmRemoveBook(context, name, details)
                : null,
          );
        },
      ),
    );
  }

  Future<void> _confirmRemoveBook(
      BuildContext context, String bookName, BookDetails details) async {
    final progressProvider = context.read<ShamorZachorProgressProvider>();
    final dataProvider = context.read<ShamorZachorDataProvider>();
    final confirmed = await showWarningDialog(
      context: context,
      title: 'shamor_zachor.remove_book_title'.tr(),
      content:
          'shamor_zachor.remove_book_content'.tr(namedArgs: {'name': bookName}),
      subtitle: 'shamor_zachor.remove_book_subtitle'.tr(),
      cancelText: 'shamor_zachor.cancel'.tr(),
      confirmText: 'shamor_zachor.remove'.tr(),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final topLevelCategory =
          details.categoryPath ?? widget.categoryName ?? '';
      final localBookKey = _bookLocalKey(topLevelCategory, bookName, details);

      setState(() {
        _locallyRemovedBookKeys.add(localBookKey);
      });

      if (details.id != null) {
        await progressProvider.clearBookProgressById(
          details.id!,
          bookDetails: details,
        );
      }

      await dataProvider.removeCustomBook(
        categoryName: topLevelCategory,
        bookName: bookName,
        bookId: details.id,
      );
      if (context.mounted) {
        UiSnack.show(
            'shamor_zachor.book_removed'.tr(namedArgs: {'name': bookName}));
      }
    } catch (e) {
      final topLevelCategory =
          details.categoryPath ?? widget.categoryName ?? '';
      final localBookKey = _bookLocalKey(topLevelCategory, bookName, details);
      if (mounted) {
        setState(() {
          _locallyRemovedBookKeys.remove(localBookKey);
        });
      }
      if (context.mounted) {
        UiSnack.showError(
            'shamor_zachor.remove_book_error'.tr(namedArgs: {'error': '$e'}));
      }
    }
  }

  List<Map<String, dynamic>> _getAllBooksRecursive(
      BookCategory category, String topLevelName,
      {String? parentPath}) {
    List<Map<String, dynamic>> books = [];

    // Build the current category path
    final currentPath =
        parentPath != null ? '$parentPath/${category.name}' : category.name;

    category.books.forEach((name, details) {
      // Use the actual category from BookDetails if available, otherwise use topLevelName
      final actualCategory =
          details.categoryPath?.split('/').first ?? topLevelName;

      books.add({
        'name': name,
        'details': details,
        'category': actualCategory, // שימוש בקטגוריה האמיתית
        'categoryPath':
            details.categoryPath ?? currentPath, // נתיב מלא של הקטגוריות
      });
    });

    category.subcategories?.forEach((sub) {
      books.addAll(
          _getAllBooksRecursive(sub, topLevelName, parentPath: currentPath));
    });

    return books;
  }
}
