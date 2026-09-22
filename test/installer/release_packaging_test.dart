import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('ארכיון מפוצל נבנה מחדש ומאומת לפי ה-manifest', () async {
    final temp = Directory.systemTemp.createTempSync('otzaria_release_parts_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final source = File(p.join(temp.path, 'indexed-full.tar.zst'));
    final sourceBytes = List<int>.generate(1025, (index) => index % 251);
    source.writeAsBytesSync(sourceBytes);
    final partsDirectory = Directory(p.join(temp.path, 'parts'));

    final split = await Process.run('bash', [
      'tool/release/split_release_asset.sh',
      source.path,
      partsDirectory.path,
      '128',
    ]);
    expect(split.exitCode, 0, reason: '${split.stdout}\n${split.stderr}');

    final manifestFile = File(
      p.join(partsDirectory.path, 'indexed-full.tar.zst.manifest.json'),
    );
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final parts = manifest['parts'] as List<dynamic>;
    expect(parts, hasLength(9));
    expect(
      parts.every((part) => (part as Map<String, dynamic>)['size'] <= 128),
      isTrue,
    );

    final reassembled = p.join(temp.path, 'reassembled.tar.zst');
    final assemble = await Process.run('bash', [
      'tool/release/assemble_split_asset.sh',
      manifestFile.path,
      reassembled,
    ]);
    expect(
      assemble.exitCode,
      0,
      reason: '${assemble.stdout}\n${assemble.stderr}',
    );
    expect(File(reassembled).readAsBytesSync(), sourceBytes);

    final manifestSummary = p.join(temp.path, 'manifest-summary.txt');
    final parseManifest = await Process.run('pwsh', [
      '-NoLogo',
      '-NoProfile',
      '-File',
      'installer/read_indexed_library_manifest.ps1',
      '-ManifestPath',
      manifestFile.path,
      '-OutputPath',
      manifestSummary,
    ]);
    expect(
      parseManifest.exitCode,
      0,
      reason: '${parseManifest.stdout}\n${parseManifest.stderr}',
    );
    final summaryLines = File(manifestSummary).readAsLinesSync();
    expect(summaryLines.first, startsWith('archive|indexed-full.tar.zst|'));
    expect(
      summaryLines.where((line) => line.startsWith('part|')),
      hasLength(9),
    );

    final embeddedManifestDirectory = Directory(
      p.join(temp.path, 'embedded-manifest'),
    )..createSync();
    final embeddedManifest = File(
      p.join(embeddedManifestDirectory.path, 'indexed_library.manifest.json'),
    );
    manifestFile.copySync(embeddedManifest.path);
    final powerShellOutput = p.join(temp.path, 'reassembled-pwsh.tar.zst');
    final powerShellAssemble = await Process.run('pwsh', [
      '-NoLogo',
      '-NoProfile',
      '-File',
      'tool/release/assemble_split_asset.ps1',
      embeddedManifest.path,
      powerShellOutput,
      partsDirectory.path,
    ]);
    expect(
      powerShellAssemble.exitCode,
      0,
      reason: '${powerShellAssemble.stdout}\n${powerShellAssemble.stderr}',
    );
    expect(File(powerShellOutput).readAsBytesSync(), sourceBytes);

    final firstPart = File(
      p.join(
        partsDirectory.path,
        (parts.first as Map<String, dynamic>)['name'],
      ),
    );
    firstPart.writeAsBytesSync([0], mode: FileMode.append);
    final rejectedOutput = p.join(temp.path, 'rejected.tar.zst');
    final rejectedAssembly = await Process.run('pwsh', [
      '-NoLogo',
      '-NoProfile',
      '-File',
      'tool/release/assemble_split_asset.ps1',
      embeddedManifest.path,
      rejectedOutput,
      partsDirectory.path,
    ]);
    expect(rejectedAssembly.exitCode, isNot(0));
    expect(File(rejectedOutput).existsSync(), isFalse);
  });

  test('ה-workflow מפריד בין המתקין לחלקי הספרייה שמתחת ל-2 GiB', () {
    final workflow = File(
      '.github/workflows/build-and-announce.yml',
    ).readAsStringSync();

    // האינדקס אינו נבנה כאן יותר — הוא מגיע מוכן מ-SeforimLibrary.
    expect(workflow, isNot(contains('build-release-index')));
    expect(workflow, contains('tool/release/fetch_prebuilt_library_index.sh'));
    expect(workflow, contains('otzaria-index-inputs'));
    expect(workflow, contains('otzaria-library-full-indexed'));
    expect(workflow, contains('1992294400'));
    expect(workflow, contains('split_release_asset.sh'));
    expect(workflow, contains('compression-level: 0'));
    expect(workflow, contains('/DIndexedSplitFull=1'));
    expect(workflow, contains('otzaria-windows-installer-full-indexed'));
    expect(workflow, contains('התקנה לא־מקוונת בווינדוס'));
    expect(workflow, contains('indexed_library.manifest.json'));
    expect(
      workflow,
      contains(
        'cp -al "\$GITHUB_WORKSPACE/\$BUNDLE_ROOT/אוצריא" '
        '"\$INDEXED_LIBRARY_ROOT/books"',
      ),
    );
  });

  test('אינדקס מאוחסן מותקן רק כשה-DB והמנוע של הבנייה תואמים', () async {
    final temp = Directory.systemTemp.createTempSync('otzaria_prebuilt_index_');
    addTearDown(() => temp.deleteSync(recursive: true));

    Future<ProcessResult> sh(String script) =>
        Process.run('bash', ['-euo', 'pipefail', '-c', script]);

    Future<String> sha256Of(String path) async {
      final result = await Process.run('sha256sum', [path]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return (result.stdout as String).split(RegExp(r'\s+')).first;
    }

    // ספרייה שמדמה אינדקס בנוי, ארוזה ומפוצלת בדיוק כמו בצד SeforimLibrary.
    final sourceIndex = Directory(p.join(temp.path, 'src', 'index'))
      ..createSync(recursive: true);
    File(p.join(sourceIndex.path, 'meta.json')).writeAsStringSync('{"o":1}');
    final dist = Directory(p.join(temp.path, 'dist'))..createSync();
    final archive = p.join(temp.path, 'otzaria-library-index.tar.zst');
    final packed = await sh(
      'tar -C "${p.join(temp.path, 'src')}" -cf - index '
      '| zstd -19 -o "$archive"',
    );
    expect(packed.exitCode, 0, reason: '${packed.stderr}');
    final split = await Process.run('bash', [
      'tool/release/split_release_asset.sh',
      archive,
      dist.path,
      '1992294400',
    ]);
    expect(split.exitCode, 0, reason: '${split.stdout}\n${split.stderr}');

    final database = File(p.join(temp.path, 'seforim.db.zst'))
      ..writeAsBytesSync(List<int>.generate(64, (index) => index));
    // ארכיון תלמוד אמיתי: השער בצד הזה גוזר את קבוצת שמות הכרכים מרשימת
    // הארכיון, ולכן קובץ אקראי לא היה בודק דבר.
    final talmudRoot = p.join(temp.path, 'talmud');
    final talmudSource = Directory(p.join(talmudRoot, 'תלמוד בבלי'))
      ..createSync(recursive: true);
    for (final tractate in ['מסכת ברכות', 'מסכת שבת', 'מסכת עירובין']) {
      File(
        p.join(talmudSource.path, '$tractate.pdf'),
      ).writeAsStringSync('%PDF-1.4 $tractate');
    }
    File(p.join(talmudSource.path, '.version')).writeAsStringSync('deadbeef');
    final talmud = File(p.join(temp.path, 'talmud_bavli_latest.tar.zst'));
    final packedTalmud = await sh(
      'tar -C "$talmudRoot" -cf - "תלמוד בבלי" | zstd -19 -q -o "${talmud.path}"',
    );
    expect(packedTalmud.exitCode, 0, reason: '${packedTalmud.stderr}');

    // בדיוק הצינור ששני הצדדים מריצים על אותו ארכיון.
    final volumesDigest = await sh(
      'zstd -d -c "${talmud.path}" | tar -tf - | sed "s#.*/##" '
      r"| grep -i '\.pdf$' | LC_ALL=C sort -u | sha256sum | awk '{print $1}'",
    );
    expect(volumesDigest.exitCode, 0, reason: '${volumesDigest.stderr}');
    final talmudVolumesDigest = (volumesDigest.stdout as String).trim();
    expect(talmudVolumesDigest, hasLength(64));

    final lock = File(p.join(temp.path, 'pubspec.lock'))
      ..writeAsStringSync('''
packages:
  otzaria_search_engine:
    dependency: "direct main"
    source: hosted
    version: "0.8.4"
''');

    Future<ProcessResult> fetch({
      required String databaseSha256,
      required String engineVersion,
      required String indexDirectory,
      String? volumesDigest,
    }) async {
      File(
        p.join(dist.path, 'otzaria-library-index.provenance.json'),
      ).writeAsStringSync(
        jsonEncode({
          'schemaVersion': 1,
          'libraryReleaseTag': 'v28-20260910220310',
          'seforimDbZstSha256': databaseSha256,
          'indexArchive': 'otzaria-library-index.tar.zst',
          'indexArchiveSha256': await sha256Of(archive),
          'catalogueBooks': 7,
          'talmudBavliSha256': await sha256Of(talmud.path),
          'talmudVolumesDigest': volumesDigest ?? talmudVolumesDigest,
          'talmudVolumes': 3,
          'includesPdfBooks': false,
          'searchEngineVersion': engineVersion,
        }),
      );
      return Process.run(
        'bash',
        [
          'tool/release/fetch_prebuilt_library_index.sh',
          indexDirectory,
          database.path,
          talmud.path,
          lock.path,
        ],
        environment: {'PREBUILT_LIBRARY_INDEX_BASE_URL': 'file://${dist.path}'},
      );
    }

    final installed = p.join(temp.path, 'installed', 'index');
    final ok = await fetch(
      databaseSha256: await sha256Of(database.path),
      engineVersion: '0.8.4',
      indexDirectory: installed,
    );
    expect(ok.exitCode, 0, reason: '${ok.stdout}\n${ok.stderr}');
    expect(File(p.join(installed, 'meta.json')).existsSync(), isTrue);

    // אינדקס של DB אחר: החבילה הייתה נשלחת עם אינדקס שאינו תואם לספרים שבה.
    final wrongDatabase = await fetch(
      databaseSha256: 'f' * 64,
      engineVersion: '0.8.4',
      indexDirectory: p.join(temp.path, 'wrong-db', 'index'),
    );
    expect(wrongDatabase.exitCode, isNot(0));
    expect(wrongDatabase.stderr, contains('build-library-index.yml'));

    // מנוע חיפוש אחר: האפליקציה הייתה דוחה את האינדקס ובונה אותו מחדש אצל המשתמש.
    final wrongEngine = await fetch(
      databaseSha256: await sha256Of(database.path),
      engineVersion: '0.7.0',
      indexDirectory: p.join(temp.path, 'wrong-engine', 'index'),
    );
    expect(wrongEngine.exitCode, isNot(0));
    expect(wrongEngine.stderr, contains('otzaria_search_engine'));

    // כרכי תלמוד אחרים: catalogueOrder של כמעט כל הספרייה היה זז מול
    // מה שהאפליקציה מחשבת אצל המשתמש, בלי ששום בדיקה הייתה תופסת זאת.
    final wrongTalmud = await fetch(
      databaseSha256: await sha256Of(database.path),
      engineVersion: '0.8.4',
      indexDirectory: p.join(temp.path, 'wrong-talmud', 'index'),
      volumesDigest: 'e' * 64,
    );
    expect(wrongTalmud.exitCode, isNot(0));
    expect(wrongTalmud.stderr, contains('catalogue order'));
  });

  test('ה-workflow שומר את ה-SHA שנבחר ותומך בתיקון חירום', () {
    final workflow = File(
      '.github/workflows/build-and-announce.yml',
    ).readAsStringSync();

    expect(workflow, contains('      hotfix:'));
    expect(workflow, contains('default: "0"'));
    expect(workflow, contains("inputs.hotfix != '0'"));
    expect(workflow, contains('HOTFIX: \${{ inputs.hotfix }}'));
    expect(workflow, contains("grep -Eq '^(0|[1-9][0-9]?)\$'"));
    expect(workflow, contains('ref: \${{ github.sha }}'));
    expect(workflow, isNot(contains('ref: \${{ github.ref_name }}')));
    expect(workflow, contains(r'"hotfix": %s'));
    expect(workflow, contains(r'"$NEW_VERSION" "$HOTFIX"'));
  });
  group('מסייע ההורדה ומניפסט ה-release ב-workflow', () {
    final workflow = File(
      '.github/workflows/build-and-announce.yml',
    ).readAsStringSync();

    test('האשף נבנה עם ה-ISCC הקיים ואינו מפיל את שחרור אוצריא', () {
      expect(
        workflow,
        contains(r'$tagDefine installer\download_assistant.iss'),
      );
      expect(
        workflow,
        contains(
          '      - name: Build Download Assistant (non-fatal helper tool)\n'
          '        id: download_assistant\n'
          '        continue-on-error: true\n',
        ),
      );
      expect(workflow, contains('name: otzaria-download-assistant'));

      // ההתקנה של Inno Setup לא שוכפלה בשביל הכלי החדש.
      expect('Install Inno Setup'.allMatches(workflow).length, 3);
    });

    test('המניפסט נוצר אחרי ארגון הקבצים ונכתב לתוך release-files', () {
      final organize = workflow.indexOf('- name: Organize release files');
      final generate = workflow.indexOf('- name: Generate release manifest');
      final createRelease = workflow.indexOf('- name: Create Release');
      expect(organize, greaterThan(0));
      expect(generate, greaterThan(organize));
      expect(createRelease, greaterThan(generate));

      expect(
        workflow,
        contains('dart run tool/release/generate_release_manifest.dart'),
      );
      expect(workflow, contains('--dir release-files'));
      expect(
        workflow,
        contains('--out release-files/otzaria-release-manifest.json'),
      );

      // נכס עזר אינו מבטל release: כישלון כאן מזהיר, מוחק מניפסט חלקי
      // וממשיך — בדיוק כמו בניית האשף עצמו.
      expect(
        workflow.substring(generate, generate + 300),
        contains('continue-on-error: true'),
      );
      final warn = workflow.indexOf(
        '- name: Warn when the release manifest is missing',
      );
      expect(warn, greaterThan(generate));
      expect(warn, lessThan(createRelease));
      expect(
        workflow.substring(warn, warn + 400),
        contains('rm -f release-files/otzaria-release-manifest.json'),
      );
    });

    test('שם נכס המניפסט הוא זה שהאשף מחפש', () {
      final iss = File('installer/download_assistant.iss').readAsStringSync();
      final suffix = RegExp(
        r"EndsWithText\(Name, '([^']*manifest[^']*)'\)",
      ).firstMatch(iss)!.group(1)!;
      expect('otzaria-release-manifest.json'.endsWith(suffix), isTrue);
    });

    test('פיצול מתקין ה-FULL מותנה במגבלת ה-2 GiB ואינו נדרש היום', () {
      expect(workflow, contains('GITHUB_ASSET_LIMIT=2147483648'));
      expect(
        workflow,
        contains(
          r'for installer in release-files/otzaria-*-windows-full.exe; do',
        ),
      );
      expect(
        workflow,
        contains(r'if [ "$size" -lt "$GITHUB_ASSET_LIMIT" ]; then'),
      );
      expect(
        workflow,
        contains(
          r'tool/release/split_release_asset.sh "$installer" '
          r'windows-full-parts "$PART_SIZE"',
        ),
      );

      // הגודל בפועל של otzaria-0.9.97-windows-full.exe — התנאי יוצא שקר,
      // ולכן הנכס של היום נשאר קובץ אחד, בית-בבית.
      const fullInstallerSizeToday = 2012390081;
      const githubAssetLimit = 2147483648;
      expect(fullInstallerSizeToday, lessThan(githubAssetLimit));
    });

    test('הערות השחרור מציגות את האשף ככלי עזר ואת החלקים אם יופיעו', () {
      // המסווג ממיר לאותיות קטנות לפני ההשוואה, ולכן הענף נשאר קטן.
      expect(workflow, contains('otzaria-download-assistant-windows.exe)'));
      expect(
        workflow,
        contains(
          'מסייע הורדה — כלי עזר להורדת אוצריא ולהכנת התקנה למחשב ללא '
          'אינטרנט. זהו אינו קובץ ההתקנה עצמו',
        ),
      );

      // הסיווג רגיש לסדר: החלקים חייבים להיתפס לפני *windows-full*.exe.
      final parts = workflow.indexOf('*windows-full.exe.part-*)');
      final support = workflow.indexOf('*windows-full.exe.manifest.json)');
      final fullExe = workflow.indexOf('*windows-full*.exe)');
      expect(parts, greaterThan(0));
      expect(support, greaterThan(0));
      expect(fullExe, greaterThan(parts));
      expect(fullExe, greaterThan(support));
    });
  });
}
