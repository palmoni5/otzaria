import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ffi/ffi.dart';
import 'package:zstandard_native/zstandard_native_bindings.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/core/http_client_registry.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/empty_library/bloc/empty_library_event.dart';
import 'package:otzaria/empty_library/bloc/empty_library_state.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/utils/download_eta_estimator.dart';
import 'package:otzaria/utils/file/zip_extractor_service.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class EmptyLibraryBloc extends Bloc<EmptyLibraryEvent, EmptyLibraryState> {
  EmptyLibraryBloc({
    http.Client? httpClient,
    Future<void> Function(String archivePath, String outputPath,
            void Function(double progress)? onProgress)?
        extractCompressedDatabase,
    Future<void> Function(String archivePath, String outputDir,
            void Function(double progress)? onProgress)?
        extractTarArchive,
    String? defaultLibraryPathOverride,
  })  : _httpClient = httpClient ?? http.Client(),
        _extractCompressedDatabase =
            extractCompressedDatabase ?? _extractZstWithSystemProcess,
        _extractTarArchive = extractTarArchive ?? _extractTarZst,
        _defaultLibraryPathOverride = defaultLibraryPathOverride,
        super(EmptyLibraryInitial(
            downloadDisabledReason:
                'empty_library.bloc.checking_free_space'.tr())) {
    HttpClientRegistry.register(_httpClient.close);
    on<PickDirectoryRequested>(_onPickDirectoryRequested);
    on<PickArchiveFileRequested>(_onPickArchiveFileRequested);
    on<DownloadLibraryRequested>(_onDownloadLibraryRequested);
    on<DeleteZipAnswered>(_onDeleteZipAnswered);
    on<PickDbFileRequested>(_onPickDbFileRequested);
    on<CheckDiskSpaceRequested>(_onCheckDiskSpaceRequested);
    // בדיקת מקום פנוי מתבצעת מיד — כפתור ההורדה מושבת עד להשלמתה
    add(CheckDiskSpaceRequested());
  }

  final http.Client _httpClient;
  final Future<void> Function(String archivePath, String outputPath,
      void Function(double progress)? onProgress) _extractCompressedDatabase;
  final Future<void> Function(String archivePath, String outputDir,
      void Function(double progress)? onProgress) _extractTarArchive;

  /// בונה callback שמ-emit-ת התקדמות חילוץ למסך.
  /// הקריאות מגיעות מתוך ה-isolet בזמן ה-await על פעולת החילוץ — עדיין
  /// בתוך מטפל האירוע — ולכן ה-emit חוקי.
  void Function(double) _extractProgress(
    Emitter<EmptyLibraryState> emit,
    String selectedPath,
    String message,
  ) =>
      (progress) => emit(EmptyLibraryExtracting(
            selectedPath: selectedPath,
            progress: progress,
            message: message,
          ));
  // סיבת השבתת כפתור ההורדה — נשמרת כ-instance field כדי להישמר בין state transitions
  String? _downloadDisabledReason =
      'empty_library.bloc.checking_free_space'.tr();
  final String? _defaultLibraryPathOverride;

  Future<void> _onPickDirectoryRequested(
      PickDirectoryRequested event, Emitter<EmptyLibraryState> emit) async {
    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'empty_library.bloc.pick_library_dir_title'.tr(),
      lockParentWindow: true,
    );

    if (result == null) return;

    emit(EmptyLibraryLoading(selectedPath: result));
    await _handleDirectorySelection(result, emit);
  }

  Future<void> _onPickArchiveFileRequested(
      PickArchiveFileRequested event, Emitter<EmptyLibraryState> emit) async {
    String? selectedFile = event.overrideFilePath;
    if (selectedFile == null) {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'zst'],
        dialogTitle: 'empty_library.bloc.pick_archive_title'.tr(),
        lockParentWindow: true,
      );

      if (result == null || result.files.isEmpty) return;

      selectedFile = result.files.first.path;
      if (selectedFile == null) return;
    }

    emit(EmptyLibraryLoading(selectedPath: selectedFile));

    if (selectedFile.toLowerCase().endsWith('.zip')) {
      await _handleZipFile(selectedFile, emit);
    } else if (selectedFile.toLowerCase().endsWith('.zst')) {
      await _handleZstFile(selectedFile, emit);
    } else {
      emit(_error(
        errorMessage: 'empty_library.bloc.unsupported_file_type'.tr(),
        selectedPath: selectedFile,
      ));
    }
  }

  Future<void> _handleDirectorySelection(
      String directoryPath, Emitter<EmptyLibraryState> emit) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        emit(_error(
          errorMessage: 'empty_library.bloc.directory_not_exists'
              .tr(namedArgs: {'path': directoryPath}),
          selectedPath: directoryPath,
        ));
        return;
      }

      // מחפש את המסד בתיקייה שנבחרה (ללא חיפוש עמוק)
      final dbFilePath =
          path.join(directoryPath, DatabaseConstants.databaseFileName);
      final dbFile = File(dbFilePath);

      if (!await dbFile.exists()) {
        emit(_error(
          errorMessage: 'empty_library.bloc.db_not_found_in_dir'.tr(
              namedArgs: {'dbName': DatabaseConstants.databaseFileName}),
          selectedPath: directoryPath,
        ));
        return;
      }

      // Android: בדוק אם sqlite3 native יכול לפתוח את הקובץ ישירות.
      // אחסון Scoped Storage (כגון /storage/emulated/0/...) נגיש ל-dart:io
      // בחלק מהמכשירים אבל לא לספריית sqlite3 native.
      if (Platform.isAndroid && !_isPathNativeAccessible(dbFilePath)) {
        final internalDbPath = await _getInternalDbPath();
        final dbStat = await dbFile.stat();
        final dbSize = dbStat.size;
        final appDir = await getApplicationDocumentsDirectory();
        final freeSpace = await _getFreeInternalSpace(appDir.path);

        // בדיקת מקום פנוי לפני ניסיון ההעתקה
        // (גם "העבר" לא יעזור — הוא מעתיק לפנימי לפני מחיקת החיצוני)
        if (freeSpace > 0 && dbSize > freeSpace) {
          final needed = (dbSize / 1024 / 1024).toStringAsFixed(1);
          final free = (freeSpace / 1024 / 1024).toStringAsFixed(1);
          emit(_error(
            errorMessage: 'empty_library.bloc.not_enough_internal_space'
                .tr(namedArgs: {'needed': needed, 'free': free}),
            selectedPath: directoryPath,
          ));
          return;
        }

        // נסה להעתיק ישירות — עובד אם לאפליקציה יש READ_EXTERNAL_STORAGE
        emit(EmptyLibraryLoading(selectedPath: directoryPath));
        try {
          final destFile = File(internalDbPath);
          await destFile.parent.create(recursive: true);
          await File(dbFilePath).openRead().pipe(destFile.openWrite());

          // העתקה הצליחה — שמור הגדרות והמשך
          await Settings.setValue(
              SettingsRepository.keyLibraryPath, directoryPath);
          await Settings.setValue(SettingsRepository.keyLibraryFolderName, '');
          await Settings.setValue(
              SettingsRepository.keyDbEffectivePath, internalDbPath);
          emit(EmptyLibraryDirectorySelected(selectedPath: directoryPath));
          return;
        } on PathAccessException {
          // dart:io לא יכול לגשת לקובץ — צריך FilePicker (SAF)
          // ממשיכים למטה להצגת הדיאלוג
        } catch (copyError) {
          // שגיאת I/O שאינה הרשאה (למשל ENOSPC, שגיאת קריאה)
          // מנקים קובץ יעד חלקי אם נוצר
          try {
            await File(internalDbPath).delete();
          } catch (_) {}
          final isNoSpace = copyError.toString().contains('No space') ||
              copyError.toString().contains('ENOSPC');
          emit(_error(
            errorMessage: isNoSpace
                ? 'empty_library.bloc.no_space_try_again'.tr()
                : 'empty_library.bloc.library_copy_error'
                    .tr(namedArgs: {'error': '$copyError'}),
            selectedPath: directoryPath,
          ));
          return;
        }
        // נגענו כאן רק אם PathAccessException — הדרך היחידה קדימה היא picker שני
        emit(EmptyLibraryAskingDbCopy(
          externalDbPath: dbFilePath,
          libraryPath: directoryPath,
          internalDbPath: internalDbPath,
          dbSizeBytes: dbSize,
          freeSpaceBytes: freeSpace,
        ));
        return;
      }

      await Settings.setValue(SettingsRepository.keyLibraryPath, directoryPath);
      await Settings.setValue(SettingsRepository.keyLibraryFolderName, '');
      // נקה override קודם אם קיים
      await Settings.setValue(SettingsRepository.keyDbEffectivePath, '');

      emit(EmptyLibraryDirectorySelected(selectedPath: directoryPath));
    } catch (e) {
      emit(_error(
        errorMessage: 'empty_library.bloc.directory_check_error'
            .tr(namedArgs: {'error': '$e'}),
        selectedPath: directoryPath,
      ));
    }
  }

  /// מחזיר את הנתיב הראשון בעץ ההורים שקיים בפועל, לצורך בדיקת df.
  static String _findExistingAncestor(String dirPath) {
    var dir = Directory(dirPath);
    while (!dir.existsSync() && dir.parent.path != dir.path) {
      dir = dir.parent;
    }
    return dir.path;
  }

  /// בודק אם נתיב נגיש לספריית sqlite3 native ב-Android.
  ///
  /// ב-Android Scoped Storage, רק אחסון פנימי (/data/) ואחסון חיצוני
  /// ייעודי לאפליקציה (Android/data/PACKAGE_NAME/) נגיש לגישה native.
  /// נתיבים כגון /storage/emulated/0/Download/ אינם נגישים.
  static bool _isPathNativeAccessible(String filePath) {
    if (!Platform.isAndroid) return true;
    // אחסון פנימי
    if (filePath.startsWith('/data/')) return true;
    // אחסון חיצוני ייעודי לאפליקציה
    if (filePath.contains('/Android/data/')) return true;
    // אחסון חיצוני ייעודי אחר
    if (filePath.contains('/Android/obb/')) return true;
    return false;
  }

  /// מחזיר את הנתיב הפנימי שאליו יועתק seforim.db ב-Android.
  static Future<String> _getInternalDbPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(
        appDir.path, 'otzaria', DatabaseConstants.databaseFileName);
  }

  /// מחזיר מידע df עבור נתיב נתון: filesystem ומקום פנוי בבייטים.
  /// מחזיר freeBytes = -1 אם לא ניתן לקבוע.
  static Future<_DfInfo> _getDfInfo(String dirPath) async {
    if (!Platform.isAndroid) {
      return const _DfInfo(filesystem: null, freeBytes: -1);
    }
    try {
      // -k (בלוקים של 1024B) נתמך גם ב-toybox של אנדרואיד וגם ב-coreutils.
      // הדגל -B1 של GNU אינו קיים ב-toybox ומחזיר exit!=0, מה שהשבית בעבר
      // את כל בדיקת המקום הפנוי באנדרואיד (freeBytes נשאר -1 תמיד).
      final result =
          await Process.run('df', ['-k', dirPath], runInShell: false);
      if (result.exitCode != 0) {
        return const _DfInfo(filesystem: null, freeBytes: -1);
      }
      final lines = result.stdout.toString().trim().split('\n');
      if (lines.length < 2) {
        return const _DfInfo(filesystem: null, freeBytes: -1);
      }
      // שורת הנתונים של df -k: Filesystem 1K-blocks Used Available Use% Mount
      final parts = lines.last.trim().split(RegExp(r'\s+'));
      if (parts.length < 4) {
        return const _DfInfo(filesystem: null, freeBytes: -1);
      }
      final availableKb = int.tryParse(parts[3]);
      return _DfInfo(
        filesystem: parts[0],
        freeBytes: availableKb == null ? -1 : availableKb * 1024,
      );
    } catch (_) {
      return const _DfInfo(filesystem: null, freeBytes: -1);
    }
  }

  /// עוטף את _getDfInfo להחזרת מקום פנוי בלבד (לשימוש קיים).
  static Future<int> _getFreeInternalSpace(String dirPath) async =>
      (await _getDfInfo(dirPath)).freeBytes;

  /// בודק אם יש מספיק מקום פנוי להורדה ולחילוץ הספרייה.
  ///
  /// [downloadSize] - גודל הקבצים הדחוסים בבייטים. כשידוע (אחרי קריאת
  /// ה-Content-Length של שלושת הקבצים) מועבר הסכום **האמיתי**; אחרת משמש
  /// אומדן (1.5GB) לבדיקת הסף הראשונית שמשביתה את כפתור ההורדה.
  ///
  /// מחזיר הודעת שגיאה אם אין מספיק מקום, או null אם הכל תקין.
  /// מטפל גם בתרחיש שבו temp ותיקיית הספרייה חולקים אותו volume.
  Future<String?> _checkSpaceForDownload({int? downloadSize}) async {
    if (!Platform.isAndroid) return null;
    // אומדן fallback לסכום הדחוס של שלושת הקבצים, בשימוש רק כש-downloadSize
    // לא ידוע (בדיקת הסף הראשונית, או כש-HEAD לא החזיר Content-Length).
    // נכון להיום הסכום האמיתי ~1.45GB (seforim ~1.01GB + תלמוד ~0.44GB +
    // קטלוג ~0.005GB). אם ה-DB יגדל בעתיד מעבר ל-1.5GB, יש להגדיל את
    // הקבוע בהתאם — אחרת בדיקת הסף הראשונית עלולה לעבור בטעות במכשירים עם
    // מעט מקום (הבדיקה האמיתית מול grandTotal עדיין תתפוס זאת בהמשך).
    final int kDownloadSize = downloadSize ?? 1610612736; // אומדן 1.5 GB
    const int kExtractSize = 6979321856; // 6.5 GB

    final tempPath = Directory.systemTemp.path;
    final libraryPath =
        _defaultLibraryPathOverride ?? await AppPaths.getDefaultLibraryPath();
    final checkPath = _findExistingAncestor(libraryPath);

    final tempInfo = await _getDfInfo(tempPath);
    final extractInfo = await _getDfInfo(checkPath);

    final sameVolume = tempInfo.filesystem != null &&
        extractInfo.filesystem != null &&
        tempInfo.filesystem == extractInfo.filesystem;

    if (sameVolume) {
      // שני הנתיבים על אותו volume: צריך מקום לשניהם יחד.
      final free = tempInfo.freeBytes;
      if (free > 0 && free < kDownloadSize + kExtractSize) {
        final freeGb = (free / 1024 / 1024 / 1024).toStringAsFixed(1);
        return 'empty_library.bloc.no_space_download_extract'
            .tr(namedArgs: {'free': freeGb});
      }
    } else {
      // volumes נפרדים: בדיקה לכל אחד בנפרד
      if (tempInfo.freeBytes > 0 && tempInfo.freeBytes < kDownloadSize) {
        final freeGb =
            (tempInfo.freeBytes / 1024 / 1024 / 1024).toStringAsFixed(1);
        return 'empty_library.bloc.no_space_download'
            .tr(namedArgs: {'free': freeGb});
      }
      if (extractInfo.freeBytes > 0 && extractInfo.freeBytes < kExtractSize) {
        final freeGb =
            (extractInfo.freeBytes / 1024 / 1024 / 1024).toStringAsFixed(1);
        return 'empty_library.bloc.no_space_extract'
            .tr(namedArgs: {'free': freeGb});
      }
    }
    return null;
  }

  Future<void> _onCheckDiskSpaceRequested(
      CheckDiskSpaceRequested event, Emitter<EmptyLibraryState> emit) async {
    _downloadDisabledReason = await _checkSpaceForDownload();
    emit(EmptyLibraryInitial(downloadDisabledReason: _downloadDisabledReason));
  }

  /// מייצר EmptyLibraryError תמיד עם downloadDisabledReason הנוכחי.
  EmptyLibraryError _error({
    String? errorMessage,
    String? selectedPath,
    List<String>? zipFiles,
  }) =>
      EmptyLibraryError(
        errorMessage: errorMessage,
        selectedPath: selectedPath,
        zipFiles: zipFiles,
        downloadDisabledReason: _downloadDisabledReason,
      );

  /// בוחר את קובץ seforim.db ישירות דרך FilePicker (SAF-aware).
  ///
  /// משמש כאשר הנתיב הפיזי אינו נגיש ל-dart:io ב-Android Scoped Storage.
  /// FilePicker.pickFiles() מטפל ב-SAF ומחזיר נתיב נגיש (מ-cache אם נדרש).
  Future<void> _onPickDbFileRequested(
      PickDbFileRequested event, Emitter<EmptyLibraryState> emit) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        dialogTitle: 'empty_library.bloc.pick_db_file_title'
            .tr(namedArgs: {'dbName': DatabaseConstants.databaseFileName}),
        lockParentWindow: true,
      );

      if (result == null || result.files.isEmpty) {
        // המשתמש ביטל — חזרה לדיאלוג ההעתקה
        final internalDbPath = await _getInternalDbPath();
        emit(EmptyLibraryAskingDbCopy(
          externalDbPath: '',
          libraryPath: event.libraryPath,
          internalDbPath: internalDbPath,
          dbSizeBytes: 0,
          freeSpaceBytes: -1,
        ));
        return;
      }

      final pickedFile = result.files.first;

      // וודא שנבחר הקובץ הנכון — אם לא, חזור לדיאלוג עם הסבר
      if (pickedFile.name != DatabaseConstants.databaseFileName) {
        final internalDbPath = await _getInternalDbPath();
        emit(EmptyLibraryAskingDbCopy(
          externalDbPath: event.externalDbPath,
          libraryPath: event.libraryPath,
          internalDbPath: internalDbPath,
          dbSizeBytes: 0,
          freeSpaceBytes: -1,
          errorMessage: 'empty_library.bloc.wrong_db_file_selected'.tr(
              namedArgs: {
                'dbName': DatabaseConstants.databaseFileName,
                'picked': pickedFile.name,
              }),
        ));
        return;
      }

      emit(EmptyLibraryLoading(selectedPath: event.libraryPath));

      final sourcePath = pickedFile.path;
      final destFile = File(event.internalDbPath);
      await destFile.parent.create(recursive: true);

      if (sourcePath == null) {
        throw Exception('empty_library.bloc.file_picker_no_path'.tr());
      }

      // העתק תוך שימוש ב-streams (FilePicker מספק נתיב נגיש מ-cache SAF)
      await File(sourcePath).openRead().pipe(destFile.openWrite());

      // אם בחר להעביר — מחק את קובץ המקור החיצוני האמיתי
      if (event.shouldMove && event.externalDbPath.isNotEmpty) {
        try {
          await File(event.externalDbPath).delete();
        } catch (_) {
          // dart:io עשוי להיכשל על Scoped Storage — לא קריטי, ה-DB כבר הועתק
        }
      }

      await Settings.setValue(
          SettingsRepository.keyLibraryPath, event.libraryPath);
      await Settings.setValue(SettingsRepository.keyLibraryFolderName, '');
      await Settings.setValue(
          SettingsRepository.keyDbEffectivePath, event.internalDbPath);

      emit(EmptyLibraryDirectorySelected(selectedPath: event.libraryPath));
    } catch (e) {
      // זיהוי שגיאת חוסר מקום (ENOSPC / No space left)
      final isNoSpace = e.toString().contains('No space') ||
          e.toString().contains('ENOSPC') ||
          e.toString().contains('28');
      final msg = isNoSpace
          ? 'empty_library.bloc.no_space_move_hint'.tr()
          : 'empty_library.bloc.library_copy_error'
              .tr(namedArgs: {'error': '$e'});
      emit(_error(
        errorMessage: msg,
        selectedPath: event.libraryPath,
      ));
    }
  }

  Future<void> _handleZstFile(
      String zstFilePath, Emitter<EmptyLibraryState> emit) async {
    try {
      final outputDir = path.dirname(zstFilePath);
      final outputPath = path.join(
        outputDir,
        DatabaseConstants.databaseFileName,
      );

      emit(EmptyLibraryExtracting(
        selectedPath: zstFilePath,
        progress: 0.0,
        message: 'empty_library.bloc.extracting_compressed_db'.tr(),
      ));

      await _extractCompressedDatabase(zstFilePath, outputPath,
          _extractProgress(emit, zstFilePath, 'מחלץ קובץ DB דחוס...'));

      // אם הקובץ שנבחר הוא ה-DB הראשי, חפש את 2 הקבצים האחרים של חבילת FULL
      // (קטלוג ו-תלמוד בבלי) באותה תיקייה וחלץ גם אותם. זה חוסך למשתמש
      // הורדה מהרשת של ~3GB אחרי שהוא כבר הוריד אותם בחבילת ה-FULL.
      final basename = path.basename(zstFilePath).toLowerCase();
      if (basename == DatabaseConstants.databaseArchiveFileName.toLowerCase()) {
        await _extractBundleSiblings(outputDir, emit);
      }

      emit(EmptyLibraryExtracting(
        selectedPath: zstFilePath,
        progress: 1.0,
        message: 'empty_library.bloc.extraction_complete'.tr(),
      ));

      emit(EmptyLibraryAskingDeleteZip(
        zipPath: zstFilePath,
        extractedPath: outputDir,
      ));
    } catch (e) {
      emit(_error(
        errorMessage: 'empty_library.bloc.compressed_extract_error'
            .tr(namedArgs: {'error': '$e'}),
        selectedPath: zstFilePath,
      ));
    }
  }

  /// מחלץ קבצי FULL bundle נלווים (קטלוג חיצוני ו-תלמוד בבלי) אם הם
  /// נמצאים באותה תיקייה כמו ה-DB הראשי. best-effort: כישלון בקובץ אחד
  /// לא עוצר את האחרים, כי ה-DB הראשי כבר נחלץ בהצלחה והאפליקציה תוכל
  /// לעבוד גם בלי הקבצים הנלווים (הם יורדו דרך הזרימה הרגילה בעת הצורך).
  Future<void> _extractBundleSiblings(
      String dir, Emitter<EmptyLibraryState> emit) async {
    final catalogArchive = File(path.join(
      dir,
      DatabaseConstants.externalCatalogArchiveFileName,
    ));
    if (await catalogArchive.exists()) {
      try {
        emit(EmptyLibraryExtracting(
          selectedPath: catalogArchive.path,
          progress: 0.0,
          message: 'empty_library.bloc.extracting_otzar_catalog'.tr(),
        ));
        await _extractCompressedDatabase(
          catalogArchive.path,
          path.join(dir, DatabaseConstants.externalCatalogDatabaseFileName),
          _extractProgress(
              emit, catalogArchive.path, 'מחלץ קטלוג אוצר החכמה...'),
        );
      } catch (e) {
        debugPrint('Failed to extract bundled catalog archive: $e');
      }
    }

    final talmudArchive = File(path.join(
      dir,
      DatabaseConstants.talmudBavliArchiveFileName,
    ));
    if (await talmudArchive.exists()) {
      try {
        emit(EmptyLibraryExtracting(
          selectedPath: talmudArchive.path,
          progress: 0.0,
          message: 'empty_library.bloc.extracting_talmud_bavli'.tr(),
        ));
        await _extractTarArchive(
            talmudArchive.path,
            dir,
            _extractProgress(
                emit, talmudArchive.path, 'מחלץ ספרי תלמוד בבלי...'));
      } catch (e) {
        debugPrint('Failed to extract bundled Talmud Bavli archive: $e');
      }
    }
  }

  Future<void> _handleZipFile(
      String zipFilePath, Emitter<EmptyLibraryState> emit) async {
    try {
      emit(EmptyLibraryExtracting(
        selectedPath: '',
        progress: 0.0,
        message: 'empty_library.bloc.starting_extraction'.tr(),
      ));

      final extractionResult =
          await ZipExtractorService.checkAndExtractZipIfNeeded(
        path.dirname(zipFilePath),
        onProgress: (p, m) {
          emit(EmptyLibraryExtracting(
            selectedPath: zipFilePath,
            progress: p,
            message: m,
          ));
        },
        onAskDeleteZip: () async => false,
      );

      if (!extractionResult.success) {
        emit(_error(
          errorMessage: extractionResult.errorMessage ??
              'empty_library.bloc.extraction_error'.tr(),
          zipFiles: extractionResult.zipFiles,
        ));
        return;
      }

      // אם החילוץ הצליח, נשאל את המשתמש אם למחוק את ה-ZIP
      if (extractionResult.successfullyExtracted) {
        emit(EmptyLibraryAskingDeleteZip(
          zipPath: zipFilePath,
          extractedPath: path.dirname(zipFilePath),
        ));
        return;
      }

      // אם לא היה חילוץ, נמשיך ישירות לבדיקת הקובץ
      await _checkAndSaveExtractedDatabase(path.dirname(zipFilePath), emit);
    } catch (e) {
      emit(_error(
        errorMessage:
            'empty_library.bloc.generic_error'.tr(namedArgs: {'error': '$e'}),
      ));
    }
  }

  Future<void> _checkAndSaveExtractedDatabase(
      String extractedDirectory, Emitter<EmptyLibraryState> emit) async {
    try {
      // חיפוש קובץ seforim.db בתיקייה המחולצת
      final directory = Directory(extractedDirectory);
      final dbFiles = await directory
          .list(recursive: true)
          .where((entity) =>
              entity is File &&
              entity.path
                  .toLowerCase()
                  .endsWith(DatabaseConstants.databaseFileName))
          .cast<File>()
          .toList();

      if (dbFiles.isEmpty) {
        emit(_error(
          errorMessage: 'empty_library.bloc.db_not_found_in_archive'.tr(
              namedArgs: {'dbName': DatabaseConstants.databaseFileName}),
          selectedPath: extractedDirectory,
        ));
        return;
      }

      final dbPath = dbFiles.first.path;
      final rootPath = path.dirname(dbPath);

      await Settings.setValue(SettingsRepository.keyLibraryPath, rootPath);
      await Settings.setValue(SettingsRepository.keyLibraryFolderName, '');
      // ניקוי override Android — ה-DB החדש נמצא ישירות בספרייה
      await Settings.setValue(SettingsRepository.keyDbEffectivePath, '');

      emit(EmptyLibraryDirectorySelected(selectedPath: rootPath));
    } catch (e) {
      emit(_error(
        errorMessage:
            'empty_library.bloc.generic_error'.tr(namedArgs: {'error': '$e'}),
      ));
    }
  }

  Future<void> _onDownloadLibraryRequested(
      DownloadLibraryRequested event, Emitter<EmptyLibraryState> emit) async {
    try {
      final libraryPath =
          _defaultLibraryPathOverride ?? await AppPaths.getDefaultLibraryPath();
      final latestAsset = await _fetchLatestDatabaseAsset();

      // שלושת הקבצים מורדים יחד ואז מחולצים יחד. פס ההתקדמות בשני השלבים
      // מתייחס לסכום שלושתם; רק כותרת המשנה משתנה לפי הקובץ הנוכחי.
      final assets = <_DownloadAsset>[
        _DownloadAsset(
          url: latestAsset.downloadUrl,
          tempFileName: 'otzaria_${latestAsset.assetName}',
          downloadTitle: 'מוריד את ספריית אוצריא',
          extractTitle: 'מחלץ את ספריית אוצריא',
          isTar: false,
          outputFileName: DatabaseConstants.databaseFileName,
          isMainDb: true,
        ),
        _DownloadAsset(
          url:
              'https://github.com/Otzaria/otzaria-library/releases/latest/download/talmud_bavli_latest.tar.zst',
          tempFileName: 'otzaria_talmud_bavli.tar.zst',
          downloadTitle: 'מוריד את התלמוד הבבלי',
          extractTitle: 'מחלץ את התלמוד הבבלי',
          isTar: true,
        ),
        _DownloadAsset(
          url:
              'https://github.com/Otzaria/otzar-HB_catalog/releases/latest/download/otzar-HB_catalog.db.zst',
          tempFileName: 'otzaria_otzar-HB_catalog.db.zst',
          downloadTitle: 'מוריד את הקטלוגים',
          extractTitle: 'מחלץ את הקטלוגים',
          isTar: false,
          outputFileName: DatabaseConstants.externalCatalogDatabaseFileName,
        ),
      ];

      emit(EmptyLibraryDownloading(
        progress: 0.0,
        message: 'empty_library.bloc.connecting_to_server'.tr(),
      ));

      // פתרון redirect-ים מראש (package:http מאבד את ה-Range בעת redirect) +
      // קריאת גודל כל קובץ דחוס, לחישוב פס התקדמות וזמן משוער מאוחדים.
      for (final asset in assets) {
        final resolved = await _resolveRedirectWithSize(asset.url);
        asset.resolvedUrl = resolved.url;
        asset.compressedSize = resolved.size;
      }
      final grandTotal =
          assets.fold<int>(0, (sum, a) => sum + a.compressedSize);

      // בדיקת מקום פנוי מול הסכום הדחוס האמיתי של שלושת הקבצים (במקום
      // אומדן קבוע). גם safety net למצב שהדיסק התמלא אחרי טעינת המסך.
      final spaceError = await _checkSpaceForDownload(
          downloadSize: grandTotal > 0 ? grandTotal : null);
      if (spaceError != null) {
        _downloadDisabledReason = spaceError;
        emit(_error(errorMessage: spaceError));
        return;
      }

      // יצירת תיקיית הספרייה אם לא קיימת
      final libraryDir = Directory(libraryPath);
      if (!await libraryDir.exists()) {
        await libraryDir.create(recursive: true);
      }

      // שלב 1 — הורדת שלושת הקבצים יחד (פס וזמן משוער מאוחדים)
      final etaEstimator = DownloadEtaEstimator();
      var downloadedBase = 0;
      for (final asset in assets) {
        await _downloadAsset(
          asset: asset,
          cumulativeBase: downloadedBase,
          grandTotal: grandTotal,
          estimator: etaEstimator,
          emit: emit,
        );
        downloadedBase += asset.compressedSize;
      }

      // שלב 2 — חילוץ שלושת הקבצים יחד (פס מאוחד, משוקלל לפי הגודל הדחוס)
      var extractBase = 0;
      for (final asset in assets) {
        await _extractAsset(
          asset: asset,
          weightBase: extractBase,
          totalWeight: grandTotal,
          outputDir: libraryPath,
          emit: emit,
        );
        extractBase += asset.compressedSize;
      }

      emit(EmptyLibraryExtracting(
        selectedPath: '',
        progress: 1.0,
        message: 'empty_library.bloc.extraction_complete'.tr(),
      ));

      await Settings.setValue(SettingsRepository.keyLibraryPath, libraryPath);
      await Settings.setValue(SettingsRepository.keyLibraryFolderName, '');
      // ניקוי override Android — ה-DB החדש נמצא ישירות בספרייה
      await Settings.setValue(SettingsRepository.keyDbEffectivePath, '');

      emit(EmptyLibraryDirectorySelected(selectedPath: libraryPath));
    } catch (e) {
      // קבצי ה-temp נשמרים בכוונה — ישמשו ל-resume בניסיון הבא
      emit(EmptyLibraryError(
        errorMessage: 'empty_library.bloc.download_error_resumable'
            .tr(namedArgs: {'error': '$e'}),
      ));
    }
  }

  Future<void> _onDeleteZipAnswered(
      DeleteZipAnswered event, Emitter<EmptyLibraryState> emit) async {
    try {
      if (event.shouldDelete) {
        final zipFile = File(event.zipPath);
        if (await zipFile.exists()) {
          await zipFile.delete();
        }
      }

      // המשך לבדיקת הקובץ המחולץ
      await _checkAndSaveExtractedDatabase(event.extractedPath, emit);
    } catch (e) {
      emit(_error(
        errorMessage:
            'empty_library.bloc.generic_error'.tr(namedArgs: {'error': '$e'}),
      ));
    }
  }

  /// מוריד קובץ דחוס יחיד (עם resume) ומדווח התקדמות מאוחדת על פני כל
  /// הקבצים: [cumulativeBase] = סכום הגדלים הדחוסים של הקבצים שכבר הורדו
  /// במלואם, [grandTotal] = סך הגדלים הדחוסים של כל הקבצים.
  Future<void> _downloadAsset({
    required _DownloadAsset asset,
    required int cumulativeBase,
    required int grandTotal,
    required DownloadEtaEstimator estimator,
    required Emitter<EmptyLibraryState> emit,
  }) async {
    final tempPath = path.join(Directory.systemTemp.path, asset.tempFileName);
    final tempFile = File(tempPath);

    var alreadyDownloaded =
        await tempFile.exists() ? await tempFile.length() : 0;

    // הקובץ כבר הורד במלואו משריד ניסיון קודם — מדלגים על ההורדה.
    if (asset.compressedSize > 0 && alreadyDownloaded >= asset.compressedSize) {
      return;
    }

    // מדווח התקדמות מאוחדת לפי הבייטים שהורדו עד כה בקובץ הנוכחי.
    void emitProgress(int downloadedBytes) {
      if (grandTotal <= 0) {
        emit(EmptyLibraryDownloading(
            progress: 0.0, message: asset.downloadTitle));
        return;
      }
      final cumulative = cumulativeBase + downloadedBytes;
      final mb = (cumulative / 1024 / 1024).toStringAsFixed(1);
      final totalMb = (grandTotal / 1024 / 1024).toStringAsFixed(1);
      final eta = estimator.update(
        downloadedBytes: cumulative,
        totalBytes: grandTotal,
        now: DateTime.now(),
      );
      final etaLine = eta != null ? '\n${formatRemainingTimeHebrew(eta)}' : '';
      emit(EmptyLibraryDownloading(
        progress: (cumulative / grandTotal).clamp(0.0, 1.0),
        message: '${asset.downloadTitle}\n$mb MB מתוך $totalMb MB$etaLine',
      ));
    }

    final request = http.Request('GET', Uri.parse(asset.resolvedUrl!));
    if (alreadyDownloaded > 0) {
      request.headers['Range'] = 'bytes=$alreadyDownloaded-';
    }
    final response = await _httpClient.send(request);

    if (response.statusCode == 416) {
      // Range Not Satisfiable — הקובץ כבר שלם.
      return;
    } else if (response.statusCode == 200) {
      // השרת לא תומך ב-Range — מתחילים מחדש.
      alreadyDownloaded = 0;
      await tempFile.delete().catchError((_) => tempFile);
    } else if (response.statusCode == 206) {
      final contentRange = response.headers['content-range'];
      if (contentRange != null) {
        final match = RegExp(r'bytes (\d+)-').firstMatch(contentRange);
        if (match != null) {
          final serverStart = int.tryParse(match.group(1)!) ?? 0;
          if (serverStart == 0 && alreadyDownloaded > 0) {
            // השרת התחיל מ-0 למרות הבקשה — מחיקת הקובץ החלקי.
            alreadyDownloaded = 0;
            await tempFile.delete().catchError((_) => tempFile);
          } else {
            // וידוא שה-offset תואם למה שהשרת אישר.
            alreadyDownloaded = serverStart;
          }
        }
      }
    } else {
      // שגיאת HTTP — זורקים כדי שהמשתמש יידע.
      throw Exception('empty_library.bloc.asset_download_error'.tr(namedArgs: {
        'status': asset.downloadTitle,
        'code': '${response.statusCode}',
      }));
    }

    var downloadedBytes = alreadyDownloaded;
    emitProgress(downloadedBytes);

    final sink = tempFile.openWrite(
      mode: alreadyDownloaded > 0 ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        emitProgress(downloadedBytes);
      }
    } finally {
      await sink.close();
    }
  }

  /// מחלץ קובץ דחוס יחיד ומדווח התקדמות מאוחדת, משוקללת לפי הגודל הדחוס
  /// ([weightBase] = סכום הגדלים של הקבצים שכבר חולצו, [totalWeight] = סך
  /// הכול). החילוץ מדווח לפי בייטים דחוסים שנקראו, ולכן שקלול לפי הגודל
  /// הדחוס נותן פס התקדמות לינארי ומדויק על פני שלושת הקבצים.
  Future<void> _extractAsset({
    required _DownloadAsset asset,
    required int weightBase,
    required int totalWeight,
    required String outputDir,
    required Emitter<EmptyLibraryState> emit,
  }) async {
    final tempPath = path.join(Directory.systemTemp.path, asset.tempFileName);

    void report(double assetProgress) {
      final combined = totalWeight > 0
          ? ((weightBase + asset.compressedSize * assetProgress) / totalWeight)
              .clamp(0.0, 1.0)
          : assetProgress;
      emit(EmptyLibraryExtracting(
        selectedPath: tempPath,
        progress: combined,
        message: asset.extractTitle,
      ));
    }

    report(0.0);

    if (asset.isTar) {
      await _extractTarArchive(tempPath, outputDir, report);
    } else {
      final outputPath = path.join(outputDir, asset.outputFileName!);

      if (asset.isMainDb) {
        // SqliteDataProvider פותח את seforim.db ב-WAL בעלייה אם הקובץ קיים —
        // גם אם הוא חלקי/פגום משריד הורדה קודמת. הסגירה משחררת את ה-handle
        // לדריסה, ומחיקת shm/wal מונעת מ-SQLite לקרוא WAL ישן ולבלבל את
        // ה-DB החדש.
        await SqliteDataProvider.instance.dispose();
        for (final suffix in const ['', '-shm', '-wal', '-journal']) {
          final f = File('$outputPath$suffix');
          if (await f.exists()) {
            try {
              await f.delete();
            } catch (_) {
              // הסטרימינג יטפל בשארית — אם המחיקה כשלה גם כאן, השגיאה
              // האמיתית תעלה משם עם הודעה ברורה יותר.
            }
          }
        }
      }

      await _extractCompressedDatabase(tempPath, outputPath, report);
    }

    // מחיקת קובץ ה-temp לאחר חילוץ מוצלח.
    await File(tempPath).delete().catchError((_) => File(tempPath));
  }

  /// מחלץ קובץ tar.zst לתיקיית היעד בזרימה נמוכת-זיכרון:
  /// 1. חילוץ ה-zst לקובץ tar זמני דרך ZSTD streaming (ב-isolet, עם דיווח
  ///    התקדמות). מחליף את `Zstandard().decompress` שטען את כל ה-tar ל-RAM
  ///    וגרם ללחץ זיכרון/קפיאות על מכשירים חלשים.
  /// 2. חילוץ ה-tar מהדיסק עם `extractFileToDisk` שקורא בזרימה מהקובץ.
  static Future<void> _extractTarZst(String archivePath, String outputDir,
      void Function(double progress)? onProgress) async {
    final tarPath = '$archivePath.tar';
    await _runWithProgress(
      onProgress,
      (port) => _decompressZstInIsolate(archivePath, tarPath, port),
    );
    try {
      await extractFileToDisk(tarPath, outputDir);
    } finally {
      await File(tarPath).delete().catchError((_) => File(tarPath));
    }
  }

  /// עוקב אחרי redirects ידנית ומחזיר את ה-URL הסופי ואת גודל הקובץ
  /// (Content-Length). נדרש כי package:http מאבד את ה-Range header בעת
  /// redirect; הגודל משמש לחישוב פס התקדמות וזמן משוער מאוחדים.
  /// מחזיר size=0 אם השרת לא סיפק Content-Length.
  Future<({String url, int size})> _resolveRedirectWithSize(String url) async {
    var current = Uri.parse(url);
    var size = 0;
    for (var i = 0; i < 5; i++) {
      final request = http.Request('HEAD', current)..followRedirects = false;
      final response = await _httpClient.send(request);
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers['location'];
        if (location == null) break;
        // תמיכה ב-Location יחסי
        current = current.resolve(location);
      } else {
        size = response.contentLength ?? 0;
        break;
      }
    }
    return (url: current.toString(), size: size);
  }

  Future<DatabaseReleaseAsset> _fetchLatestDatabaseAsset() async {
    final response = await _httpClient.get(
      Uri.parse(
        'https://api.github.com/repos/Otzaria/SeforimLibrary/releases/latest',
      ),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('empty_library.bloc.github_release_fetch_error'
          .tr(namedArgs: {'status': '${response.statusCode}'}));
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('empty_library.bloc.github_response_invalid'.tr());
    }

    final asset = parseLatestDatabaseAsset(decoded);
    if (asset == null) {
      throw Exception('empty_library.bloc.db_asset_not_found'.tr());
    }

    return asset;
  }

  @visibleForTesting

  /// מחלץ מתוך JSON של רליס את קובץ ה-DB הדחוס של הספרייה.
  static DatabaseReleaseAsset? parseLatestDatabaseAsset(
      Map<String, dynamic> releaseJson) {
    final assets = releaseJson['assets'];
    if (assets is! List) {
      return null;
    }

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) {
        continue;
      }

      final name = asset['name']?.toString() ?? '';
      final downloadUrl = asset['browser_download_url']?.toString() ?? '';
      if (name == 'seforim.db.zst' && downloadUrl.isNotEmpty) {
        return DatabaseReleaseAsset(
          assetName: name,
          downloadUrl: downloadUrl,
        );
      }
    }

    return null;
  }

  static Future<void> _extractZstWithSystemProcess(
    String archivePath,
    String outputPath,
    void Function(double progress)? onProgress,
  ) async {
    // חילוץ streaming על כל הפלטפורמות. ה-DB הדחוס של הספרייה הוא
    // 1.5 GB דחוס ו-6.5 GB פרוס; טעינה לזיכרון RAM ב-`Zstandard().decompress`
    // קרסה ב-Microsoft Store certification על Surface Laptop 5 עם 8 GB RAM
    // (FAST_FAIL 0xc0000409 בעת ההרצה של שלב "הורדת ספרייה"). שימוש ב-
    // ZSTD_decompressStream דרך FFI מעבד נתחים של ~128 KB ולא חורג מ-
    // כמה מאות KB של RAM. רץ ב-isolate נפרד כדי לא לחסום את ה-UI.
    await _runWithProgress(
      onProgress,
      (port) => _decompressZstInIsolate(archivePath, outputPath, port),
    );
  }

  /// מריץ את חילוץ ה-ZST streaming ב-isolet נפרד.
  ///
  /// מבודד בפונקציה עצמאית כדי שה-closure שנשלח ל-[Isolate.run] ילכוד
  /// **רק** ערכים שליחים (מחרוזות + [SendPort]). אם ה-closure היה נוצר
  /// באותו scope של ה-`ReceivePort`/ה-`onProgress`, Dart היה מנסה לשלוח
  /// גם אותם — והם בלתי-שליחים (object is unsendable).
  static Future<void> _decompressZstInIsolate(
    String archivePath,
    String outputPath,
    SendPort progressPort,
  ) {
    return Isolate.run(
      () => _decompressZstStreaming(archivePath, outputPath, progressPort),
    );
  }

  /// מאזין לעדכוני התקדמות מ-isolet ומעביר אותם ל-UI.
  ///
  /// [runInIsolate] נקראת **מקומית** (לא נשלחת ל-isolet); היא עצמה אחראית
  /// להפעיל את [Isolate.run]. ה-isolet שולח ערכי `double` (0.0–1.0) דרך
  /// ה-[SendPort]; [Isolate.run] מטפל בהשלמה ובהפצת שגיאות.
  static Future<void> _runWithProgress(
    void Function(double progress)? onProgress,
    Future<void> Function(SendPort progressPort) runInIsolate,
  ) async {
    final progressPort = ReceivePort();
    final sub = progressPort.listen((message) {
      if (message is double) onProgress?.call(message);
    });
    try {
      await runInIsolate(progressPort.sendPort);
    } finally {
      await sub.cancel();
      progressPort.close();
    }
  }

  /// מחזיר את ה-DynamicLibrary של zstandard לפלטפורמה הנוכחית.
  ///
  /// כל פלאגין פלטפורמה של `zstandard` בונה DLL/dylib/SO עם זרות שונה;
  /// השמות תואמים את `zstandard_<platform>` package.
  static DynamicLibrary _openZstandardLib() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libzstandard_android.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('zstandard_windows.dll');
    }
    if (Platform.isLinux) {
      return DynamicLibrary.open('libzstandard_linux_plugin.so');
    }
    if (Platform.isMacOS) {
      return DynamicLibrary.open('zstandard_macos.framework/zstandard_macos');
    }
    if (Platform.isIOS) {
      return DynamicLibrary.open('zstandard_ios.framework/zstandard_ios');
    }
    throw UnsupportedError(
        'Platform not supported: ${Platform.operatingSystem}');
  }

  /// חילוץ ZST streaming דרך ZSTD FFI — רץ ב-isolate נפרד.
  /// מעבד את הקובץ בנתחים של ~128 KB ישירות לדיסק.
  /// שימוש ב-RAM: כמה מאות KB בלבד (במקום ~8 GB).
  static void _decompressZstStreaming(String archivePath, String outputPath,
      [SendPort? progressPort]) {
    try {
      _decompressZstStreamingInner(archivePath, outputPath, progressPort);
    } catch (_) {
      // בכשל (קובץ קטוע, דיסק מלא וכו') מוחקים את קובץ הפלט החלקי. אחרת
      // הוא נשאר בתיקיית הספרייה, ובעלייה הבאה SqliteDataProvider מנסה
      // לפתוח DB חתוך ונכשל ב"database disk image is malformed" — מה שחוסם
      // את האפליקציה במקום להחזיר אותה למסך בחירת/הורדת הספרייה.
      try {
        final partial = File(outputPath);
        if (partial.existsSync()) partial.deleteSync();
      } catch (_) {}
      rethrow;
    }
  }

  static void _decompressZstStreamingInner(
      String archivePath, String outputPath,
      [SendPort? progressPort]) {
    final dylib = _openZstandardLib();
    final bindings = ZstandardNativeBindings(dylib);

    final inBufSize = bindings.ZSTD_DStreamInSize();
    final outBufSize = bindings.ZSTD_DStreamOutSize();

    final dStream = bindings.ZSTD_createDStream();
    if (dStream == nullptr) throw Exception('ZSTD_createDStream נכשל');

    // ממיר קוד שגיאה גולמי של ZSTD לתיאור טקסטואלי קריא (למשל קוד 16 →
    // "Frame requires too much memory for decoding").
    String zstdError(int code) =>
        bindings.ZSTD_getErrorName(code).cast<Utf8>().toDartString();

    try {
      final initRet = bindings.ZSTD_initDStream(dStream);
      if (bindings.ZSTD_isError(initRet) != 0) {
        throw Exception('ZSTD_initDStream נכשל: ${zstdError(initRet)}');
      }

      // ברירת המחדל של ה-streaming decompressor מגבילה את חלון הדחיסה ל-
      // 128MB (windowLog=27). קובץ ה-seforim.db.zst נדחס עם `--long` ולכן
      // נכשל עם ZSTD_error_frameParameter_windowTooLarge (קוד 16). 31 =
      // חלון עד 2GB, המקסימום הסטנדרטי של zstd. אין לזה השפעה על שימוש
      // RAM בפועל — זו רק תקרה שמתירה לדקומפרסור להתאים את עצמו לחלון.
      final paramRet = bindings.ZSTD_DCtx_setParameter(
          dStream, ZSTD_dParameter.ZSTD_d_windowLogMax, 31);
      if (bindings.ZSTD_isError(paramRet) != 0) {
        throw Exception(
            'ZSTD_DCtx_setParameter(windowLogMax) נכשל: ${zstdError(paramRet)}');
      }

      final inNative = malloc.allocate<Uint8>(inBufSize);
      final outNative = malloc.allocate<Uint8>(outBufSize);
      final inBuf = malloc<ZSTD_inBuffer_s>();
      final outBuf = malloc<ZSTD_outBuffer_s>();

      try {
        final inputRaf = File(archivePath).openSync();
        final outFile = File(outputPath);
        if (outFile.existsSync()) outFile.deleteSync();
        final outputRaf = outFile.openSync(mode: FileMode.writeOnly);

        // גודל הקובץ הדחוס משמש בסיס לחישוב התקדמות. ZSTD קורא את הקלט
        // באופן ליניארי, ולכן "בייטים שנקראו / סך הבייטים" הוא קירוב טוב.
        final totalBytes = inputRaf.lengthSync();
        var totalRead = 0;
        var lastReported = 0.0;

        try {
          final inView = inNative.asTypedList(inBufSize);

          // 0 = frame הושלם, >0 = עדיין נתונים בממתנה, <0 = שגיאה
          int lastRet = 0;
          // הגודל הלא-דחוס המוצהר ב-frame header (Frame_Content_Size).
          // -1 (ZSTD_CONTENTSIZE_UNKNOWN) או -2 (ERROR) אם לא ניתן לקבוע.
          int expectedSize = -1;
          int totalWritten = 0;
          var headerParsed = false;

          while (true) {
            final bytesRead = inputRaf.readIntoSync(inView);
            if (bytesRead == 0) break;
            totalRead += bytesRead;

            // קריאת Frame_Content_Size מתוך תחילת ה-frame (פעם אחת).
            if (!headerParsed) {
              expectedSize =
                  bindings.ZSTD_getFrameContentSize(inNative.cast(), bytesRead);
              headerParsed = true;
            }

            inBuf.ref.src = inNative.cast();
            inBuf.ref.size = bytesRead;
            inBuf.ref.pos = 0;

            while (inBuf.ref.pos < inBuf.ref.size) {
              outBuf.ref.dst = outNative.cast();
              outBuf.ref.size = outBufSize;
              outBuf.ref.pos = 0;

              lastRet = bindings.ZSTD_decompressStream(dStream, outBuf, inBuf);

              if (bindings.ZSTD_isError(lastRet) != 0) {
                throw Exception(
                    'שגיאת ZSTD בחילוץ: ${zstdError(lastRet)} (קוד: $lastRet)');
              }

              if (outBuf.ref.pos > 0) {
                outputRaf.writeFromSync(outNative.asTypedList(outBuf.ref.pos));
                totalWritten += outBuf.ref.pos;
              }
            }

            // דיווח התקדמות — רק כשהשתנתה ב-1% לפחות, כדי לא להציף את ה-UI
            if (progressPort != null && totalBytes > 0) {
              final progress = totalRead / totalBytes;
              if (progress - lastReported >= 0.01) {
                lastReported = progress;
                progressPort.send(progress);
              }
            }
          }

          // לפי תיעוד ZSTD: ערך חזרה > 0 אחרי EOF = frame לא הושלם (קובץ קטוע/פגום)
          if (lastRet != 0) {
            throw Exception(
              'קובץ ה-ZST קטוע או פגום: ה-frame לא הושלם (נותרו $lastRet bytes לפענוח)',
            );
          }

          // flush מפורש כדי לאלץ כתיבה בפועל לדיסק. בלעדיו כתיבה דרך page
          // cache עלולה "להצליח" ב-writeFromSync ולהיכשל בשקט מאוחר יותר על
          // דיסק מלא (ENOSPC), ולהשאיר קובץ חתוך.
          outputRaf.flushSync();

          // אימות שלמות: גודל הפלט חייב להיות זהה לגודל המוצהר ב-frame.
          // תופס דיסק מלא (ENOSPC) שנבלע ב-page cache והשאיר קובץ חתוך —
          // התסמין שהוביל ל"database disk image is malformed" בעת הטעינה.
          // expectedSize < 0 = הגודל לא הוצהר ב-frame; אז אין מה לאמת.
          if (expectedSize >= 0 && totalWritten != expectedSize) {
            throw Exception(
              'החילוץ לא הושלם: נכתבו $totalWritten מתוך $expectedSize bytes. '
              'ככל הנראה אזל מקום האחסון.',
            );
          }
        } finally {
          inputRaf.closeSync();
          outputRaf.closeSync();
        }
      } finally {
        malloc.free(inNative);
        malloc.free(outNative);
        malloc.free(inBuf);
        malloc.free(outBuf);
      }
    } finally {
      bindings.ZSTD_freeDStream(dStream);
    }
  }

  @override
  Future<void> close() {
    HttpClientRegistry.unregister(_httpClient.close);
    _httpClient.close();
    return super.close();
  }
}

