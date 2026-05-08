import 'dart:async';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/tour/bloc/tour_cubit.dart';
import 'package:otzaria/tour/bloc/tour_state.dart';
import 'package:updat/updat.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:updat/utils/file_handler.dart'
    show getDownloadFileLocation, openInstaller;
import 'package:window_manager/window_manager.dart';
import 'hebrew_update_widgets.dart';
import 'linux_installer.dart';
import 'macos_installer.dart';
import 'package:otzaria/settings/settings_exports.dart';

/// סוג ההתקנה המוגדר בזמן build (אופציונלי)
/// להגדרה: --dart-define=INSTALL_KIND=exe/zip
const _kInstallKind =
    String.fromEnvironment('INSTALL_KIND', defaultValue: 'auto');

const _githubOwner = 'Otzaria';
const _githubRepository = 'otzaria';
const _changelogAssetPath = 'assets/יומן שינויים.md';
const _kGithubTimeout = Duration(seconds: 15);
const _kDownloadTimeout = Duration(minutes: 3);

@visibleForTesting
bool supportsManagedUpdatePlatform({
  required bool isWeb,
  required String operatingSystem,
}) {
  if (isWeb) return false;
  return operatingSystem == 'windows' ||
      operatingSystem == 'macos' ||
      operatingSystem == 'linux';
}

@visibleForTesting
bool shouldLaunchInstallerOnExit({
  required UpdatStatus status,
  required bool hasInstallerFile,
}) {
  if (!hasInstallerFile) return false;
  return status == UpdatStatus.readyToInstall ||
      status == UpdatStatus.dismissed;
}

/// בוחר את קובץ העדכון המתאים ל-Windows מתוך נכסי ה-release.
///
/// בהתקנה רגילה (exe) העדיפות היא למתקין ה**שקט** — הוא מתקין ברקע ללא
/// אשף, משמר את ההגדרות ומפעיל את אוצריא מחדש בסיום — כך שהעדכון מתבצע
/// כולו מתוך התוכנה. אם אין מתקין שקט ב-release (גרסאות ישנות), נופלים
/// למתקין הרגיל. קבצי `full` (עם ספרייה מצורפת) לעולם אינם נבחרים לעדכון.
@visibleForTesting
String? pickWindowsAssetUrl(
  List<Map<String, dynamic>> assets, {
  required String preferredFormat, // 'exe' | 'zip'
}) {
  String? silentExe;
  String? regularExe;
  String? zip;

  for (final asset in assets) {
    final name = (asset['name'] as String).toLowerCase();
    final url = asset['browser_download_url'] as String;
    final isWindowsAsset = name.contains('win') ||
        name.contains('windows') ||
        name.endsWith('.exe');
    if (!isWindowsAsset) continue;
    if (name.contains('full')) continue;

    if (name.endsWith('.exe')) {
      if (name.contains('silent')) {
        silentExe ??= url;
      } else {
        regularExe ??= url;
      }
    } else if (name.endsWith('.zip')) {
      zip ??= url;
    }
  }

  final exe = silentExe ?? regularExe;
  if (preferredFormat == 'zip') {
    return zip ?? exe;
  }
  return exe ?? zip;
}

/// בוחר את נכס העדכון המתאים ל-macOS מתוך נכסי ה-release.
///
/// כשהאפליקציה מסוגלת לעדכון עצמי ([selfUpdateCapable], כלומר רצה מ-bundle
/// רגיל — לא Translocation ולא DMG; הרשאת הכתיבה בפועל נבדקת בסקריפט העדכון,
/// שרץ מחוץ ל-sandbox) — מעדיפים את ה-zip של האפליקציה בלבד
/// (`otzaria-macos.zip`), שמוחלף ברקע על ידי סקריפט העדכון. אחרת בוחרים
/// **רק** DMG, שנפתח להתקנה ידנית בגרירה: zip ללא עדכון עצמי הוא נתיב
/// שבור — הוא אינו מחולץ ב-Dart במאק (ראה `_downloadRelease`) ולכן
/// `openInstaller` ייכשל עליו. קבצי `full` לעולם אינם נבחרים — הם חבילות
/// ספרייה מלאות ולא עדכוני תוכנה.
@visibleForTesting
String? pickMacAssetUrl(
  List<Map<String, dynamic>> assets, {
  required bool selfUpdateCapable,
}) {
  String? zip;
  String? dmg;

  for (final asset in assets) {
    final name = (asset['name'] as String).toLowerCase();
    final url = asset['browser_download_url'] as String;
    final isMacAsset = name.contains('macos') ||
        name.contains('darwin') ||
        name.contains('mac');
    if (!isMacAsset) continue;
    if (name.contains('full')) continue;

    if (name.endsWith('.zip')) zip ??= url;
    if (name.endsWith('.dmg')) dmg ??= url;
  }

  if (selfUpdateCapable) {
    return zip ?? dmg;
  }
  return dmg;
}

