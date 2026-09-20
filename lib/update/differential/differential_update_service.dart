import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'update_engine.dart';
import 'update_package.dart';
import 'zstd_runner.dart';

/// המאגר שאליו CI מפרסם את חבילות העדכון. נפרד ממאגר אוצריא כדי לא להעמיס
/// את ה-release הראשי.
const String kUpdatePackagesRepository = 'palmoni5/otzaria';

const Duration _kApiTimeout = Duration(seconds: 15);

/// נכס אחד ב-release של מאגר החבילות.
class UpdatePackageAsset {
  const UpdatePackageAsset({
    required this.name,
    required this.url,
    required this.size,
  });

  final String name;
  final String url;
  final int size;
}

/// מוצא נכס לפי שמו המדויק. שם שאינו קיים = אין חבילה, ולא ניחוש.
UpdatePackageAsset? findUpdatePackageAsset(
  List<UpdatePackageAsset> assets,
  String name,
) {
  for (final asset in assets) {
    if (asset.name == name) return asset;
  }
  return null;
}

/// קורא את רשימת נכסי ה-release של [releaseTag] במאגר החבילות.
Future<List<UpdatePackageAsset>> fetchUpdatePackageAssets(
  String releaseTag, {
  http.Client? client,
  String repository = kUpdatePackagesRepository,
}) async {
  final owned = client == null;
  final http1 = client ?? http.Client();
  try {
    final response = await http1
        .get(
          Uri.parse(
            'https://api.github.com/repos/$repository/releases/tags/'
            '${Uri.encodeComponent(releaseTag)}',
          ),
        )
        .timeout(_kApiTimeout);
    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return const [];
    final assets = decoded['assets'];
    if (assets is! List) return const [];
    return [
      for (final asset in assets)
        if (asset is Map &&
            asset['name'] is String &&
            asset['browser_download_url'] is String)
          UpdatePackageAsset(
            name: asset['name'] as String,
            url: asset['browser_download_url'] as String,
            size: asset['size'] is int ? asset['size'] as int : 0,
          ),
    ];
  } finally {
    if (owned) http1.close();
  }
}

