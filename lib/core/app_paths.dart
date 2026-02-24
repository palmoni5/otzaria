import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/settings/settings_repository.dart';

/// Utility class for managing application paths.
/// Centralizes path construction logic to avoid duplication.
class AppPaths {
  /// Gets the main library path from settings. Defaults to 'C:/אוצריא' for Windows if not set.
  static Future<String> getLibraryPath() async {
    // Check existing library path setting
    final currentPath = Settings.getValue(SettingsRepository.keyLibraryPath);

    if (currentPath != null) {
      return currentPath;
    }

    // Determine default path based on platform
    String libraryPath;
    if (Platform.isIOS) {
      libraryPath = (await getApplicationDocumentsDirectory()).path;
    } else if (Platform.isAndroid) {
      try {
        libraryPath = (await getExternalStorageDirectory())?.path ??
            (await getApplicationDocumentsDirectory()).path;
      } catch (_) {
        libraryPath = (await getApplicationDocumentsDirectory()).path;
      }
    } else if (Platform.isWindows) {
      libraryPath = 'C:/אוצריא';
    } else {
      // Linux, macOS: use application support directory for consistency
      libraryPath = (await getApplicationSupportDirectory()).path;
    }

    await Settings.setValue(SettingsRepository.keyLibraryPath, libraryPath);
    return libraryPath;
  }

  /// Helper method to get the base directory path
  /// If library path points to a .db file, returns its parent directory
  /// Otherwise returns the library path itself
  static Future<String> _getBasePath() async {
    final libraryPath = await getLibraryPath();
    
    // אם הנתיב הוא קובץ DB, נשתמש בתיקייה שמכילה אותו
    if (libraryPath.toLowerCase().endsWith('.db')) {
      return p.dirname(libraryPath);
    }
    
    // אחרת, נשתמש בנתיב כרגיל
    return libraryPath;
  }

  /// Gets the search index path (library_path/index)
  /// If library path points to a .db file, uses its parent directory
  static Future<String> getIndexPath() async {
    final basePath = await _getBasePath();
    return p.join(basePath, 'index');
  }

  /// Gets the manifest file path (library_path/files_manifest.json)
  /// If library path points to a .db file, uses its parent directory
  static Future<String> getManifestPath() async {
    final basePath = await _getBasePath();
    return p.join(basePath, 'files_manifest.json');
  }

  /// Resolves the notes database path - for cross-platform compatibility
  static Future<String> resolveNotesDbPath(String fileName) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Windows, Linux, macOS: this will go into application support directory
      final support = await getApplicationSupportDirectory();
      final dbDir = Directory(p.join(support.path, 'databases'));
      if (!await dbDir.exists()) await dbDir.create(recursive: true);
      return p.join(dbDir.path, fileName);
    } else {
      // Mobile: the standard path for sqflite
      final dbs = await getDatabasesPath();
      final dbDir = Directory(dbs);
      if (!await dbDir.exists()) await dbDir.create(recursive: true);
      return p.join(dbs, fileName);
    }
  }

  /// Creates necessary directories for the application
  /// Note: Does NOT create the library path itself - only index directories
  /// The library path should be created by the user or during library download
  static Future<void> createNecessaryDirectories() async {
    // רק ניצור את תיקיות האינדקס, לא את תיקיית הספרייה עצמה
    // תיקיית הספרייה תיווצר רק כשמורידים ספרייה או כשהמשתמש בוחר תיקייה קיימת
    final libraryPath = await getLibraryPath();
    
    // בדיקה אם הנתיב הוא קובץ או תיקייה
    final isDbFile = libraryPath.toLowerCase().endsWith('.db');
    final checkPath = isDbFile ? p.dirname(libraryPath) : libraryPath;
    final checkDir = Directory(checkPath);

    // אם התיקייה לא קיימת, לא ניצור אותה
    // רק נוודא שתיקיות האינדקס קיימות אם התיקייה קיימת
    if (await checkDir.exists()) {
      final dirs = [
        await getIndexPath(),
      ];

      for (final dirPath in dirs) {
        final directory = Directory(dirPath);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      }
    }
  }
}