/// האם ה-URL מצביע על המתקין השקט של Windows.
///
/// ההכרעה נעשית לפי ה-URL (שמשמר את שם הנכס ב-release) ולא לפי הקובץ
/// שהורד, כי שם הקובץ המקומי אחיד (`otzaria-<version>.exe`) ואינו מבחין
/// בין מתקין שקט לרגיל.
@visibleForTesting
bool isSilentWindowsInstallerUrl(String url) {
  final name = url.split('/').last.toLowerCase();
  return name.endsWith('.exe') && name.contains('silent');
}

/// מטמון של תוצאות GitHub API. המפתח כולל גם את הערוץ (stable/dev) כדי למנוע
/// דליפה בין ערוצים אם המשתמש מחליף הגדרה באותו סשן, וגם כדי שלא יחזרו
/// תוצאות ישנות כאשר שני release-ים בערוץ dev חולקים אותה core version
/// (כגון `0.9.92+628` ו-`0.9.92+629`).
@visibleForTesting
final Map<String, Map<String, dynamic>> releaseCacheForTesting = {};

bool _isDevChannelEnabled() =>
    Settings.getValue<bool>('key-dev-channel') ?? false;

String _cacheKey(String version, {bool? isDev}) {
  final dev = isDev ?? _isDevChannelEnabled();
  return '${dev ? 'dev' : 'stable'}:$version';
}

/// מאחסן release ב-cache עבור גרסה נתונה. נקרא מ-`getLatestVersion` כדי
/// להבטיח ש-`getChangelog`/`getBinaryUrl` מקבלים בדיוק את ה-release שזוהה
/// כ"החדש ביותר", ולא נבחר מחדש לפי prefix.
void _cacheRelease(String version, Map<String, dynamic> release,
    {bool? isDev}) {
  releaseCacheForTesting[_cacheKey(version, isDev: isDev)] = release;
}

/// בוחר את ה-release ה-pre-release האחרון ברשימה שמתאים לערוץ dev:
/// pre-release אמיתי, לא draft, ולא PR preview (tag שלא מכיל `-pr`).
/// אם אין התאמה — נופל ל-release הראשון ברשימה (כדי להתאים להתנהגות הקודמת).
/// מקבלת `List<dynamic>` ישירות מ-`jsonDecode` ולא מסתמכת על הסקה גנרית
/// של `firstWhere` שמשתנה לפי הטיפוס בזמן ריצה.
@visibleForTesting
Map<String, dynamic> pickLatestDevRelease(List<dynamic> releases) {
  for (final r in releases) {
    if (r is Map &&
        r["prerelease"] == true &&
        r["draft"] == false &&
        !r["tag_name"].toString().contains('-pr')) {
      return r.cast<String, dynamic>();
    }
  }
  return (releases.first as Map).cast<String, dynamic>();
}

/// כאשר ערוץ המפתחים פעיל, עדיין צריך לבחור release יציב אם הוא חדש יותר
/// מה-pre-release האחרון. במקרה של שוויון בגרסת הליבה מחזירים את ה-stable,
/// כדי לעגן את ה-changelog והנכסים ל-release היציב; עצם ההקפצה למשתמש עדיין
/// תלויה בהשוואת semver המלאה של `updat`, ולכן שינוי רק ב-`+build` לא ייחשב
/// לעדכון חדש.
@visibleForTesting
Map<String, dynamic> pickPreferredReleaseForDevChannel({
  required Map<String, dynamic> stableRelease,
  required Map<String, dynamic> devRelease,
}) {
  final stableTag = stableRelease['tag_name']?.toString() ?? '';
  final devTag = devRelease['tag_name']?.toString() ?? '';
  final stableVersion = _tryParseVersion(stableTag);
  final devVersion = _tryParseVersion(devTag);

  if (stableVersion == null) return devRelease;
  if (devVersion == null) return stableRelease;

  return devVersion > stableVersion ? devRelease : stableRelease;
}