/// גודל הורדה בעברית פשוטה, לקריאה על מסך רגיל ("8 מגה-בייט").
String formatDownloadSizeHebrew(int bytes) {
  if (bytes < 1024 * 1024) {
    final kilobytes = (bytes / 1024).ceil();
    return '$kilobytes קילו-בייט';
  }
  final megabytes = bytes / (1024 * 1024);
  if (megabytes >= 10) return '${megabytes.round()} מגה-בייט';
  final rounded = (megabytes * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? '${rounded.round()}'
      : rounded.toStringAsFixed(1);
  return '$text מגה-בייט';
}

/// האם כדאי לנסות את המסלול הדיפרנציאלי. למעדכן העצמאי אין הסלמת הרשאות,
/// ולכן התקנת מנהל ([installRootWritable]=false) נשארת על המתקין המלא.
bool differentialUpdateSupported({
  required bool isWindows,
  required bool installRootWritable,
  required bool zstdAvailable,
  required bool hasUpdaterHelper,
}) => isWindows && installRootWritable && zstdAvailable && hasUpdaterHelper;

/// ארכיטקטורת הבנייה שרצה כעת. המעבד לבדו אינו קובע: בנייית x64 באמולציה
/// על מחשב ARM היא עדיין התקנת x64, וחבילת ARM64 אינה מתאימה לה.
String installedWindowsArchitecture({
  required bool isWindowsOnArm,
  required bool isEmulatedOnArm,
}) => isWindowsOnArm && !isEmulatedOnArm ? 'arm64' : 'x64';

/// האם אפשר לכתוב לתיקייה. נבדק בכתיבה בפועל ולא בהרשאות: ACL שמתיר
/// כתיבה אינו מבטיח שהקובץ ייכתב (Program Files עם וירטואליזציה).
bool isDirectoryWritable(Directory directory) {
  final probe = File(
    p.join(directory.path, '.otzaria-update-probe-${pid.toString()}'),
  );
  try {
    probe.writeAsStringSync('');
    probe.deleteSync();
    return true;
  } catch (_) {
    return false;
  }
}

/// עדכון דיפרנציאלי שהוכן במלואו: מה ירד בפועל, וה-staging המאומת.
class PreparedDifferentialUpdate {
  PreparedDifferentialUpdate({
    required this.staged,
    required this.downloadedBytes,
  });

  final StagedUpdate staged;

  /// סך הבתים שירדו בפועל — כולל חבילת הקבצים המלאים אם נדרשה.
  final int downloadedBytes;
}

/// מוריד קובץ ל-[target]. מוזרק כדי שבדיקות לא ייגשו לרשת.
/// [expectedSize] הוא הגודל שה-release מדווח, לאימות הורדה שנקטעה.
typedef PackageDownloader =
    Future<File> Function(String url, File target, {int? expectedSize});

/// איתור החבילה, הורדתה ובנייה מאומתת ב-staging. חבילת הקבצים המלאים
/// יורדת **רק** אם ערך כלשהו נכשל; כל כשל מחזיר למתקין המלא.
class DifferentialUpdateService {
  DifferentialUpdateService({
    required this.installRoot,
    required this.workRoot,
    required this.architecture,
    required this.installedReleaseTag,
    required this.download,
    this.platform = 'windows',
    this.zstd = const ZstdRunner.bundled(),
    Future<List<UpdatePackageAsset>> Function(String releaseTag)? fetchAssets,
  }) : fetchAssets = fetchAssets ?? fetchUpdatePackageAssets;

  final Directory installRoot;
  final Directory workRoot;
  final String platform;
  final String architecture;
  final String installedReleaseTag;
  final PackageDownloader download;
  final ZstdRunner zstd;
  final Future<List<UpdatePackageAsset>> Function(String releaseTag)
  fetchAssets;

  /// מכין את העדכון מהגרסה המותקנת ל-[toReleaseTag].
  Future<PreparedDifferentialUpdate> prepare(String toReleaseTag) async {
    final assets = await fetchAssets(toReleaseTag);
    final patchName = updatePackageAssetNameFor(
      platform: platform,
      architecture: architecture,
      fromReleaseTag: installedReleaseTag,
      toReleaseTag: toReleaseTag,
    );
    final patchAsset = findUpdatePackageAsset(assets, patchName);
    if (patchAsset == null) {
      throw DifferentialUpdateUnavailable(
        UpdateAbortReason.environment,
        'no update package named $patchName was published for $toReleaseTag',
      );
    }

    await workRoot.create(recursive: true);
    // שם מקומי קבוע ונטול סיומת zip: מסלול ההורדה של המתקין מחלץ כל .zip
    // שהוא מוריד, וחבילת העדכון אינה אמורה להיפרס לדיסק.
    final patchFile = await download(
      patchAsset.url,
      File(p.join(workRoot.path, 'patch-package.otzupd')),
      expectedSize: patchAsset.size,
    );
    var downloaded = await patchFile.length();

    final engine = DifferentialUpdateEngine(
      installRoot: installRoot,
      workRoot: workRoot,
      platform: platform,
      architecture: architecture,
      installedReleaseTag: installedReleaseTag,
      zstd: zstd,
    );
    final staged = await engine.prepare(
      patchFile,
      fallbackPackage: () async {
        final name = updatePackageAssetNameFor(
          platform: platform,
          architecture: architecture,
          fromReleaseTag: installedReleaseTag,
          toReleaseTag: toReleaseTag,
          kind: UpdatePackageKind.full,
        );
        final asset = findUpdatePackageAsset(assets, name);
        if (asset == null) {
          throw StateError('no full-files package named $name');
        }
        final file = await download(
          asset.url,
          File(p.join(workRoot.path, 'full-package.otzupd')),
          expectedSize: asset.size,
        );
        downloaded += await file.length();
        return file;
      },
    );
    return PreparedDifferentialUpdate(
      staged: staged,
      downloadedBytes: downloaded,
    );
  }
}
