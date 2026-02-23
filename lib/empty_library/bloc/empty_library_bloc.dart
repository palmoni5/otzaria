import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/empty_library/bloc/empty_library_event.dart';
import 'package:otzaria/empty_library/bloc/empty_library_state.dart';
import 'package:otzaria/settings/settings_repository.dart';
import 'package:otzaria/utils/zip_extractor_service.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class EmptyLibraryBloc extends Bloc<EmptyLibraryEvent, EmptyLibraryState> {
  EmptyLibraryBloc() : super(EmptyLibraryInitial()) {
    on<PickDatabaseFileRequested>(_onPickDatabaseFileRequested);
    on<DownloadLibraryRequested>(_onDownloadLibraryRequested);
    on<DeleteZipAnswered>(_onDeleteZipAnswered);
  }

  Future<void> _onPickDatabaseFileRequested(
      PickDatabaseFileRequested event, Emitter<EmptyLibraryState> emit) async {
    String? selectedFile = event.filePath;

    if (selectedFile == null) {
      // FilePicker.getFilePath לא קיים, נשתמש בפתיחת תיקייה ובחירת קובץ
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'zip'],
        dialogTitle: 'בחר קובץ מסד נתונים (seforim.db) או קובץ ZIP',
      );
      
      if (result == null || result.files.isEmpty) {
        return;
      }
      
      selectedFile = result.files.first.path;
      if (selectedFile == null) {
        return;
      }
    }

    emit(EmptyLibraryLoading(selectedPath: selectedFile));

    // בדיקה אם הקובץ הוא ZIP
    if (selectedFile.toLowerCase().endsWith('.zip')) {
      await _handleZipFile(selectedFile, emit);
    } else if (selectedFile.toLowerCase().endsWith('.db')) {
      await _handleDatabaseFile(selectedFile, emit);
    } else {
      emit(EmptyLibraryError(
        errorMessage: 'סוג קובץ לא תומך. בחר קובץ .db או .zip',
        selectedPath: selectedFile,
      ));
    }
  }

  Future<void> _handleDatabaseFile(
      String dbFilePath, Emitter<EmptyLibraryState> emit) async {
    try {
      final dbFile = File(dbFilePath);
      if (!await dbFile.exists()) {
        emit(EmptyLibraryError(
          errorMessage: 'הקובץ לא קיים: $dbFilePath',
          selectedPath: dbFilePath,
        ));
        return;
      }

      // שמירת הגדרות - נשמור את נתיב הקובץ ישירות
      await Settings.setValue(SettingsRepository.keyLibraryPath, dbFilePath);
      await Settings.setValue(SettingsRepository.keyLibraryFolderName, '');

      emit(EmptyLibraryDirectorySelected(selectedPath: dbFilePath));
    } catch (e) {
      emit(EmptyLibraryError(
        errorMessage: 'שגיאה: $e',
        selectedPath: dbFilePath,
      ));
    }
  }

  Future<void> _handleZipFile(
      String zipFilePath, Emitter<EmptyLibraryState> emit) async {
    try {
      emit(const EmptyLibraryExtracting(
        selectedPath: '',
        progress: 0.0,
        message: 'מתחיל חילוץ...',
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
        emit(EmptyLibraryError(
          errorMessage: extractionResult.errorMessage ?? 'שגיאה בחילוץ',
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
      emit(EmptyLibraryError(
        errorMessage: 'שגיאה: $e',
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
              entity.path.toLowerCase().endsWith(DatabaseConstants.databaseFileName))
          .cast<File>()
          .toList();

      if (dbFiles.isEmpty) {
        emit(EmptyLibraryError(
          errorMessage: 'לא נמצא קובץ ${DatabaseConstants.databaseFileName} בקובץ ה-ZIP',
          selectedPath: extractedDirectory,
        ));
        return;
      }

      // שמירת הגדרות - נשמור את נתיב קובץ ה-DB
      final dbPath = dbFiles.first.path;
      await Settings.setValue(SettingsRepository.keyLibraryPath, dbPath);
      await Settings.setValue(SettingsRepository.keyLibraryFolderName, '');

      emit(EmptyLibraryDirectorySelected(selectedPath: dbPath));
    } catch (e) {
      emit(EmptyLibraryError(
        errorMessage: 'שגיאה: $e',
      ));
    }
  }

  Future<void> _onDownloadLibraryRequested(
      DownloadLibraryRequested event, Emitter<EmptyLibraryState> emit) async {
    const url =
        'https://github.com/Otzaria/otzaria-library/releases/download/library-db-1/seforim.db.zip';

    try {
      // קבלת תיקיית ההתקנה
      final executablePath = Platform.resolvedExecutable;
      final installDir = path.dirname(executablePath);
      final otzariaDir = Directory(path.join(installDir, 'אוצריא'));

      // יצירת תיקיית אוצריא אם לא קיימת
      if (!await otzariaDir.exists()) {
        await otzariaDir.create(recursive: true);
      }

      final zipPath = path.join(otzariaDir.path, 'seforim.zip');

      // הורדת הקובץ
      emit(const EmptyLibraryDownloading(
        progress: 0.0,
        message: 'מתחבר לשרת...',
      ));

      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        emit(EmptyLibraryError(
          errorMessage: 'שגיאה בהורדה: ${response.statusCode}',
        ));
        return;
      }

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;
      final file = File(zipPath);
      final sink = file.openWrite();

      try {
        await for (var chunk in response.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;

          if (contentLength > 0) {
            final progress = downloadedBytes / contentLength;
            final mb = (downloadedBytes / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (contentLength / 1024 / 1024).toStringAsFixed(1);
            emit(EmptyLibraryDownloading(
              progress: progress,
              message: 'מוריד... $mb MB מתוך $totalMb MB',
            ));
          }
        }
      } finally {
        await sink.close();
      }

      // חילוץ הקובץ
      emit(const EmptyLibraryExtracting(
        selectedPath: '',
        progress: 0.0,
        message: 'מתחיל חילוץ...',
      ));

      final extractResult =
          await ZipExtractorService.checkAndExtractZipIfNeeded(
        otzariaDir.path,
        onProgress: (p, m) {
          emit(EmptyLibraryExtracting(
            selectedPath: otzariaDir.path,
            progress: p,
            message: m,
          ));
        },
        onAskDeleteZip: () async => false,
      );

      if (!extractResult.success) {
        emit(EmptyLibraryError(
          errorMessage: extractResult.errorMessage ?? 'שגיאה בחילוץ',
          zipFiles: extractResult.zipFiles,
        ));
        return;
      }

      // אם החילוץ הצליח, נשאל את המשתמש אם למחוק את ה-ZIP
      if (extractResult.successfullyExtracted) {
        emit(EmptyLibraryAskingDeleteZip(
          zipPath: zipPath,
          extractedPath: otzariaDir.path,
        ));
        return;
      }

      // אם לא היה חילוץ, נמשיך ישירות לבדיקת הקובץ
      await _checkAndSaveExtractedDatabase(otzariaDir.path, emit);
    } catch (e) {
      emit(EmptyLibraryError(
        errorMessage: 'שגיאה בהורדה: $e',
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
      emit(EmptyLibraryError(
        errorMessage: 'שגיאה: $e',
      ));
    }
  }
}