/// שולפת את מידע ה-release מ-GitHub עבור גרסה נתונה ושומרת אותו במטמון.
/// אם `getLatestVersion` כבר הקדים לאחסן את ה-release המדויק שזוהה, נחזיר
/// אותו ישירות — כך מובטח עקביות בין ה-release שזוהה כ"חדש" לבין
/// ה-changelog וקובץ ההתקנה.
Future<Map<String, dynamic>> _fetchRelease(String version) async {
  final cached = releaseCacheForTesting[_cacheKey(version)];
  if (cached != null) return cached;

  final isDev = _isDevChannelEnabled();
  Map<String, dynamic> release;

  if (isDev) {
    final data = await http
        .get(Uri.parse(
          "https://api.github.com/repos/$_githubOwner/$_githubRepository/releases",
        ))
        .timeout(_kGithubTimeout);
    final releases = jsonDecode(data.body) as List;
    final byPrefix = releases
        .where((r) => r["tag_name"].toString().startsWith(version))
        .toList();
    final pool = byPrefix.isNotEmpty ? byPrefix : releases;
    release = pickLatestDevRelease(pool);
  } else {
    var resp = await http
        .get(Uri.parse(
          "https://api.github.com/repos/$_githubOwner/$_githubRepository/releases/tags/$version",
        ))
        .timeout(_kGithubTimeout);
    if (resp.statusCode == 404) {
      resp = await http
          .get(Uri.parse(
            "https://api.github.com/repos/$_githubOwner/$_githubRepository/releases/tags/v$version",
          ))
          .timeout(_kGithubTimeout);
    }
    if (resp.statusCode >= 400) {
      throw Exception(
          'Release "$version" not found (status ${resp.statusCode})');
    }
    release = (jsonDecode(resp.body) as Map).cast<String, dynamic>();
  }

  _cacheRelease(version, release, isDev: isDev);
  return release;
}

/// בונה URL לקובץ raw בריפו, צמוד לתג הספציפי של ה-release.
/// שימוש ב-`pathSegments` מבטיח קידוד נכון של תווים מיוחדים כמו `+` שבתגים
/// בערוץ dev (לדוגמה `0.9.92+628`) ושל תווי יוניקוד בנתיב.
@visibleForTesting
Uri rawAssetUrlForTag(String tagName, String relativePath) {
  final segments = <String>[
    _githubOwner,
    _githubRepository,
    'refs',
    'tags',
    tagName,
    ...relativePath.split('/'),
  ];
  return Uri(
    scheme: 'https',
    host: 'raw.githubusercontent.com',
    pathSegments: segments,
  );
}

final _changelogHeadingPattern = RegExp(
  r'^\s*(?:(?:#{1,6}|[*-])\s*)?\*{0,2}v?(\d+(?:\.\d+){1,2}(?:[-+][^\s*]+)?)\*{0,2}\s*$',
);

class _ParsedVersion implements Comparable<_ParsedVersion> {
  final int major;
  final int minor;
  final int patch;

  const _ParsedVersion(this.major, this.minor, this.patch);

  @override
  int compareTo(_ParsedVersion other) {
    final majorCompare = major.compareTo(other.major);
    if (majorCompare != 0) return majorCompare;

    final minorCompare = minor.compareTo(other.minor);
    if (minorCompare != 0) return minorCompare;

    return patch.compareTo(other.patch);
  }

  bool operator >(_ParsedVersion other) => compareTo(other) > 0;

