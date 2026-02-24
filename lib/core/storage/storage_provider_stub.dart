import 'storage_provider.dart';

/// Stub implementation - לא אמור להיקרא
class PlatformStorageProvider implements StorageProvider {
  @override
  Future<String> getApplicationSupportDirectory() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<String> getApplicationDocumentsDirectory() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<String?> getExternalStorageDirectory() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<String> getDatabasesPath() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<bool> directoryExists(String path) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> createDirectory(String path, {bool recursive = false}) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<String> readFileAsString(String path) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<List<int>> readFileAsBytes(String path) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> writeFileAsString(String path, String content) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> writeFileAsBytes(String path, List<int> bytes) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<bool> fileExists(String path) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> deleteFile(String path) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> deleteDirectory(String path, {bool recursive = false}) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<List<String>> listFiles(String path) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<List<String>> listDirectories(String path) async {
    throw UnsupportedError('Platform not supported');
  }
}

/// יוצר instance של StorageProvider המתאים לפלטפורמה
StorageProvider createStorageProvider() {
  return PlatformStorageProvider();
}
