import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/data/data_providers/user_books_database_holder.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/library/bloc/library_event.dart';
import 'package:otzaria/migration/sync/background_db_sync_worker.dart';
import 'package:otzaria/migration/sync/file_sync_service.dart'
    show FileSyncResult;
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/settings/services/custom_folders/custom_folder.dart';

part 'custom_folders_event.dart';
part 'custom_folders_state.dart';

typedef LoadCustomFoldersFn = List<CustomFolder> Function();
typedef SaveCustomFoldersFn = Future<void> Function(List<CustomFolder> folders);
typedef SyncCustomFoldersFn = Future<FileSyncResult> Function(
  List<CustomFolder> folders,
);
typedef DeleteCustomFolderFromDbFn = Future<void> Function(CustomFolder folder);

class CustomFoldersBloc extends Bloc<CustomFoldersEvent, CustomFoldersState> {
  final LibraryBloc _libraryBloc;
  final LoadCustomFoldersFn? _loadFoldersOverride;
  final SaveCustomFoldersFn? _saveFoldersOverride;
  final SyncCustomFoldersFn? _syncFoldersOverride;
  final DeleteCustomFolderFromDbFn? _deleteFolderFromDbOverride;

  CustomFoldersBloc({
    required LibraryBloc libraryBloc,
    LoadCustomFoldersFn? loadFolders,
    SaveCustomFoldersFn? saveFolders,
    SyncCustomFoldersFn? syncFolders,
    DeleteCustomFolderFromDbFn? deleteFolderFromDb,
  })  : _libraryBloc = libraryBloc,
        _loadFoldersOverride = loadFolders,
        _saveFoldersOverride = saveFolders,
        _syncFoldersOverride = syncFolders,
        _deleteFolderFromDbOverride = deleteFolderFromDb,
        super(const CustomFoldersState()) {
    on<LoadCustomFolders>(_onLoad);
    on<AddCustomFolder>(_onAdd);
    on<RemoveCustomFolder>(_onRemove);
    on<ToggleAddToDatabase>(_onToggleAddToDatabase);
    on<RescanCustomFolders>(_onRescan);
  }

  void _onLoad(LoadCustomFolders event, Emitter<CustomFoldersState> emit) {
    emit(state.copyWith(folders: _loadFolders()));
  }

  Future<void> _onAdd(
      AddCustomFolder event, Emitter<CustomFoldersState> emit) async {
    final currentFolders = _loadFolders();
    final newFolders =
        CustomFoldersManager.addFolder(currentFolders, event.path);
    await _saveFolders(newFolders);
    emit(state.copyWith(
      folders: newFolders,
      isSyncing: true,
      activePath: event.path,
      message: null,
      error: null,
    ));

    try {
      final repository = await UserBooksDatabaseHolder.instance.repository;
      final folderName = event.path.split(RegExp(r'[/\\]')).last;
      final result = await DatabaseLibraryProvider.instance
          .scanAndAddExternalBooksFromFolder(
              event.path, folderName, repository);

      if (result.isSuccess) {
        _libraryBloc.add(RefreshLibrary());
        if (result.hasPartialFailure) {
          final failedMsg = result.failedDetails.isNotEmpty
              ? result.failedDetails.map((d) => '"${d.$1}": ${d.$2}').join('\n')
              : 'settings.custom_folders_bloc.scan_failed_count'
                  .tr(namedArgs: {'count': result.failedBooks.toString()});
          emit(state.copyWith(
            isSyncing: false,
            error: 'settings.custom_folders_bloc.scan_partial'.tr(namedArgs: {
              'added': result.addedBooks.toString(),
              'updated': result.updatedBooks.toString(),
              'failed': failedMsg,
            }),
          ));
        } else {
          emit(state.copyWith(isSyncing: false));
        }
      } else {
        emit(state.copyWith(
            isSyncing: false,
            error: 'settings.custom_folders_bloc.scan_fatal_error'
                .tr(namedArgs: {'error': result.fatalError.toString()})));
      }
    } catch (e) {
      emit(state.copyWith(
          isSyncing: false,
          error: 'settings.custom_folders_bloc.scan_error'
              .tr(namedArgs: {'error': e.toString()})));
    }
  }

  Future<void> _onRemove(
      RemoveCustomFolder event, Emitter<CustomFoldersState> emit) async {
    final currentFolders = _loadFolders();
    final newFolders =
        CustomFoldersManager.removeFolder(currentFolders, event.folder.path);
    await _saveFolders(newFolders);
    emit(state.copyWith(folders: newFolders, message: null, error: null));

    if (event.deleteFromDb) {
      emit(state.copyWith(isSyncing: true, message: null, error: null));
      try {
        await _deleteFolderFromDb(event.folder);
        emit(state.copyWith(
          isSyncing: false,
          message: 'settings.custom_folders_bloc.removed_with_books'.tr(),
        ));
      } catch (e) {
        emit(state.copyWith(
          isSyncing: false,
          error: 'settings.custom_folders_bloc.db_delete_error'
              .tr(namedArgs: {'error': e.toString()}),
        ));
        return;
      }
    } else {
      emit(state.copyWith(
        message: 'settings.custom_folders_bloc.removed_kept_books'.tr(),
      ));
    }
    _libraryBloc.add(RefreshLibrary());
  }