  bool operator <=(_ParsedVersion other) => compareTo(other) <= 0;

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ParsedVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

/// זיהוי סוג ההתקנה ב-Windows
/// אם הוגדר INSTALL_KIND בזמן build - משתמש בו
/// אחרת - מזהה לפי נתיב הקובץ
String _preferredWindowsFormat() {
  if (!Platform.isWindows) return 'unknown';

  // אם הוגדר סוג התקנה בזמן build - משתמש בו
  if (_kInstallKind != 'auto') return _kInstallKind; // 'exe' | 'zip'

  try {
    // זיהוי אוטומטי לפי נתיב הקובץ
    final executablePath = Platform.resolvedExecutable.toLowerCase();

    if (executablePath.contains('\\program files\\') ||
        executablePath.contains('\\program files (x86)\\')) {
      return 'exe'; // התקנה תקנית
    }

    return 'zip'; // גרסה ניידת/ידנית
  } catch (e) {
    // במקרה של שגיאה, ברירת מחדל היא EXE
    return 'exe';
  }
}

String _normalizeVersion(String version) {
  var normalized = version.trim();
  if (normalized.startsWith('v')) {
    normalized = normalized.substring(1);
  }

  final plusIndex = normalized.indexOf('+');
  if (plusIndex != -1) {
    normalized = normalized.substring(0, plusIndex);
  }

  return normalized;
}

_ParsedVersion? _tryParseVersion(String version) {
  final core = _normalizeVersion(version).split('-').first;
  final parts = core.split('.');
  if (parts.length < 2 || parts.length > 3) return null;

  final major = int.tryParse(parts[0]);
  final minor = int.tryParse(parts[1]);
  final patch = parts.length == 3 ? int.tryParse(parts[2]) : 0;
  if (major == null || minor == null || patch == null) return null;

  return _ParsedVersion(major, minor, patch);
}

/// מחזירה את פריטי יומן השינויים שבין הגרסה הנוכחית לגרסה הזמינה.
@visibleForTesting
String changelogBetweenVersionsForUpdateDialog({
  required String changelog,
  required String currentVersion,
  required String latestVersion,
}) {
  final current = _tryParseVersion(currentVersion);
  final latest = _tryParseVersion(latestVersion);
  if (current == null || latest == null || latest <= current) {
    return changelog;
  }

  final lines = changelog.split('\n');
  final selected = <String>[];
  var includeCurrentSection = false;
  var sawVersionHeading = false;

  for (final line in lines) {
    final match = _changelogHeadingPattern.firstMatch(line);
    if (match != null) {
      sawVersionHeading = true;
      final headingVersion = _tryParseVersion(match.group(1)!);
      includeCurrentSection = headingVersion != null &&
          headingVersion > current &&
          headingVersion <= latest;

      if (includeCurrentSection) {
        if (selected.isNotEmpty && selected.last.trim().isNotEmpty) {
          selected.add('');
        }
        selected.add(line);
      }
      continue;
    }

    if (!sawVersionHeading) {
      continue;
    }

    if (includeCurrentSection) {
      selected.add(line);
    }
  }

  final result = selected.join('\n').trim();
  if (result.isEmpty) {
    return 'update.no_changelog_between'.tr(
        namedArgs: {'current': currentVersion, 'latest': latestVersion});
  }
  return result;
}

class MyUpdatWidget extends StatelessWidget {
  const MyUpdatWidget({super.key, required this.child});

  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!supportsManagedUpdatePlatform(
      isWeb: kIsWeb,
      operatingSystem: Platform.operatingSystem,
    )) {
      return child;
    }
    final isOfflineMode =
        Settings.getValue<bool>(SettingsRepository.keyOfflineMode) ?? false;
    final softwareAndBookUpdatesEnabled = Settings.getValue<bool>(
          SettingsRepository.keySoftwareAndBookUpdatesEnabled,
          defaultValue: true,
        ) ??
        true;
    if (kDebugMode || isOfflineMode || !softwareAndBookUpdatesEnabled) {
      return child;
    }

    return _ManagedUpdatWidget(child: child);
  }
}

class _ManagedUpdatWidget extends StatefulWidget {
  const _ManagedUpdatWidget({required this.child});

  final Widget child;

  @override
  State<_ManagedUpdatWidget> createState() => _ManagedUpdatWidgetState();
}

class _ManagedUpdatWidgetState extends State<_ManagedUpdatWidget> {
  UpdatStatus _status = UpdatStatus.checking;
  String? _currentVersion;
  String? _latestVersion;
  String? _changelog;
  File? _installerFile;

