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
    on<PickDirectoryRequested>(_onPickDirectoryRequested);
    on<PickDirectoryWithZipRequested>(_onPickDirectoryWithZipRequested);
    on<DownloadLibraryRequested>(_onDownloadLibraryRequested);
    on<DeleteZipAnswered>(_onDeleteZipAnswered);
  }

  Future<void> _onPickDirectoryRequested(
      PickDirectoryRequested event, Emitter<EmptyLibraryState> emit) async {
    // אם יש נתיב שהועבר, נשתמש בו (מהUI שכבר עשה חילוץ)
    // אחרת, נבקש מהמשתמש לבחור
    String? selectedDirectory = event.path;
    
    if (selectedDirectory == null) {
      selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        return;
      }
    }

    emit(EmptyLibraryLoading(selectedPath: selectedDirectory));

    // בדיקה שקובץ seforim.db קיים בתיקייה שנבחרה
    // נבדוק שני מקרים:
    // 1. המשתמש בחר תיקייה שמכילה את תיקיית "אוצריא" (למשל: C:\Library שמכילה C:\Library\אוצריא\seforim.db)
    // 2. המשתמש בחר ישירות את תיקיית "אוצריא" (למשל: C:\Library\אוצריא שמכילה seforim.db)

    String libraryPath;
    String folderName;

    // בדיקה אפשרות 1: התיקייה שנבחרה מכילה תיקייה בשם "אוצריא" עם seforim.db
    final databasePathWithOtzaria =
        DatabaseConstants.getDatabasePathForLibrary(selectedDirectory);
    final databaseFileWithOtzaria = File(databasePathWithOtzaria);

    // בדיקה אפשרות 2: התיקייה שנבחרה היא תיקייה עם seforim.db ישירות בתוכה
    final databasePathDirect =
        path.join(selectedDirectory, DatabaseConstants.databaseFileName);
    final databaseFileDirect = File(databasePathDirect);

    // בדיקה אפשרות 3: התיקייה שנבחרה היא תיקייה שמכילה תיקייה אחרת עם seforim.db
    final dirName = path.basename(selectedDirectory);
    final databasePathInSelectedDir =
        path.join(selectedDirectory, DatabaseConstants.databaseFileName);
    final databaseFileInSelectedDir = File(databasePathInSelectedDir);

    if (databaseFileWithOtzaria.existsSync()) {
      // אפשרות 1: נבחרה תיקייה שמכילה תיקייה בשם "אוצריא" עם seforim.db
      libraryPath = selectedDirectory;
      folderName = DatabaseConstants.otzariaFolderName;
    } else if (databaseFileDirect.existsSync()) {
      // אפשרות 2: נבחרה ישירות תיקייה שיש בה seforim.db
      libraryPath = path.dirname(selectedDirectory);
      folderName = dirName;
    } else if (databaseFileInSelectedDir.existsSync()) {
      // אפשרות 3: התיקייה שנבחרה מכילה seforim.db ישירות
      libraryPath = selectedDirectory;
      folderName = '';
    } else {
      emit(EmptyLibraryError(
        errorMessage: 'הקובץ ${DatabaseConstants.databaseFileName} לא נמצא.\n'
            'יש לבחור את התיקייה המכילה את הקובץ ${DatabaseConstants.databaseFileName}.\n'
            'לדוגמה: C:\\אוצריא\\3אוצריא (אם seforim.db נמצא בתוכה)',
        selectedPath: selectedDirectory,
      ));
      return;
    }

    // שמירת הגדרות
    await Settings.setValue(SettingsRepository.keyLibraryFolderName, folderName);
    await Settings.setValue(SettingsRepository.keyLibraryPath, libraryPath);

    // שמירת הנתיב בהגדרות
    await Settings.setValue(SettingsRepository.keyLibraryPath, libraryPath);

    emit(EmptyLibraryDirectorySelected(selectedPath: libraryPath));
  }

  Future<void> _onPickDirectoryWithZipRequested(
      PickDirectoryWithZipRequested event, Emitter<EmptyLibraryState> emit) async {
    try {
      emit(const EmptyLibraryExtracting(
        selectedPath: '',
        progress: 0.0,
        message: 'מתחיל חילוץ...',
      ));

      // נמצא את קובץ ה-ZIP בתיקייה לפני החילוץ
      final directory = Directory(event.path);
      final zipFiles = await directory
          .list()
          .where((entity) =>
              entity is File && entity.path.toLowerCase().endsWith('.zip'))
          .cast<File>()
          .toList();
      
      final zipPath = zipFiles.isNotEmpty ? zipFiles.first.path : '';

      final extractionResult =
          await ZipExtractorService.checkAndExtractZipIfNeeded(
        event.path,
        onProgress: (p, m) {
          emit(EmptyLibraryExtracting(
            selectedPath: event.path,
            progress: p,
            message: m,
          ));
        },
        onAskDeleteZip: () async {
          // לא נמחק כאן - נשאל את המשתמש אחרי החילוץ
          return false;
        },
      );

      if (!extractionResult.success) {
        emit(EmptyLibraryError(
          errorMessage: extractionResult.errorMessage ?? 'שגיאה בחילוץ',
          zipFiles: extractionResult.zipFiles,
        ));
        return;
      }

      // אם החילוץ הצליח, נשאל את המשתמש אם למחוק את ה-ZIP
      if (extractionResult.successfullyExtracted && zipPath.isNotEmpty) {
        emit(EmptyLibraryAskingDeleteZip(
          zipPath: zipPath,
          extractedPath: event.path,
        ));
        // נעצור כאן - המשתמש יענה דרך אירוע DeleteZipAnswered
        return;
      }

      // אם לא היה חילוץ (אין ZIP), נמשיך ישירות לבדיקת הספרייה
      await _checkAndSaveLibraryPath(event.path, emit);
    } catch (e) {
      emit(EmptyLibraryError(
        errorMessage: 'שגיאה: $e',
      ));
    }
  }

  Future<void> _onDownloadLibraryRequested(
      DownloadLibraryRequested event, Emitter<EmptyLibraryState> emit) async {
    const url =
        'https://github.com/Otzaria/otzaria-library/releases/download/library-db-1/seforim.zip';

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

      await sink.close();

      // חילוץ הקובץ
      emit(const EmptyLibraryExtracting(
        selectedPath: '',
        progress: 0.0,
        message: 'מתחיל חילוץ...',
      ));

      final extractionResult =
          await ZipExtractorService.checkAndExtractZipIfNeeded(
        otzariaDir.path,
        onProgress: (p, m) {
          emit(EmptyLibraryExtracting(
            selectedPath: otzariaDir.path,
            progress: p,
            message: m,
          ));
        },
        onAskDeleteZip: () async {
          // לא נמחק כאן - נשאל את המשתמש אחרי החילוץ
          return false;
        },
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
          zipPath: zipPath,
          extractedPath: otzariaDir.path, // נשמור את נתיב תיקיית אוצריא
        ));
        // נעצור כאן - המשתמש יענה דרך אירוע DeleteZipAnswered
        return;
      }

      // אם לא היה חילוץ, נמשיך ישירות לבדיקת הספרייה
      await _checkAndSaveLibraryPath(otzariaDir.path, emit);
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

      // המשך לבדיקת הספרייה
      await _checkAndSaveLibraryPath(event.extractedPath, emit);
    } catch (e) {
      emit(EmptyLibraryError(
        errorMessage: 'שגיאה: $e',
      ));
    }
  }

  Future<void> _checkAndSaveLibraryPath(
      String selectedDirectory, Emitter<EmptyLibraryState> emit) async {
    String libraryPath;
    String folderName;

    final databasePathWithOtzaria =
        DatabaseConstants.getDatabasePathForLibrary(selectedDirectory);
    final databaseFileWithOtzaria = File(databasePathWithOtzaria);

    final databasePathDirect =
        path.join(selectedDirectory, DatabaseConstants.databaseFileName);
    final databaseFileDirect = File(databasePathDirect);

    final dirName = path.basename(selectedDirectory);
    final databasePathInSelectedDir =
        path.join(selectedDirectory, DatabaseConstants.databaseFileName);
    final databaseFileInSelectedDir = File(databasePathInSelectedDir);

    if (databaseFileWithOtzaria.existsSync()) {
      // אפשרות 1: נבחרה תיקייה שמכילה תיקייה בשם "אוצריא" עם seforim.db
      libraryPath = selectedDirectory;
      folderName = DatabaseConstants.otzariaFolderName;
    } else if (databaseFileDirect.existsSync()) {
      // אפשרות 2: נבחרה ישירות תיקייה שיש בה seforim.db
      libraryPath = path.dirname(selectedDirectory);
      folderName = dirName;
    } else if (databaseFileInSelectedDir.existsSync()) {
      // אפשרות 3: התיקייה שנבחרה מכילה seforim.db ישירות
      libraryPath = selectedDirectory;
      folderName = '';
    } else {
      emit(EmptyLibraryError(
        errorMessage: 'הקובץ ${DatabaseConstants.databaseFileName} לא נמצא.\n'
            'יש לבחור את התיקייה המכילה את הקובץ ${DatabaseConstants.databaseFileName}.',
        selectedPath: selectedDirectory,
      ));
      return;
    }

    await Settings.setValue(SettingsRepository.keyLibraryFolderName, folderName);
    await Settings.setValue(SettingsRepository.keyLibraryPath, libraryPath);
    emit(EmptyLibraryDirectorySelected(selectedPath: libraryPath));
  }
}