  Future<void> _onToggleAddToDatabase(
      ToggleAddToDatabase event, Emitter<CustomFoldersState> emit) async {
    final currentFolders = _loadFolders();
    final newFolders = CustomFoldersManager.updateFolderDbSetting(
      currentFolders,
      event.folder.path,
      event.value,
    );
    await _saveFolders(newFolders);
    emit(state.copyWith(
      folders: newFolders,
      isSyncing: true,
      activePath: event.folder.path,
      message: null,
      error: null,
    ));

    try {
      final result = await _syncCustomFolders(newFolders);
      if (!event.value) {
        emit(state.copyWith(
          isSyncing: false,
          message: 'settings.custom_folders_bloc.db_unset_success'.tr(),
        ));
      } else {
        final hasChanges = result.addedBooks > 0 || result.updatedBooks > 0;
        emit(state.copyWith(
          isSyncing: false,
          message: hasChanges
              ? 'settings.custom_folders_bloc.scan_completed_counts'
                  .tr(namedArgs: {
                  'added': result.addedBooks.toString(),
                  'updated': result.updatedBooks.toString(),
                })
              : null,
        ));
      }
      _libraryBloc.add(RefreshLibrary());
    } catch (e) {
      emit(state.copyWith(
          isSyncing: false,
          error: 'settings.custom_folders_bloc.sync_error'
              .tr(namedArgs: {'error': e.toString()})));
    }
  }

  Future<void> _onRescan(
      RescanCustomFolders event, Emitter<CustomFoldersState> emit) async {
    final currentFolders = _loadFolders();
    emit(state.copyWith(
      folders: currentFolders,
      isSyncing: true,
      message: null,
      error: null,
    ));
    try {
      final result = await _syncCustomFolders(currentFolders);
      final hasChanges = result.addedBooks > 0 || result.updatedBooks > 0;
      final message = hasChanges
          ? 'settings.custom_folders_bloc.scan_completed_counts'.tr(namedArgs: {
              'added': result.addedBooks.toString(),
              'updated': result.updatedBooks.toString(),
            })
          : event.showNoChangesMessage
              ? 'settings.custom_folders_bloc.scan_completed_no_new'.tr()
              : null;
      emit(state.copyWith(isSyncing: false, message: message));
      _libraryBloc.add(RefreshLibrary());
    } catch (e) {
      emit(state.copyWith(
          isSyncing: false,
          error: 'settings.custom_folders_bloc.rescan_error'
              .tr(namedArgs: {'error': e.toString()})));
    }
  }

  List<CustomFolder> _loadFolders() {
    final override = _loadFoldersOverride;
    if (override != null) {
      return override();
    }

    final jsonString =
        Settings.getValue<String>(SettingsRepository.keyCustomFolders);
    return CustomFoldersManager.loadFolders(jsonString);
  }

  Future<FileSyncResult> _syncCustomFolders(List<CustomFolder> folders) {
    final override = _syncFoldersOverride;
    if (override != null) {
      return override(folders);
    }

    return _runSync(folders);
  }

  Future<void> _deleteFolderFromDb(CustomFolder folder) {
    final override = _deleteFolderFromDbOverride;
    if (override != null) {
      return override(folder);
    }

    return _deleteFromDatabase(folder);
  }

  Future<FileSyncResult> _runSync(List<CustomFolder> folders) async {
    final sqliteProvider = SqliteDataProvider.instance;
    if (!sqliteProvider.isInitialized) await sqliteProvider.initialize();
    if (!sqliteProvider.isInitialized) {
      throw Exception('settings.custom_folders_bloc.db_unavailable'.tr());
    }

    final dbPath = sqliteProvider.dbPath;
    final libraryPath = Settings.getValue<String>('key-library-path');
    if (libraryPath == null || libraryPath.isEmpty) {
      throw Exception('settings.custom_folders_bloc.library_path_unset'.tr());
    }

    final folderName =
        Settings.getValue<String>(SettingsRepository.keyLibraryFolderName) ??
            '';
    final userBooksDbPath = await UserBooksDatabaseHolder.resolveDbPath();

    // ה-close/reopen של ה-RO סביב הכתיבה מנוהלים *בתוך*
    // [runCustomFoldersDbSyncInIsolate] — בתוך יחידת ה-operationQueue — כדי
    // שה-RO לא ייסגר בזמן ההמתנה בתור.
    return await runCustomFoldersDbSyncInIsolate(
      dbPath: dbPath,
      userBooksDbPath: userBooksDbPath,
      libraryPath: libraryPath,
      customFolders: folders,
      folderName: folderName,
      prepareForWrite: sqliteProvider.closeForExternalWrite,
      restoreAfterWrite: sqliteProvider.reopenAfterExternalWrite,
    );
  }

  Future<void> _deleteFromDatabase(CustomFolder folder) async {
    final sqliteProvider = SqliteDataProvider.instance;
    if (!sqliteProvider.isInitialized) await sqliteProvider.initialize();

    final userBooksDbPath = await UserBooksDatabaseHolder.resolveDbPath();

    // הזיהוי הוא לפי נתיב התיקייה (שם ה-source הייחודי), לא לפי שם
    // הקטגוריה — כך הסרת תיקייה לא תפגע בספרי תיקייה אחרת בעלת אותו
    // basename שממוזגת לאותה קטגוריה.
    // ה-close/reopen של ה-RO מנוהלים *בתוך* [runDeleteFolderFromDbInIsolate].
    await runDeleteFolderFromDbInIsolate(
      dbPath: sqliteProvider.dbPath,
      userBooksDbPath: userBooksDbPath,
      folderPath: folder.path,
      prepareForWrite: sqliteProvider.closeForExternalWrite,
      restoreAfterWrite: sqliteProvider.reopenAfterExternalWrite,
    );
  }

  Future<void> _saveFolders(List<CustomFolder> folders) async {
    final override = _saveFoldersOverride;
    if (override != null) {
      await override(folders);
      return;
    }

    await Settings.setValue(
      SettingsRepository.keyCustomFolders,
      CustomFoldersManager.saveFolders(folders),
    );
  }
}
