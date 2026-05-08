import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/file_sync/bloc/file_sync_event.dart';
import 'package:otzaria/file_sync/bloc/file_sync_state.dart';
import 'package:otzaria/file_sync/repository/file_sync_repository.dart';
import 'package:otzaria/file_sync/library_diff_sync_worker.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/work_status/work_status_cubit.dart';
import 'package:otzaria/work_status/work_status_item.dart';

const _kSyncTaskId = 'library-db-sync';

class FileSyncBloc extends Bloc<FileSyncEvent, FileSyncState> {
  final FileSyncRepository repository;
  final WorkStatusCubit workStatusCubit;

  LibraryDiffSyncWorkerService? _syncService;
  int _syncRunId = 0;

  bool get _isOffline =>
      Settings.getValue<bool>(SettingsRepository.keyOfflineMode) ?? false;

  bool get _softwareAndBookUpdatesEnabled =>
      Settings.getValue<bool>(
        SettingsRepository.keySoftwareAndBookUpdatesEnabled,
        defaultValue: true,
      ) ??
      true;

  FileSyncBloc({required this.repository, required this.workStatusCubit})
      : super(const FileSyncState()) {
    on<StartSync>(_onStartSync);
    on<StopSync>(_onStopSync);
    on<ResetState>(_onResetState);
  }

  Future<void> _onStartSync(
    StartSync event,
    Emitter<FileSyncState> emit,
  ) async {
    if (_isOffline) {
      emit(state.copyWith(
        status: FileSyncStatus.initial,
        message: 'file_sync.offline_mode',
      ));
      return;
    }

    if (!_softwareAndBookUpdatesEnabled) {
      emit(state.copyWith(
        status: FileSyncStatus.initial,
        message: 'file_sync.updates_disabled',
      ));
      return;
    }

    if (state.status == FileSyncStatus.syncing) return;
    if (state.status == FileSyncStatus.completed) {
      emit(const FileSyncState());
    }

    emit(state.copyWith(
      status: FileSyncStatus.syncing,
      message: 'file_sync.checking_updates',
    ));

    workStatusCubit.upsert(WorkStatusItem(
      id: _kSyncTaskId,
      title: 'file_sync.sync_title'.tr(),
      message: 'file_sync.checking_message'.tr(),
    ));

    final runId = ++_syncRunId;
    bool isCurrent() => _syncRunId == runId && !isClosed;

    try {
      final currentVersion = await repository.getCurrentLibraryVersion();
      final assets = await repository.fetchAvailableDiffAssets();

      // Guard after slow network calls: a Stop or new Start may have fired.
      if (!isCurrent()) return;

      final chain = FileSyncRepository.buildUpdateChain(
        currentVersion: currentVersion,
        availableAssets: assets,
      );

      if (chain.isEmpty) {
        workStatusCubit.remove(_kSyncTaskId);
        emit(state.copyWith(
          status: FileSyncStatus.completed,
          hasNewSync: false,
          message: 'file_sync.library_up_to_date',
        ));
        return;
      }

      await DatabaseLibraryProvider.operationQueue.enqueue(() async {
        // Guard: a Stop or new Start may have fired while we waited in queue.
        if (!isCurrent()) return;

        await SqliteDataProvider.instance.dispose();

        _syncService = LibraryDiffSyncWorkerService();
        final dbPath = repository.getDbPath();

        var appliedCount = 0;
        var cancelled = false;
        String? failedMessage;

        try {
          await for (final update in _syncService!.start(
            dbPath: dbPath,
            assets: chain,
          )) {
            if (!isCurrent()) break;

            final item = _workItemForUpdate(update);
            if (item != null) workStatusCubit.upsert(item);

            if (update is LibraryDiffSyncCompleted) {
              appliedCount = update.appliedAssetCount;
              break;
            }
            if (update is LibraryDiffSyncCancelled) {
              cancelled = true;
              break;
            }
            if (update is LibraryDiffSyncFailed) {
              failedMessage = update.message;
              break;
            }
          }
        } finally {
          _syncService?.dispose();
          _syncService = null;
          await SqliteDataProvider.instance.initialize();
        }

        // Guard after finally: _onStopSync may have already updated the UI.
        if (!isCurrent()) return;

        workStatusCubit.remove(_kSyncTaskId);
        if (cancelled) {
          emit(const FileSyncState());
        } else if (failedMessage != null) {
          emit(state.copyWith(
            status: FileSyncStatus.error,
            message: 'file_sync.sync_error_title',
            errorMessage: failedMessage,
          ));
        } else {
          emit(state.copyWith(
            status: FileSyncStatus.completed,
            hasNewSync: appliedCount > 0,
            message: appliedCount > 0
                ? 'file_sync.applied_updates'
                    .tr(namedArgs: {'count': '$appliedCount'})
                : 'file_sync.library_up_to_date'.tr(),
            currentProgress: appliedCount,
            totalFiles: chain.length,
          ));
        }
      });
    } catch (e) {
      if (!isCurrent()) return;
      workStatusCubit.remove(_kSyncTaskId);
      emit(state.copyWith(
        status: FileSyncStatus.error,
        message: 'שגיאה בסנכרון: ${e.toString()}',
        errorMessage: e.toString(),
      ));
    }
  }

