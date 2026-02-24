import 'dart:io';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'storage_provider.dart';

/// מימוש StorageProvider לפלטפורמות Native (Desktop/Mobile)
/// משתמש ב-dart:io למערכת קבצים מקומית
class FileStorageProvider implements StorageProvider {
  @override
  Future<String> getApplicationSupportDirectory() async {
    final dir = await path_provider.getApplicationSupportDirectory();
    return dir.path;
  }

  @override
  Future<String> getApplicationDocumentsDirectory() async {
    final dir = await path_provider.getApplicationDocumentsDirectory();
    return dir.path;
  }

  @override
  Future<String?> getExternalStorageDirectory() async {
    if (Platform.isAndroid) {
      final dir = await path_provider.getExternalStorageDirectory();
      return dir?.path;
    }
    return null;
  }

  @override
  Future<String> getDatabasesPath() async {
    return await sqflite.getDatabasesPath();
  }

  @override
  Future<bool> directoryExists(String path) async {
    return await Directory(path).exists();
  }

  @override
  Future<void> createDirectory(String path, {bool recursive = false}) async {
    await Directory(path).create(recursive: recursive);
  }

  @override
  Future<String> readFileAsString(String path) async {
    return await File(path).readAsString();
  }

  @override
  Future<List<int>> readFileAsBytes(String path) async {
    return await File(path).readAsBytes();
  }

  @override
  Future<void> writeFileAsString(String path, String content) async {
    await File(path).writeAsString(content);
  }

  @override
  Future<void> writeFileAsBytes(String path, List<int> bytes) async {
    await File(path).writeAsBytes(bytes);
  }

  @override
  Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  @override
  Future<void> deleteFile(String path) async {
    await File(path).delete();
  }

  @override
  Future<void> deleteDirectory(String path, {bool recursive = false}) async {
    await Directory(path).delete(recursive: recursive);
  }

  @override
  Future<List<String>> listFiles(String path) async {
    final dir = Directory(path);
    final entities = await dir.list().toList();
    return entities
        .whereType<File>()
        .map((f) => f.path)
        .toList();
  }

  @override
  Future<List<String>> listDirectories(String path) async {
    final dir = Directory(path);
    final entities = await dir.list().toList();
    return entities
        .whereType<Directory>()
        .map((d) => d.path)
        .toList();
  }
}
