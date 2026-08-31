import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:otzaria/core/app_paths.dart';

/// מידע על ה-release האחרון של קובץ הביוגרפיות.
class BiographiesRelease {
  /// תג ה-release (למשל `bio-20260831-113627`) — משמש לזיהוי גרסה מותקנת.
  final String tag;

  /// כתובת ההורדה הישירה של נכס `biographies.tsb`.
  final Uri downloadUrl;

  const BiographiesRelease({required this.tag, required this.downloadUrl});
}

/// מוריד את קובץ הביוגרפיות (`biographies.tsb`) מ-GitHub Releases של
/// `ta-shma-to-otzaria` אל תיקיית מסדי הנתונים, ומעדכן רק כשיש release חדש —
/// אותה תבנית כמו מילון המורפולוגיה (`lexical.db`).
///
/// כל הפעולות best-effort: בכשל רשת האזור ממשיך לעבוד עם הקובץ הקיים,
/// ובהיעדרו מוצגת הודעת "אין נתונים".
class BiographiesDownloader {
  /// נקודת ה-API של ה-release האחרון.
  static const String latestReleaseApi =
      'https://api.github.com/repos/Otzaria/ta-shma-to-otzaria/releases/latest';

  static const String _assetSuffix = '/biographies.tsb';

  final http.Client _client;
  final bool _ownsClient;
  final Future<String> Function() _destinationProvider;

  BiographiesDownloader({
    http.Client? client,
    Future<String> Function()? destinationProvider,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _destinationProvider =
           destinationProvider ?? AppPaths.getBiographiesPath;

  void dispose() {
    if (_ownsClient) _client.close();
  }

  /// נתיב הקובץ המקומי, קיים או לא.
  Future<String> destinationPath() => _destinationProvider();

  /// מוודא שהגרסה האחרונה מותקנת: מוריד רק אם חסר קובץ מקומי או שהתג
  /// השמור שונה מהתג של ה-release האחרון.
  ///
  /// מחזיר `true` אם בסוף הפעולה קיים קובץ מקומי (כולל קובץ ישן כשאין
  /// רשת). לעולם אינו זורק.
  Future<bool> ensureLatest({bool force = false}) async {
    final dest = await _destinationProvider();
    try {
      final release = await fetchLatestRelease();
      final installed = await installedTag();
      final hasFile = await File(dest).exists();
      if (!force && hasFile && installed == release.tag) return true;
      await _download(release, dest);
      await File(_versionPath(dest)).writeAsString(release.tag);
      return true;
    } catch (_) {
      return File(dest).exists();
    }
  }

  /// שולף את פרטי ה-release האחרון. זורק [Exception] בכשל.
  Future<BiographiesRelease> fetchLatestRelease() async {
    final response = await _client.get(
      Uri.parse(latestReleaseApi),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('GitHub API החזיר ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String?)?.trim();
    final assets = (json['assets'] as List?) ?? const [];
    String? url;
    for (final a in assets) {
      final candidate =
          (a as Map<String, dynamic>)['browser_download_url'] as String?;
      if (candidate != null && candidate.endsWith(_assetSuffix)) {
        url = candidate;
        break;
      }
    }
    if (tag == null || tag.isEmpty || url == null) {
      throw Exception('לא נמצא נכס biographies.tsb ב-release האחרון');
    }
    return BiographiesRelease(tag: tag, downloadUrl: Uri.parse(url));
  }

  /// התג המותקן כעת, או `null` אם אין.
  Future<String?> installedTag() async {
    final marker = File(_versionPath(await _destinationProvider()));
    if (!await marker.exists()) return null;
    final tag = (await marker.readAsString()).trim();
    return tag.isEmpty ? null : tag;
  }

  /// מוריד אל קובץ `.part` ומשנה שם אטומית, כדי שקובץ חלקי לא ייראה תקין.
  Future<void> _download(BiographiesRelease release, String dest) async {
    final response = await _client.get(release.downloadUrl);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('הורדת הביוגרפיות נכשלה (${response.statusCode})');
    }
    final outFile = File('$dest.part');
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(response.bodyBytes, flush: true);
    await outFile.rename(dest);
  }

  static String _versionPath(String dest) => '$dest.version';
}