  void _onStopSync(StopSync event, Emitter<FileSyncState> emit) {
    _syncRunId++;
    _syncService?.cancel();
    workStatusCubit.remove(_kSyncTaskId);
    emit(const FileSyncState());
  }

  void _onResetState(ResetState event, Emitter<FileSyncState> emit) {
    emit(const FileSyncState());
  }

  WorkStatusItem? _workItemForUpdate(LibraryDiffSyncUpdate update) {
    return switch (update) {
      LibraryDiffStageChanged u when u.stage == 'downloadStarted' =>
        WorkStatusItem(
          id: _kSyncTaskId,
          title: 'סנכרון ספרייה',
          message: 'מוריד ${u.assetName}',
          detail: _assetProgress(u.assetIndex, u.totalAssets),
        ),
      LibraryDiffDownloadProgress u => WorkStatusItem(
          id: _kSyncTaskId,
          title: 'סנכרון ספרייה',
          message: 'מוריד ${u.assetName}',
          detail: _bytesLabel(u.downloadedBytes, u.totalBytes),
          progress: u.totalBytes != null && u.totalBytes! > 0
              ? (u.downloadedBytes / u.totalBytes!).clamp(0.0, 1.0)
              : null,
        ),
      LibraryDiffStageChanged u when u.stage == 'extractStarted' =>
        WorkStatusItem(
          id: _kSyncTaskId,
          title: 'סנכרון ספרייה',
          message: 'מחלץ את קובץ העדכון',
          detail: u.assetName,
        ),
      LibraryDiffStageChanged u when u.stage == 'sqlSplitStarted' =>
        WorkStatusItem(
          id: _kSyncTaskId,
          title: 'סנכרון ספרייה',
          message: 'מפענח את קובץ העדכון',
          detail: 'מכין פקודות SQL',
        ),
      LibraryDiffStageChanged u when u.stage == 'applyStarted' =>
        WorkStatusItem(
          id: _kSyncTaskId,
          title: 'סנכרון ספרייה',
          message: 'מחיל עדכון על מסד הנתונים',
          detail: _assetProgress(u.assetIndex, u.totalAssets),
        ),
      LibraryDiffApplyProgress u => WorkStatusItem(
          id: _kSyncTaskId,
          title: 'סנכרון ספרייה',
          message: 'מחיל עדכון על מסד הנתונים',
          detail: 'פקודה ${u.appliedStatements} מתוך ${u.totalStatements}'
              '${u.totalAssets > 1 ? ' • קובץ ${u.assetIndex + 1}/${u.totalAssets}' : ''}',
          progress: (u.appliedStatements / u.totalStatements).clamp(0.0, 1.0),
        ),
      _ => null,
    };
  }

  static String? _assetProgress(int index, int total) =>
      total > 1 ? 'קובץ ${index + 1} מתוך $total' : null;

  static String _bytesLabel(int downloaded, int? total) {
    String fmt(int bytes) {
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)}KB';
      }
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }

    return total != null
        ? '${fmt(downloaded)} מתוך ${fmt(total)}'
        : fmt(downloaded);
  }

  @override
  Future<void> close() {
    _syncService?.dispose();
    return super.close();
  }
}
