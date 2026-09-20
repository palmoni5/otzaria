import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/update/differential/differential_update_service.dart';
import 'package:otzaria/update/differential/installed_release.dart';
import 'package:otzaria/update/differential/swap_plan.dart';
import 'package:otzaria/update/differential/update_engine.dart';
import 'package:otzaria/update/differential/update_package.dart';
import 'package:otzaria/update/differential/zstd_runner.dart';
import 'package:path/path.dart' as p;

import '../../tool/release/generate_app_file_manifest.dart' as manifest_tool;
import '../../tool/release/generate_update_package.dart' as builder;
import '../../tool/updater/updater_swap.dart';

const _oldTag = '0.9.97+789';
const _newTag = '0.9.98+801';

void _write(Directory root, String relative, String content) {
  final file = File(p.join(root.path, relative));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// שתי בניות סינתטיות שכל אחת נושאת את חותם השחרור שלה, בדיוק כפי ש-CI
/// מייצר אותן: החותם נכתב לתיקיית הבנייה לפני סריקת המניפסט.
class _Release {
  _Release(this.root);

  final Directory root;

  Directory get oldRoot => Directory(p.join(root.path, 'old'));
  Directory get newRoot => Directory(p.join(root.path, 'new'));
  File get package => File(p.join(root.path, 'package.zip'));

  late Map<String, Object?> oldManifest;
  late Map<String, Object?> newManifest;

  Map<String, Object?> _buildSide(
    Directory dir,
    String tag,
    String version,
    String body,
  ) {
    _write(dir, 'otzaria.exe', body);
    _write(dir, 'data/icudtl.dat', 'shared payload');
    manifest_tool.writeInstalledReleaseStamp(
      root: dir,
      releaseTag: tag,
      releaseVersion: version,
      platform: 'windows',
      architecture: 'x64',
    );
    return manifest_tool.buildAppFileManifest(
      releaseTag: tag,
      releaseVersion: version,
      platform: 'windows',
      architecture: 'x64',
      root: dir,
    );
  }

  void build() {
    oldRoot.createSync(recursive: true);
    newRoot.createSync(recursive: true);
    final body = List.generate(2000, (i) => 'line $i of otzaria\n').join();
    oldManifest = _buildSide(oldRoot, _oldTag, '0.9.97', '$body old');
    newManifest = _buildSide(newRoot, _newTag, '0.9.98', '$body new');
    builder.buildUpdatePackage(
      oldManifest: oldManifest,
      oldRoot: oldRoot,
      newManifest: newManifest,
      newRoot: newRoot,
      output: package,
    );
  }

  /// עותק טרי של ההתקנה הישנה, כמו אצל משתמש.
  Directory install(String name) {
    final copy = Directory(p.join(root.path, name));
    for (final entity in oldRoot.listSync(recursive: true)) {
      if (entity is! File) continue;
      final target = File(
        p.join(copy.path, p.relative(entity.path, from: oldRoot.path)),
      );
      target.parent.createSync(recursive: true);
      entity.copySync(target.path);
    }
    return copy;
  }
}

void main() {
  late Directory temp;
  final hasZstd = const builder.Zstd().isAvailable;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('otzaria-installed-release');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  String? readTag(Directory root, {String architecture = 'x64'}) =>
      readInstalledReleaseTag(
        root,
        platform: 'windows',
        architecture: architecture,
      );

  group('קריאת תג השחרור המותקן', () {
    test('חותם תקין מחזיר את התג המלא, כולל מספר הריצה', () {
      manifest_tool.writeInstalledReleaseStamp(
        root: temp,
        releaseTag: _oldTag,
        releaseVersion: '0.9.97',
        platform: 'windows',
        architecture: 'x64',
      );
      expect(readTag(temp), _oldTag);
    });

    test('אין חותם — אין תג, בלי חריגה', () {
      expect(readTag(temp), isNull);
      expect(
        File(p.join(temp.path, kInstalledReleaseFileName)).existsSync(),
        isFalse,
      );
    });

    test('חותם פגום או בסכמה אחרת נדחה', () {
      final file = File(p.join(temp.path, kInstalledReleaseFileName));
      file.writeAsStringSync('{ not json');
      expect(readTag(temp), isNull);

      file.writeAsStringSync(jsonEncode({'releaseTag': _oldTag}));
      expect(readTag(temp), isNull);

      file.writeAsStringSync(
        jsonEncode({
          'schemaVersion': kInstalledReleaseSchemaVersion + 1,
          'releaseTag': _oldTag,
          'releaseVersion': '0.9.97',
          'platform': 'windows',
          'architecture': 'x64',
        }),
      );
      expect(readTag(temp), isNull);

      file.writeAsStringSync(
        jsonEncode({
          'schemaVersion': kInstalledReleaseSchemaVersion,
          'releaseTag': '   ',
          'releaseVersion': '0.9.97',
          'platform': 'windows',
          'architecture': 'x64',
        }),
      );
      expect(readTag(temp), isNull);
    });

    test('חותם של ארכיטקטורה או פלטפורמה אחרת נדחה', () {
      manifest_tool.writeInstalledReleaseStamp(
        root: temp,
        releaseTag: _oldTag,
        releaseVersion: '0.9.97',
        platform: 'windows',
        architecture: 'arm64',
      );
      expect(readTag(temp), isNull);
      expect(readTag(temp, architecture: 'arm64'), _oldTag);
      expect(
        readInstalledReleaseTag(
          temp,
          platform: 'linux',
          architecture: 'arm64',
        ),
        isNull,
      );
    });

    test('שם הקובץ זהה בכלי הבנייה ובלקוח', () {
      expect(
        kInstalledReleaseFileName,
        manifest_tool.kInstalledReleaseFileName,
      );
      expect(
        kInstalledReleaseSchemaVersion,
        manifest_tool.kInstalledReleaseSchemaVersion,
      );
    });
  });

  group('החותם כקובץ מנוהל', () {
    late _Release release;

    setUp(() {
      release = _Release(temp);
      if (hasZstd) release.build();
    });

    test('החותם נרשם במניפסט, והמניפסט עצמו אינו מותקן', () {
      final paths = [
        for (final file in (release.newManifest['files'] as List).cast<Map>())
          file['path'] as String,
      ];
      expect(paths, contains(kInstalledReleaseFileName));
      // המניפסט נכתב מחוץ לתיקיית הבנייה ולכן אינו מתאר את עצמו.
      expect(
        paths,
        isNot(
          contains(
            manifest_tool.appFileManifestAssetName(
              platform: 'windows',
              architecture: 'x64',
            ),
          ),
        ),
      );
    }, skip: !hasZstd ? 'zstd is not on PATH' : null);

    test('העדכון מחליף את החותם, והתג הבא נקרא מההתקנה', () async {
      final install = release.install('install');
      // קובץ שיושב בהתקנה ואינו באף מניפסט — למשל מניפסט שנשמר לצד
      // התוכנה. אסור שייחשב בר-הסרה.
      _write(install, 'otzaria-app-files-windows-x64.json', '{}');
      expect(readTag(install), _oldTag);

      final work = Directory(p.join(temp.path, 'work'));
      final engine = DifferentialUpdateEngine(
        installRoot: install,
        workRoot: work,
        platform: 'windows',
        architecture: 'x64',
        installedReleaseTag: _oldTag,
        zstd: const ZstdRunner(),
      );
      final staged = await engine.prepare(release.package);

      expect(
        staged.files.map((f) => f.path),
        contains(kInstalledReleaseFileName),
      );
      expect(
        staged.removals.map((r) => r.path),
        isNot(contains('otzaria-app-files-windows-x64.json')),
      );

      final plan = await staged.writeSwapPlan();
      final result = applySwapPlan(
        SwapPlan.decode(await plan.readAsString()),
      );

      expect(result.succeeded, isTrue);
      expect(readTag(install), _newTag);
      expect(
        File(
          p.join(install.path, 'otzaria-app-files-windows-x64.json'),
        ).existsSync(),
        isTrue,
      );
    }, skip: !hasZstd ? 'zstd is not on PATH' : null);
  });

  group('שם הנכס מול תג אמיתי עם +', () {
    test('הבונה והלקוח מרכיבים אותו שם, בשתי החבילות ובשתי הארכיטקטורות', () {
      for (final architecture in const ['x64', 'arm64']) {
        for (final kind in UpdatePackageKind.values) {
          final client = updatePackageAssetNameFor(
            platform: 'windows',
            architecture: architecture,
            fromReleaseTag: _oldTag,
            toReleaseTag: _newTag,
            kind: kind,
          );
          expect(
            client,
            builder.updatePackageAssetName(
              platform: 'windows',
              architecture: architecture,
              fromReleaseTag: _oldTag,
              toReleaseTag: _newTag,
              variant: kind == UpdatePackageKind.full
                  ? builder.UpdatePackageVariant.full
                  : builder.UpdatePackageVariant.patch,
            ),
          );
          // ה-`+` הופך ל-`_` בשם הנכס, ולכן השם בטוח כקובץ וכ-URL.
          expect(client, contains('0.9.97_789-to-0.9.98_801'));
          expect(client, isNot(contains('+')));
        }
      }
    });

    test('התג המקורי מקודד ל-URL של ה-API ולא נשלח כ-+', () {
      final url = Uri.parse(
        'https://api.github.com/repos/$kUpdatePackagesRepository/releases/'
        'tags/${Uri.encodeComponent(_newTag)}',
      );
      expect(url.toString(), endsWith('/tags/0.9.98%2B801'));
      expect(url.pathSegments.last, _newTag);
    });
  });
}
