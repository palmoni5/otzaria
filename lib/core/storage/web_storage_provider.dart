import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'storage_provider.dart';

/// מימוש StorageProvider לפלטפורמת Web
/// משתמש ב-cache בזיכרון (מימוש פשוט)
/// הערה: בעתיד ניתן לשדרג ל-IndexedDB למימוש מתמשך
class WebStorageProvider implements StorageProvider {
  // בווב, נשתמש בנתיבים וירטואליים
  static const String _virtualRoot = '/otzaria';
  static const String _supportDir = '$_virtualRoot/support';
  static const String _documentsDir = '$_virtualRoot/documents';
  static const String _databasesDir = '$_virtualRoot/databases';
  
  // Cache for file data in memory (simple implementation)
  final Map<String, Uint8List> _fileCache = {};

  @override
  Future<String> getApplicationSupportDirectory() async {
    return _supportDir;
  }

  @override
  Future<String> getApplicationDocumentsDirectory() async {
    return _documentsDir;
  }

  @override
  Future<String?> getExternalStorageDirectory() async {
    return null;
  }

  @override
  Future<String> getDatabasesPath() async {
    return _databasesDir;
  }

  @override
  Future<bool> directoryExists(String path) async {
    return true;
  }

  @override
  Future<void> createDirectory(String path, {bool recursive = false}) async {
    // No-op in web
  }

  @override
  Future<String> readFileAsString(String path) async {
    final bytes = await readFileAsBytes(path);
    return utf8.decode(bytes);
  }

  @override
  Future<List<int>> readFileAsBytes(String path) async {
    if (_fileCache.containsKey(path)) {
      return _fileCache[path]!;
    }
    throw Exception('File not found: $path');
  }

  @override
  Future<void> writeFileAsString(String path, String content) async {
    final bytes = utf8.encode(content);
    await writeFileAsBytes(path, bytes);
  }

  @override
  Future<void> writeFileAsBytes(String path, List<int> bytes) async {
    _fileCache[path] = Uint8List.fromList(bytes);
  }

  @override
  Future<bool> fileExists(String path) async {
    return _fileCache.containsKey(path);
  }

  @override
  Future<void> deleteFile(String path) async {
    _fileCache.remove(path);
  }

  @override
  Future<void> deleteDirectory(String path, {bool recursive = false}) async {
    final keysToRemove = _fileCache.keys
        .where((key) => key.startsWith(path))
        .toList();
    for (final key in keysToRemove) {
      _fileCache.remove(key);
    }
  }

  @override
  Future<List<String>> listFiles(String path) async {
    return _fileCache.keys
        .where((key) => key.startsWith(path))
        .toList();
  }

  @override
  Future<List<String>> listDirectories(String path) async {
    final dirs = <String>{};
    for (final file in _fileCache.keys) {
      if (file.startsWith(path)) {
        final relativePath = file.substring(path.length);
        final parts = relativePath.split('/').where((p) => p.isNotEmpty).toList();
        if (parts.length > 1) {
          dirs.add('$path/${parts[0]}');
        }
      }
    }
    return dirs.toList();
  }
}