  /// האם הקובץ ב-[_installerFile] הוא המתקין השקט של Windows (נקבע לפי
  /// ה-URL בעת ההורדה — ראה [isSilentWindowsInstallerUrl]).
  bool _installerIsSilent = false;
  bool _windowCloseHookInstalled = false;

  /// טיימר להעלמה אוטומטית של צ'יפ השגיאה אחרי 4 שניות.
  Timer? _errorDismissTimer;

  /// מנוי על מצב הסיור המודרך, פעיל רק כל עוד אנו ממתינים לסיומו לפני
  /// בדיקת העדכון הראשונית.
  StreamSubscription<TourState>? _tourSubscription;

  /// מסמן שהבדיקה האוטומטית הראשונית כבר הופעלה, כדי שלא תופעל פעמיים.
  bool _initialCheckTriggered = false;

  @override
  void initState() {
    super.initState();
    _installWindowCloseHook();
    // דוחים את הבדיקה הראשונית ל-post-frame כדי שהסיור המודרך (שמופעל אף הוא
    // ב-post-frame, מוקדם יותר באותו פריים) יספיק לעדכן את מצבו לפני שנחליט.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startInitialUpdateCheckRespectingTour();
    });
  }

  /// מפעיל את בדיקת העדכון הראשונית רק כשהסיור המודרך אינו פעיל. אם הסיור פעיל,
  /// מאזין למצבו וממתין עד שיסתיים (סיום או דילוג) לפני הבדיקה.
  void _startInitialUpdateCheckRespectingTour() {
    if (_initialCheckTriggered) return;
    final tourCubit = context.read<TourCubit>();
    if (!tourCubit.state.isActive) {
      _initialCheckTriggered = true;
      _checkForUpdate();
      return;
    }
    _tourSubscription ??= tourCubit.stream.listen((tourState) {
      if (tourState.isActive || _initialCheckTriggered) return;
      _initialCheckTriggered = true;
      _tourSubscription?.cancel();
      _tourSubscription = null;
      if (mounted) _checkForUpdate();
    });
  }

  @override
  void dispose() {
    _tourSubscription?.cancel();
    _errorDismissTimer?.cancel();
    if (_windowCloseHookInstalled) {
      windowManager.removeListener(_windowListener);
      _windowCloseHookInstalled = false;
    }
    super.dispose();
  }

  /// מציג מצב שגיאה זמני: מרענן את הצ'יפ ומתזמן העלמה אוטומטית אחרי 4 שניות.
  /// לחיצה על הצ'יפ מפעילה בדיקה חוזרת (`_checkForUpdate`) שמבטלת את הטיימר.
  void _showTransientError() {
    if (!mounted) return;
    setState(() {
      _status = UpdatStatus.error;
    });
    _errorDismissTimer?.cancel();
    _errorDismissTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _status != UpdatStatus.error) return;
      _dismissUpdate();
    });
  }

  Future<void> _installWindowCloseHook() async {
    try {
      await windowManager.setPreventClose(true);
      if (!mounted) {
        return;
      }
      windowManager.addListener(_windowListener);
      _windowCloseHookInstalled = true;
    } catch (_) {
      _windowCloseHookInstalled = false;
    }
  }

  late final WindowListener _windowListener = _ManagedUpdateWindowListener(
    handleWindowClose: _handleWindowClose,
  );

  Future<void> _handleWindowClose() async {
    try {
      if (shouldLaunchInstallerOnExit(
        status: _status,
        hasInstallerFile: _installerFile != null,
      )) {
        // המשתמש סוגר את התוכנה — העדכון מותקן ברקע, אך אין להפעיל את
        // אוצריא מחדש בסיום בניגוד לכוונתו.
        final launched = await _launchInstaller(relaunchApp: false);
        if (launched) _installerFile = null;
      }
    } finally {
      await windowManager.destroy();
    }
  }

  /// מפעיל את ההתקנה ביוזמת המשתמש (כפתור "מוכן להתקנה"): משגר את המתקין
  /// ורק אם השיגור הצליח סוגר את אוצריא. כך המתקין מופעל כפעולה האחרונה
  /// לפני היציאה — אוצריא כבר אינה רצה כשהמתקין מעתיק קבצים, ולכן אין צורך
  /// שהמתקין יבקש לסגור אותה ואין מצב שבו סגירה ידנית קוטעת מתקין שרץ.
  ///
  /// בשונה מ-[_handleWindowClose] (שמופעל כשהמשתמש סוגר את החלון ולכן חייב
  /// לסגור בכל מקרה), כאן אם השיגור נכשל אנו משאירים את החלון פתוח כדי
  /// שהמשתמש יראה את מצב השגיאה ויוכל לנסות שוב.
  Future<void> _installNow() async {
    if (_installerFile == null) return;
    final launched = await _launchInstaller(relaunchApp: true);
    if (launched) {
      // איפוס הקובץ מונע שיגור מתקין כפול אם יגיע אירוע סגירת חלון נוסף
      // (למשל מהמתקין עצמו) לפני שה-destroy מסתיים.
      _installerFile = null;
      await windowManager.destroy();
    }
  }

  Future<void> _checkForUpdate() async {
    _errorDismissTimer?.cancel();
    setState(() {
      _status = UpdatStatus.checking;
    });

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final latestVersion = await _getLatestVersion();

      if (!mounted) return;

      if (latestVersion == null) {
        setState(() {
          _currentVersion = currentVersion;
          _status = UpdatStatus.upToDate;
        });
        return;
      }

      final parsedCurrent = _tryParseVersion(currentVersion);
      final parsedLatest = _tryParseVersion(latestVersion);

      if (parsedCurrent != null &&
          parsedLatest != null &&
          parsedLatest > parsedCurrent) {
        final changelog = await _getChangelog(latestVersion, currentVersion);
        if (!mounted) return;
        setState(() {
          _currentVersion = currentVersion;
          _latestVersion = latestVersion;
          _changelog = changelog;
          _status = UpdatStatus.availableWithChangelog;
        });
        return;
      }

      setState(() {
        _currentVersion = currentVersion;
        _latestVersion = latestVersion;
        _status = UpdatStatus.upToDate;
      });
    } catch (_) {
      _showTransientError();
    }
  }

  Future<String?> _getLatestVersion() async {
    releaseCacheForTesting.clear();

    final isDevChannel = _isDevChannelEnabled();

    if (isDevChannel) {
      final devData = await http
          .get(Uri.parse(
            "https://api.github.com/repos/$_githubOwner/$_githubRepository/releases",
          ))
          .timeout(_kGithubTimeout);
      final stableData = await http
          .get(Uri.parse(
            "https://api.github.com/repos/$_githubOwner/$_githubRepository/releases/latest",
          ))
          .timeout(_kGithubTimeout);
      final releases = jsonDecode(devData.body) as List;
      final preRelease = pickLatestDevRelease(releases);
      final stableRelease =
          (jsonDecode(stableData.body) as Map).cast<String, dynamic>();
      final selectedRelease = pickPreferredReleaseForDevChannel(
        stableRelease: stableRelease,
        devRelease: preRelease,
      );
      final normalized =
          _normalizeVersion(selectedRelease["tag_name"] as String);
      _cacheRelease(normalized, selectedRelease, isDev: true);
      return normalized;
    }

    final data = await http
        .get(Uri.parse(
          "https://api.github.com/repos/$_githubOwner/$_githubRepository/releases/latest",
        ))
        .timeout(_kGithubTimeout);
    final release = (jsonDecode(data.body) as Map).cast<String, dynamic>();
    final normalized = _normalizeVersion(release["tag_name"] as String);
    _cacheRelease(normalized, release, isDev: false);
    return normalized;
  }

  Future<String> _getBinaryUrl(String version) async {
    final release = await _fetchRelease(version).timeout(_kGithubTimeout);
    final assets = (release["assets"] as List).cast<Map<String, dynamic>>();
    final platform = Platform.operatingSystem.toLowerCase();

    String? assetUrl;

    if (platform == 'windows') {
      assetUrl = pickWindowsAssetUrl(
        assets,
        preferredFormat: _preferredWindowsFormat(),
      );
    } else if (platform == 'macos') {
      assetUrl = pickMacAssetUrl(
        assets,
        selfUpdateCapable: findInstalledMacAppBundlePath() != null,
      );
    } else if (platform == 'linux') {
      for (final a in assets) {
        final n = (a["name"] as String).toLowerCase();
        final u = a["browser_download_url"] as String;
        if (n.endsWith('.deb')) {
          assetUrl = u;
          break;
        }
      }
      if (assetUrl == null) {
        for (final a in assets) {
          final n = (a["name"] as String).toLowerCase();
          final u = a["browser_download_url"] as String;
          if (n.endsWith('.rpm')) {
            assetUrl = u;
            break;
          }
        }
      }
      if (assetUrl == null) {
        for (final a in assets) {
          final n = (a["name"] as String).toLowerCase();
          final u = a["browser_download_url"] as String;
          if ((n.contains('linux') || n.contains('gnu')) &&
              n.endsWith('.zip')) {
            assetUrl = u;
            break;
          }
        }
      }
    }

    if (assetUrl == null) {
      throw Exception('No suitable binary found for $platform');
    }
    return assetUrl;
  }

  Future<String> _getChangelog(String latestVersion, String appVersion) async {
    try {
      final release = await _fetchRelease(latestVersion);
      final tagName = release['tag_name'] as String;
      final url = rawAssetUrlForTag(tagName, _changelogAssetPath);
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return changelogBetweenVersionsForUpdateDialog(
          changelog: response.body,
          currentVersion: appVersion,
          latestVersion: latestVersion,
        );
      }
      return 'update.load_changelog_error_code'
          .tr(namedArgs: {'code': '${response.statusCode}'});
    } catch (e) {
      return 'update.load_changelog_error'
          .tr(namedArgs: {'error': '$e'});
    }
  }

  Future<void> _startUpdate() async {
    if (_latestVersion == null) {
      return;
    }

    if (_status == UpdatStatus.readyToInstall) {
      return _installNow();
    }

    if (_status != UpdatStatus.available &&
        _status != UpdatStatus.availableWithChangelog) {
      return;
    }

    setState(() {
      _status = UpdatStatus.downloading;
    });

    try {
      final url = await _getBinaryUrl(_latestVersion!).timeout(_kGithubTimeout);
      final installerFile = await getDownloadFileLocation(
        _latestVersion!,
        'otzaria',
        url.split('.').last,
      ).timeout(_kGithubTimeout);
      await _downloadRelease(installerFile, url, 'otzaria')
          .timeout(_kDownloadTimeout);

      if (!mounted) return;
      setState(() {
        _installerFile = installerFile;
        _installerIsSilent = isSilentWindowsInstallerUrl(url);
        _status = UpdatStatus.readyToInstall;
      });
    } catch (_) {
      _showTransientError();
    }
  }

  /// משגר את המתקין ומחזיר `true` אם השיגור הצליח. כשל בשיגור נבלע ומעדכן
  /// את המצב ל-[UpdatStatus.error] (ללא זריקת חריגה), ומחזיר `false`, כדי
  /// שהקוראים יחליטו האם לסגור את החלון בהתאם.
  ///
  /// [relaunchApp] — האם אוצריא תופעל מחדש בסיום ההתקנה (רלוונטי למתקין
  /// השקט ב-Windows): `true` בעדכון יזום ("התקן כעת"), `false` בעדכון
  /// בעת סגירת התוכנה.
  Future<bool> _launchInstaller({required bool relaunchApp}) async {
    if (_installerFile == null) return false;

    try {
      await _launchInstallerDirect(relaunchApp: relaunchApp);
      return true;
    } catch (_) {
      _showTransientError();
      return false;
    }
  }

  Future<void> _launchInstallerDirect({required bool relaunchApp}) async {
    final installer = _installerFile;
    if (installer == null) return;

    // רק המתקין השקט (PrivilegesRequired=lowest) בטוח ב-Process.start; הרגיל
    // עלול לדרוש UAC בשיגור וחייב ShellExecute, אחרת ERROR_ELEVATION_REQUIRED.
    if (Platform.isWindows && _installerIsSilent) {
      await Process.start(
        installer.absolute.path,
        relaunchApp ? const <String>[] : const <String>['/NOLAUNCH=1'],
        mode: ProcessStartMode.detached,
      );
      return;
    }

    // macOS: zip + bundle בר-החלפה = עדכון עצמי בסקריפט; אחרת openInstaller
    // מעגן (mount) את ה-DMG להתקנה ידנית בגרירה.
    if (Platform.isMacOS && installer.path.toLowerCase().endsWith('.zip')) {
      final appBundlePath = findInstalledMacAppBundlePath();
      if (appBundlePath != null) {
        await installMacUpdate(
          zipFile: installer,
          appBundlePath: appBundlePath,
          relaunchApp: relaunchApp,
        );
        return;
      }
    }

    // ב-Linux חבילות deb/rpm מותקנות בטרמינל עם pkexec והפעלה מחדש לפי
    // [relaunchApp]. אם אין מנהל חבילות נתמך — נופלים לפתיחת הקובץ
    // במתקין הגרפי של המערכת (ההתנהגות הקודמת).
    final lowerPath = installer.path.toLowerCase();
    if (Platform.isLinux &&
        (lowerPath.endsWith('.deb') || lowerPath.endsWith('.rpm'))) {
      try {
        await installLinuxUpdate(
          packageFile: installer,
          relaunchApp: relaunchApp,
        );
        return;
      } catch (_) {
        // נפילה ל-openInstaller למטה.
      }
    }

    await openInstaller(installer, 'otzaria');
  }

  void _dismissUpdate() {
    if (!mounted) return;
    setState(() {
      _status = UpdatStatus.dismissed;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ה-Stack עוטף גם את סרגל הניווט הצדי; בלי היסט ברוחב הסרגל הצ'יפ
    // נצמד לקצה החלון ונמתח מעל הסרגל במקום מעל תוכן המסך.
    const navRailWidth = 75.0; // 74 רוחב הסרגל + 1 הקו המפריד
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final railInset = isLandscape ? navRailWidth : 0.0;

    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          right: 10 + railInset,
          bottom: 10,
          child: hebrewFlatChip(
            context: context,
            latestVersion: _latestVersion,
            appVersion: _currentVersion ?? 'unknown',
            status: _status,
            checkForUpdate: _checkForUpdate,
            openDialog: () {
              hebrewDefaultDialog(
                context: context,
                latestVersion: _latestVersion,
                appVersion: _currentVersion ?? 'unknown',
                status: _status,
                changelog: _changelog,
                checkForUpdate: _checkForUpdate,
                openDialog: () {},
                startUpdate: _startUpdate,
                launchInstaller: _installNow,
                dismissUpdate: _dismissUpdate,
              );
            },
            startUpdate: _startUpdate,
            launchInstaller: _installNow,
            dismissUpdate: _dismissUpdate,
          ),
        ),
      ],
    );
  }
}

