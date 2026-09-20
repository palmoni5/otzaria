import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// חותם השחרור שנארז לתוך תיקיית ההתקנה. חייב להישאר זהה ל-
/// `kInstalledReleaseFileName` של `tool/release/generate_app_file_manifest.dart`.
const String kInstalledReleaseFileName = 'otzaria-release.json';

/// גרסת הסכמה שהלקוח יודע לקרוא. גרסה גבוהה יותר נדחית.
const int kInstalledReleaseSchemaVersion = 1;

/// קורא את תג השחרור מהחותם שליד ה-executable. `null` = אין חותם מתאים,
/// והקורא חוזר למתקין המלא. [architecture] מונע חבילת x64 על התקנת ARM64.
String? readInstalledReleaseTag(
  Directory installRoot, {
  required String platform,
  required String architecture,
}) {
  try {
    final file = File(p.join(installRoot.path, kInstalledReleaseFileName));
    if (!file.existsSync()) return null;
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) return null;
    if (decoded['schemaVersion'] != kInstalledReleaseSchemaVersion) return null;
    if (decoded['platform'] != platform) return null;
    if (decoded['architecture'] != architecture) return null;
    final tag = decoded['releaseTag'];
    if (tag is! String || tag.trim().isEmpty) return null;
    return tag;
  } catch (_) {
    return null;
  }
}
