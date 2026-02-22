import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:path/path.dart' as path;

/// Database configuration constants
class DatabaseConstants {
  /// The name of the main database file
  static const String databaseFileName = 'seforim.db';

  /// The default name of the Otzaria folder
  static const String otzariaFolderName = 'אוצריא';

  /// Gets the full database path based on the library path setting
  static String getDatabasePath() {
    final libraryPath = Settings.getValue<String>('key-library-path') ?? '.';
    return getDatabasePathForLibrary(libraryPath);
  }

  /// Gets the database path for a specific library path
  static String getDatabasePathForLibrary(String libraryPath, [String? folderName]) {
    final folder = folderName ?? Settings.getValue<String>('key-library-folder-name') ?? otzariaFolderName;
    
    // אם folderName ריק, זה אומר שה-seforim.db נמצא ישירות בנתיב
    if (folder.isEmpty) {
      return path.join(libraryPath, databaseFileName);
    }
    
    return path.join(libraryPath, folder, databaseFileName);
  }

  /// Private constructor to prevent instantiation
  DatabaseConstants._();
}