class _ManagedUpdateWindowListener extends WindowListener {
  _ManagedUpdateWindowListener({required this.handleWindowClose});

  final Future<void> Function() handleWindowClose;

  @override
  void onWindowClose() async {
    await handleWindowClose();
  }
}

Future<File> _downloadRelease(File file, String url, String appName) async {
  final client = http.Client();
  IOSink? sink;
  try {
    final request = http.Request('GET', Uri.parse(url));
    final response = await client.send(request).timeout(_kGithubTimeout);
    if (response.statusCode != 200) {
      throw Exception('Download failed with status ${response.statusCode}');
    }

    await file.parent.create(recursive: true);
    sink = file.openWrite();

    await response.stream
        .timeout(const Duration(seconds: 30))
        .forEach(sink.add);
    await sink.flush();
    await sink.close();
    sink = null;

    // ב-macOS אין לחלץ את ה-zip ב-Dart: חבילת archive אינה משמרת symlinks
    // והרשאות הפעלה שבתוך ה-bundle. סקריפט העדכון מחלץ בעצמו עם ditto.
    if (file.path.toLowerCase().endsWith('.zip') && !Platform.isMacOS) {
      final outDir = Directory(p.join(p.dirname(file.path), appName));
      if (outDir.existsSync()) {
        outDir.deleteSync(recursive: true);
      }
      outDir.createSync(recursive: true);
      extractFileToDisk(file.absolute.path, outDir.absolute.path);
    }

    return file;
  } finally {
    await sink?.close();
    client.close();
  }
}
