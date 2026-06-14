import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;

import '../models/progress_model.dart';
import '../models/book_model.dart';
import '../models/error_model.dart';
import '../services/progress_service.dart';
import 'package:otzaria/core/ui_snack.dart';

/// Events emitted when significant progress milestones are reached
enum CompletionEventType {
  bookCompleted,
  reviewCycleCompleted,
}

class CompletionEvent {
  final CompletionEventType type;
  final int? bookId;
  final int? reviewCycleNumber;

  const CompletionEvent(
    this.type, {
    this.bookId,
    this.reviewCycleNumber,
  });

  @override
  String toString() {
    return 'CompletionEvent(type: $type, bookId: $bookId, review: $reviewCycleNumber)';
  }
}

/// Provider for managing user progress in Shamor Zachor.
/// All progress is keyed by book ID.
class ShamorZachorProgressProvider with ChangeNotifier {
  static final Logger _logger = Logger('ShamorZachorProgressProvider');

  final ProgressService _progressService;

  ProgressMapById _progressById = {};
  CompletionDatesByIdMap _completionDatesById = {};

  final Map<int, BookProgressSummary> _progressSummaryCache = {};
  bool _isLoading = false;
  ShamorZachorError? _error;

  // Column names for progress tracking
  static const String learnColumn = 'learn';
  static const String review1Column = 'review1';
  static const String review2Column = 'review2';
  static const String review3Column = 'review3';
  static const List<String> allColumnNames = [
    learnColumn,
    review1Column,
    review2Column,
    review3Column,
  ];

  // Stream for completion events
  final _completionEventController =
      StreamController<CompletionEvent>.broadcast();
  Stream<CompletionEvent> get completionEvents =>
      _completionEventController.stream;

  /// Check if data is currently loading
  bool get isLoading => _isLoading;

  /// Get current error, if any
  ShamorZachorError? get error => _error;

  /// Check if progress data has been loaded
  bool get hasData => _progressById.isNotEmpty;

  void _invalidateSummaryCache(int bookId) {
    _progressSummaryCache.remove(bookId);
  }

  void _clearSummaryCache() {
    _progressSummaryCache.clear();
  }

  ShamorZachorProgressProvider({
    ProgressService? progressService,
  }) : _progressService = progressService ?? ProgressService();

  /// Ensures data is loaded - call this when the widget is first displayed.
  /// Idempotent: only loads once.
  Future<void> ensureLoaded() async {
    if (_isLoading || hasData || _error != null) {
      return;
    }
    await _loadInitialProgress();
  }

  /// Retry loading after a previous failure.
  Future<void> retry() async {
    if (_isLoading) {
      return;
    }

    _error = null;
    await _loadInitialProgress();
  }

  /// Load initial progress data
  Future<void> _loadInitialProgress() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _progressById = await _progressService.loadProgressDataById();
      _completionDatesById = await _progressService.loadCompletionDatesById();