/// תוצאת קריאת df עבור נתיב נתון.
class _DfInfo {
  const _DfInfo({required this.filesystem, required this.freeBytes});
  final String? filesystem;
  final int freeBytes;
}

/// מתאר קובץ דחוס יחיד בחבילת ההורדה הראשונית (ספרייה / תלמוד / קטלוגים).
/// שלושת הקבצים מורדים יחד ואז מחולצים יחד, עם פס התקדמות מאוחד.
class _DownloadAsset {
  _DownloadAsset({
    required this.url,
    required this.tempFileName,
    required this.downloadTitle,
    required this.extractTitle,
    required this.isTar,
    this.outputFileName,
    this.isMainDb = false,
  });

  /// כתובת ההורדה (לפני פתרון redirect).
  final String url;

  /// שם קובץ ה-temp הקבוע (נשמר בין ניסיונות לצורך resume).
  final String tempFileName;

  /// כותרת המשנה המוצגת בזמן ההורדה.
  final String downloadTitle;

  /// כותרת המשנה המוצגת בזמן החילוץ.
  final String extractTitle;

  /// `true` → tar.zst שמחולץ לתיקיית היעד. `false` → .zst לקובץ יחיד.
  final bool isTar;

  /// שם קובץ היעד לחילוץ (נדרש כש-[isTar] = false).
  final String? outputFileName;

  /// האם זהו seforim.db הראשי — דורש סגירת SqliteDataProvider ומחיקת
  /// קבצי WAL/SHM ישנים לפני החילוץ.
  final bool isMainDb;

  /// ה-URL הסופי לאחר פתרון redirect (נקבע בזמן ריצה).
  String? resolvedUrl;

  /// גודל הקובץ הדחוס בבייטים (נקבע בזמן ריצה מ-Content-Length).
  int compressedSize = 0;
}

/// מייצג asset של DB דחוס מתוך GitHub Release.
class DatabaseReleaseAsset {
  const DatabaseReleaseAsset({
    required this.assetName,
    required this.downloadUrl,
  });

  final String assetName;
  final String downloadUrl;
}
