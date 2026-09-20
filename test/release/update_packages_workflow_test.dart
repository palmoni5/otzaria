import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release/generate_app_file_manifest.dart';
import '../../tool/release/generate_update_package.dart';

void main() {
  final workflow = File(
    '.github/workflows/build-and-announce.yml',
  ).readAsStringSync();
  final script = File(
    'tool/release/build_update_packages.sh',
  ).readAsStringSync();

  int indexOfStep(String name) {
    final at = workflow.indexOf('- name: $name');
    expect(at, greaterThan(-1), reason: 'השלב "$name" אינו ב-workflow');
    return at;
  }

  group('zstd לעדכון המצומצם', () {
    test('מועתק מההורדה הקיימת לתיקיית הבנייה, בלי הורדה שנייה', () {
      final stage = indexOfStep('Stage zstd for small updates (x64)');
      // הבינארי כבר ירד בשביל המתקין המלא — השלב מעתיק אותו בלבד.
      expect(
        workflow.indexOf('- name: Download library assets for full installer'),
        lessThan(stage),
      );
      expect(
        workflow.substring(stage, stage + 900),
        contains(r'Copy-Item installer\zstd.exe'),
      );
      expect(
        'zstd-*-win64.zip'
            .allMatches(
              workflow.substring(
                0,
                workflow.indexOf('\n  build_windows_arm64:'),
              ),
            )
            .length,
        1,
        reason: 'ב-job של x64 יש מקור הורדה אחד ל-zstd',
      );
    });

    test('נכנס גם למתקין וגם ל-ZIP, ולכן גם למניפסט', () {
      final stage = indexOfStep('Stage zstd for small updates (x64)');
      final step = workflow.substring(stage, stage + 900);
      expect(step, contains(r'build\windows\x64\runner\Release\zstd.exe'));
      expect(step, contains('Compress-Archive'));
      expect(step, contains('otzaria-windows.zip'));
      // המתקין נבנה אחרי ההעתקה ואורז את אותה תיקייה.
      expect(stage, lessThan(indexOfStep('Build Inno Setup installer')));
      expect(
        stage,
        lessThan(indexOfStep('Generate application file manifest (x64)')),
      );
    });

    test('ARM64 מקבל את אותו בינארי x64, לפני האריזה', () {
      // אין zstd ל-Windows ARM64 בשחרורי facebook/zstd, ו-Windows on ARM
      // מריץ x64 באמולציה — כמה מגה-בתים לעדכון, האטה חסרת משמעות.
      // הגדרת ה-job, לא הקלט שנושא את אותו שם ב-workflow_dispatch.
      final arm64Job = workflow.substring(
        workflow.indexOf('\n  build_windows_arm64:'),
        workflow.indexOf('\n  build_linux:'),
      );
      expect(arm64Job, contains('zstd-*-win64.zip'));
      expect(
        arm64Job,
        contains(r'build\windows\arm64\runner\Release\zstd.exe'),
      );

      final stage = indexOfStep('Stage zstd for small updates (ARM64)');
      expect(stage, lessThan(indexOfStep('Zip Windows ARM64 build')));
      expect(
        stage,
        lessThan(indexOfStep('Build Inno Setup installer (ARM64)')),
      );
      expect(
        stage,
        lessThan(indexOfStep('Generate application file manifest (ARM64)')),
      );
    });
  });

  group('חותם השחרור בתיקיית ההתקנה', () {
    test('נכתב לתיקיית הבנייה לפני האריזה, בשתי הארכיטקטורות', () {
      for (final (step, dir, arch) in [
        ('Stamp installed release (x64)', r'build\windows\x64', 'x64'),
        ('Stamp installed release (ARM64)', r'build\windows\arm64', 'arm64'),
      ]) {
        final at = indexOfStep(step);
        final body = workflow.substring(at, at + 900);
        expect(body, contains('generate_app_file_manifest.dart --stamp'));
        expect(body, contains('$dir\\runner\\Release'));
        expect(body, contains('--architecture $arch'));
        // התג האמיתי הוא `<version>+<run_number>` — בדיוק מה שהלקוח מחפש.
        expect(body, contains(r'"$version+${{ github.run_number }}"'));
        expect(body, contains('continue-on-error: true'), reason: step);
      }
    });

    test('קודם לאריזה, למתקין ולמניפסט — ולכן נכנס לשלושתם', () {
      final x64 = indexOfStep('Stamp installed release (x64)');
      expect(x64, greaterThan(indexOfStep('Build Flutter Windows app')));
      expect(x64, lessThan(indexOfStep('Zip Windows build')));
      expect(x64, lessThan(indexOfStep('Build Inno Setup installer')));
      expect(
        x64,
        lessThan(indexOfStep('Generate application file manifest (x64)')),
      );

      final arm = indexOfStep('Stamp installed release (ARM64)');
      expect(arm, lessThan(indexOfStep('Zip Windows ARM64 build')));
      expect(arm, lessThan(indexOfStep('Build Inno Setup installer (ARM64)')));
      expect(
        arm,
        lessThan(indexOfStep('Generate application file manifest (ARM64)')),
      );
    });

    test('התג בחותם הוא בדיוק התג שהשחרור מקבל', () {
      // החותם הוא הבסיס שחבילת העדכון נבנית ממנו; תג אחר = אין חבילה בשם.
      expect(workflow, contains(r'tag=$VERSION+${{ github.run_number }}'));
      expect(
        r'"$version+${{ github.run_number }}"'.allMatches(workflow).length,
        4,
        reason: 'חותם ומניפסט, בשתי הארכיטקטורות',
      );
    });

    test('שם החותם זהה לשם שהכלי כותב', () {
      expect(workflow, isNot(contains('otzaria-release-stamp')));
      expect(kInstalledReleaseFileName, 'otzaria-release.json');
    });
  });

  group('חיווט העדכון הדיפרנציאלי ל-CI', () {
    test('מניפסט קובצי ההתקנה נבנה בשני ה-jobs של ווינדוס', () {
      expect(
        workflow,
        contains('tool/release/generate_app_file_manifest.dart'),
      );
      expect(workflow, contains(r'build\windows\x64\runner\Release'));
      expect(workflow, contains(r'build\windows\arm64\runner\Release'));
      expect(workflow, contains('--architecture x64'));
      expect(workflow, contains('--architecture arm64'));
    });

    test('שם הנכס בעבודה זהה לשם שהגנרטור מפיק', () {
      for (final arch in ['x64', 'arm64']) {
        final name = appFileManifestAssetName(
          platform: 'windows',
          architecture: arch,
        );
        expect(workflow, contains(name), reason: arch);
        expect(script, contains('otzaria-app-files-windows-'));
      }
    });

    test('המניפסטים מוכנסים ל-release-files לפני יצירת השחרור', () {
      final stage = indexOfStep('Stage application file manifests');
      expect(stage, greaterThan(indexOfStep('Organize release files')));
      expect(stage, lessThan(indexOfStep('Generate release manifest')));
      expect(stage, lessThan(indexOfStep('Create Release')));
    });

    test('חבילות העדכון נבנות אחרי יצירת השחרור ואינן יכולות להפיל אותו', () {
      final publish = indexOfStep('Publish differential update packages');
      expect(publish, greaterThan(indexOfStep('Create Release')));
      expect(
        workflow.substring(publish, publish + 400),
        contains('continue-on-error: true'),
      );
    });

    test('כל שלב חדש אינו פטאלי', () {
      for (final name in [
        'Generate application file manifest (x64)',
        'Generate application file manifest (ARM64)',
        'Publish differential update packages',
      ]) {
        final at = indexOfStep(name);
        expect(
          workflow.substring(at, at + 300),
          contains('continue-on-error: true'),
          reason: name,
        );
      }
    });

    test('שלבי ההעלאה של היום לא נגעו', () {
      for (final asset in [
        'otzaria-windows-zip',
        'otzaria-windows_arm64.zip',
        'otzaria-windows-installer',
        'otzaria-windows-arm64-installer',
        'otzaria-download-assistant',
        'otzaria-release-manifest.json',
      ]) {
        expect(workflow, contains(asset), reason: asset);
      }
    });

    test('מאגר היעד ומדיניות זוגות הגרסאות מוצהרים במפורש', () {
      expect(
        workflow,
        contains('UPDATE_PACKAGES_REPO: Otzaria/otzaria-updates'),
      );
      expect(workflow, contains('UPDATE_PACKAGES_TOKEN'));
      // הארגומנט האחרון לסקריפט הוא מספר הבסיסים.
      expect(
        workflow,
        contains(
          '"\$arch" "\$RELEASE_TAG" "\$manifest" "\$zip" update-packages '
          '$kUpdateBaseReleaseCount',
        ),
      );
      expect(script, contains('base_count=\${6:-2}'));
    });

    test('הסקריפט מאמת כל חבילה לפני ההעלאה', () {
      expect(script, contains('--verify'));
      expect(script, contains('tool/release/generate_update_package.dart'));
    });

    test('הסקריפט מושך רק ממאגר בארגון Otzaria', () {
      expect(script, contains('UPDATE_PACKAGES_SOURCE_REPO:-Otzaria/otzaria'));
      expect(script, isNot(contains('http://')));
    });
  });
}