      _logger
          .info('Successfully loaded progress: ${_progressById.length} books');
    } catch (e, stackTrace) {
      if (e is ShamorZachorError) {
        _error = e;
      } else {
        _error = ShamorZachorError.fromException(
          e,
          stackTrace: stackTrace,
          customMessage: 'Failed to load progress data',
        );
      }
      _logger.severe(
          'Error loading progress: ${_error!.message}', e, stackTrace);
    }

    _clearSummaryCache();
    _isLoading = false;
    notifyListeners();
  }

  /// Get progress data for a specific book by ID
  Map<String, PageProgress> getProgressForBookById(int bookId) {
    return _progressById[bookId] ?? {};
  }

  /// Get progress for a specific item by book ID
  PageProgress getProgressForItemById(int bookId, int absoluteIndex) {
    return _progressById[bookId]?[absoluteIndex.toString()] ?? PageProgress();
  }

  /// Get completion date for a book by ID (synchronous)
  String? getCompletionDateSyncById(int bookId) {
    return _completionDatesById[bookId];
  }

  /// Update progress for a single item by book ID
  Future<void> updateProgressById(
    int bookId,
    int absoluteIndex,
    String columnName,
    bool value,
    BookDetails bookDetails, {
    bool isBulkUpdate = false,
  }) async {
    try {
      final itemIndexKey = absoluteIndex.toString();

      if (value && !isBulkUpdate) {
        final currentProgress = getProgressForItemById(bookId, absoluteIndex);

        if (columnName == 'review1' && !currentProgress.learn) {
          UiSnack.show('shamor_zachor.mark_learn_first'.tr());
          return;
        } else if (columnName == 'review2' &&
            (!currentProgress.learn || !currentProgress.review1)) {
          if (!currentProgress.learn) {
            UiSnack.show('shamor_zachor.mark_learn_first'.tr());
          } else {
            UiSnack.show('shamor_zachor.mark_review1_first'.tr());
          }
          return;
        } else if (columnName == 'review3' &&
            (!currentProgress.learn ||
                !currentProgress.review1 ||
                !currentProgress.review2)) {
          if (!currentProgress.learn) {
            UiSnack.show('shamor_zachor.mark_learn_first'.tr());
          } else if (!currentProgress.review1) {
            UiSnack.show('shamor_zachor.mark_review1_first'.tr());
          } else {
            UiSnack.show('shamor_zachor.mark_review2_first'.tr());
          }
          return;
        }
      }

      // Make sure data is loaded before mutating - prevents accidental wipes
      if (_progressById.isEmpty && !_isLoading) {
        _progressById = await _progressService.loadProgressDataById();
      }

      _progressById.putIfAbsent(bookId, () => {});
      _progressById[bookId]!.putIfAbsent(itemIndexKey, () => PageProgress());

      final pageProgress = _progressById[bookId]![itemIndexKey]!;
      pageProgress.setProperty(columnName, value);

      if (pageProgress.isEmpty) {
        _progressById[bookId]!.remove(itemIndexKey);
        if (_progressById[bookId]!.isEmpty) {
          _progressById.remove(bookId);
        }
      }

      await _progressService.saveProgressDataById(_progressById);

      _invalidateSummaryCache(bookId);

      if (value && !isBulkUpdate) {
        await _handleCompletionEventsById(bookId, columnName, bookDetails);
      }

      if (!isBulkUpdate) {
        notifyListeners();
      }
    } catch (e, stackTrace) {
      _logger.severe('Error in updateProgressById: $e', e, stackTrace);
      _error = ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        customMessage: 'Failed to update progress by ID',
      );
      notifyListeners();
    }
  }

  /// Handle completion events when progress is updated (by ID)
  Future<void> _handleCompletionEventsById(
    int bookId,
    String columnName,
    BookDetails bookDetails,
  ) async {
    _invalidateSummaryCache(bookId);

    if (columnName == learnColumn) {
      final wasAlreadyCompleted = getCompletionDateSyncById(bookId) != null;
      final isNowComplete = isBookCompletedById(bookId, bookDetails);

      if (isNowComplete && !wasAlreadyCompleted) {
        await _progressService.saveCompletionDateById(
            bookId, DateTime.now().toIso8601String());
        _completionDatesById = await _progressService.loadCompletionDatesById();
        _invalidateSummaryCache(bookId);

        _completionEventController.add(CompletionEvent(
          CompletionEventType.bookCompleted,
          bookId: bookId,
        ));
      }
    } else if (columnName.startsWith('review')) {
      int? reviewCycleNumber;
      switch (columnName) {
        case review1Column:
          reviewCycleNumber = 1;
          break;
        case review2Column:
          reviewCycleNumber = 2;
          break;
        case review3Column:
          reviewCycleNumber = 3;
          break;
      }

      if (reviewCycleNumber != null) {
        final cycleJustCompleted = _isReviewCycleCompletedById(
          bookId,
          reviewCycleNumber,
          bookDetails,
        );

        if (cycleJustCompleted) {
          _invalidateSummaryCache(bookId);
          _completionEventController.add(CompletionEvent(
            CompletionEventType.reviewCycleCompleted,
            bookId: bookId,
            reviewCycleNumber: reviewCycleNumber,
          ));
        }
      }
    }
  }

  /// Toggle select all for a column by book ID
  Future<void> toggleSelectAllForColumnById(
    int bookId,
    BookDetails bookDetails,
    String columnName,
    bool selectAll,
  ) async {
    if (!allColumnNames.contains(columnName)) {
      _logger.warning('Invalid column name: $columnName');
      return;
    }

    try {
      _progressById[bookId] ??= {};
      final bookProgress = _progressById[bookId]!;

      for (final item in bookDetails.learnableItems) {
        final key = item.absoluteIndex.toString();
        bookProgress[key] ??= PageProgress();
        bookProgress[key]!.setProperty(columnName, selectAll);
      }

      await _progressService.saveProgressDataById(_progressById);
      _invalidateSummaryCache(bookId);

      if (selectAll && columnName == learnColumn) {
        final wasAlreadyCompleted = getCompletionDateSyncById(bookId) != null;
        final isNowComplete = isBookCompletedById(bookId, bookDetails);

        if (isNowComplete && !wasAlreadyCompleted) {
          await _progressService.saveCompletionDateById(
              bookId, DateTime.now().toIso8601String());
          _completionDatesById =
              await _progressService.loadCompletionDatesById();
        }
      }

      notifyListeners();
    } catch (e, stackTrace) {
      _logger.severe(
          'Error toggling select all for column by ID', e, stackTrace);
      _error = ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        customMessage: 'Failed to bulk update column',
      );
      notifyListeners();
    }
  }

  /// Toggle section column by book ID
  Future<void> toggleSectionColumnById(
    int bookId,
    BookDetails bookDetails,
    String sectionId,
    String columnName,
    bool selectAll,
  ) async {
    try {
      final leafIndices = bookDetails.sectionLeafIndexMap[sectionId];
      if (leafIndices == null || leafIndices.isEmpty) return;

      _progressById[bookId] ??= {};
      final bookProgress = _progressById[bookId]!;

      for (final index in leafIndices) {
        final key = index.toString();
        bookProgress[key] ??= PageProgress();
        bookProgress[key]!.setProperty(columnName, selectAll);
      }

      await _progressService.saveProgressDataById(_progressById);
      _invalidateSummaryCache(bookId);

      if (selectAll && columnName == learnColumn) {
        final wasAlreadyCompleted = getCompletionDateSyncById(bookId) != null;
        final isNowComplete = isBookCompletedById(bookId, bookDetails);

        if (isNowComplete && !wasAlreadyCompleted) {
          await _progressService.saveCompletionDateById(
              bookId, DateTime.now().toIso8601String());
          _completionDatesById =
              await _progressService.loadCompletionDatesById();
        }
      }

      notifyListeners();
    } catch (e, stackTrace) {
      _logger.severe('Error toggling section column by ID', e, stackTrace);
      _error = ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        customMessage: 'Failed to update section progress',
      );
      notifyListeners();
    }
  }

  /// Clear all progress for a specific book by ID
  Future<void> clearBookProgressById(
    int bookId, {
    BookDetails? bookDetails,
  }) async {
    try {
      _progressById.remove(bookId);
      _completionDatesById.remove(bookId);

      await _progressService.saveProgressDataById(_progressById);
      await _progressService.saveCompletionDatesById(_completionDatesById);

      _invalidateSummaryCache(bookId);

      notifyListeners();
    } catch (e, stackTrace) {
      _error = ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        customMessage: 'Failed to clear book progress by ID',
      );
      _logger.severe(
          'Error clearing progress by ID: ${_error!.message}', e, stackTrace);
      notifyListeners();
    }
  }

  /// Get column selection states by book ID (all/none/partial)
  Map<String, bool?> getColumnSelectionStatesById(
    int bookId,
    BookDetails? bookDetails,
  ) {
    final columnStates = <String, bool?>{
      learnColumn: null,
      review1Column: null,
      review2Column: null,
      review3Column: null,
    };

    if (bookDetails == null) return columnStates;

    final bookProgress = _progressById[bookId];
    final totalItems = bookDetails.totalLearnableItems;

    if (totalItems == 0) {
      columnStates.updateAll((key, value) => false);
      return columnStates;
    }

    for (final currentColumnName in allColumnNames) {
      int itemsChecked = 0;
      if (bookProgress != null) {
        for (final item in bookDetails.learnableItems) {
          final itemProgress = bookProgress[item.absoluteIndex.toString()];
          if (itemProgress?.getProperty(currentColumnName) ?? false) {
            itemsChecked++;
          }
        }
      }

      if (itemsChecked == 0) {
        columnStates[currentColumnName] = false;
      } else if (itemsChecked == totalItems) {
        columnStates[currentColumnName] = true;
      } else {
        columnStates[currentColumnName] = null;
      }
    }

    return columnStates;
  }

  /// Get section column state by book ID (all/none/partial)
  bool? getSectionColumnStateById(
    int bookId,
    BookDetails bookDetails,
    String sectionId,
    String columnName,
  ) {
    final leafIndices = bookDetails.sectionLeafIndexMap[sectionId];
    if (leafIndices == null || leafIndices.isEmpty) return false;

    final bookProgress = _progressById[bookId];
    if (bookProgress == null) return false;

    int checkedCount = 0;
    for (final index in leafIndices) {
      final progress = bookProgress[index.toString()];
      if (progress?.getProperty(columnName) ?? false) {
        checkedCount++;
      }
    }

    if (checkedCount == 0) return false;
    if (checkedCount == leafIndices.length) return true;
    return null;
  }

  /// Get learn progress percentage by book ID
  double getLearnProgressPercentageById(int bookId, BookDetails bookDetails) {
    final bookProgress = _progressById[bookId];
    final totalTargetItems = bookDetails.totalLearnableItems;
    if (totalTargetItems == 0 || bookProgress == null) return 0.0;

    final learnedPagesCount =
        ProgressService.getCompletedPagesCount(bookProgress);
    return learnedPagesCount / totalTargetItems;
  }

  /// Get review progress percentage by book ID
  double getReviewProgressPercentageById(
    int bookId,
    BookDetails bookDetails,
    int reviewNumber,
  ) {
    final bookProgress = _progressById[bookId];
    final totalTargetItems = bookDetails.totalLearnableItems;
    if (totalTargetItems == 0 || bookProgress == null) return 0.0;

    final reviewPagesCount = ProgressService.getReviewCompletedPagesCount(
      bookProgress,
      reviewNumber,
    );
    return reviewPagesCount / totalTargetItems;
  }

  /// Check if book is completed by ID
  bool isBookCompletedById(int bookId, BookDetails bookDetails) {
    final bookProgress = _progressById[bookId];
    if (bookProgress == null) return false;

    final totalTargetItems = bookDetails.totalLearnableItems;
    if (totalTargetItems == 0) return false;

    final learnedItemsCount =
        ProgressService.getCompletedPagesCount(bookProgress);
    return learnedItemsCount >= totalTargetItems;
  }

  /// Check if a review cycle is completed by ID
  bool _isReviewCycleCompletedById(
    int bookId,
    int reviewCycleNumber,
    BookDetails bookDetails,
  ) {
    final bookProgress = _progressById[bookId];
    final totalItems = bookDetails.totalLearnableItems;
    if (totalItems == 0 || bookProgress == null || bookProgress.isEmpty) {
      return false;
    }

    final completedItemsInCycle = ProgressService.getReviewCompletedPagesCount(
      bookProgress,
      reviewCycleNumber,
    );

    return completedItemsInCycle >= totalItems;
  }

  /// Check if book is considered in progress by ID
  bool isBookConsideredInProgressById(int bookId, BookDetails bookDetails) {
    final bookProgress = _progressById[bookId];
    if (bookProgress == null || bookProgress.isEmpty) {
      return false;
    }

    final learnProgress = getLearnProgressPercentageById(bookId, bookDetails);
    if (learnProgress > 0 && learnProgress < 1.0) return true;

    for (int i = 1; i <= 3; i++) {
      final reviewProgress =
          getReviewProgressPercentageById(bookId, bookDetails, i);
      if (reviewProgress > 0 && reviewProgress < 1.0) return true;
    }

    return false;
  }

  /// Get number of completed cycles by book ID
  int getNumberOfCompletedCyclesById(int bookId, BookDetails bookDetails) {
    final bookProgress = _progressById[bookId];
    final totalTargetItems = bookDetails.totalLearnableItems;
    if (totalTargetItems == 0 || bookProgress == null) return 0;

    int cycles = 0;

    if (ProgressService.getCompletedPagesCount(bookProgress) >=
        totalTargetItems) {
      cycles++;
    }
    for (int i = 1; i <= 3; i++) {
      if (ProgressService.getReviewCompletedPagesCount(bookProgress, i) >=
          totalTargetItems) {
        cycles++;
      }
    }

    return cycles;
  }

  /// Get book progress summary by ID (synchronous)
  BookProgressSummary getBookProgressSummarySyncById(
    int bookId,
    String categoryName,
    String bookName,
    BookDetails bookDetails,
  ) {
    final cached = _progressSummaryCache[bookId];
    if (cached != null &&
        cached.totalItems == bookDetails.totalLearnableItems) {
      return cached;
    }

    final bookProgress = getProgressForBookById(bookId);
    final completionDate = getCompletionDateSyncById(bookId);
    final summary = _progressService.buildBookProgressSummary(
      categoryName,
      bookName,
      bookDetails,
      bookProgress,
      completionDate: completionDate,
    );
    _progressSummaryCache[bookId] = summary;
    return summary;
  }

  /// Export progress data
  Future<String?> exportProgressData() async {
    try {
      return await _progressService.exportProgressData();
    } catch (e, stackTrace) {
      _error = ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        customMessage: 'Failed to export progress data',
      );
      _logger.severe(
          'Error exporting progress: ${_error!.message}', e, stackTrace);
      notifyListeners();
      return null;
    }
  }

  /// Import progress data
  Future<bool> importProgressData(String jsonData) async {
    try {
      final success = await _progressService.importProgressData(jsonData);
      if (success) {
        await _loadInitialProgress();
      }
      return success;
    } catch (e, stackTrace) {
      _error = ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        customMessage: 'Failed to import progress data',
      );
      _logger.severe(
          'Error importing progress: ${_error!.message}', e, stackTrace);
      notifyListeners();
      return false;
    }
  }

  /// Clear all progress data
  Future<void> clearAllProgress() async {
    try {
      await _progressService.clearAllProgress();
      _progressById.clear();
      _completionDatesById.clear();
      _clearSummaryCache();
      notifyListeners();
    } catch (e, stackTrace) {
      _error = ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        customMessage: 'Failed to clear progress data',
      );
      _logger.severe(
          'Error clearing progress: ${_error!.message}', e, stackTrace);
      notifyListeners();
    }
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _logger.fine('Disposing ShamorZachorProgressProvider');
    _completionEventController.close();
    _progressService.dispose();
    super.dispose();
  }
}
