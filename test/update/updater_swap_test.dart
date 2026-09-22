import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/update/differential/swap_plan.dart';
import 'package:path/path.dart' as p;

import '../../tool/updater/updater_swap.dart';

/// כשל אמיתי באמצע ההחלפה: הקובץ שלא ניתן להזיז (נעול ע"י תהליך אחר).
class _LockedFileSystem extends SwapFileSystem {
  _LockedFileSystem(this.lockedSource);

  final String lockedSource;

  @override
  void move(String from, String to) {
    if (p.basename(from) == lockedSource) {
      throw const FileSystemException('the file is locked by another process');
    }
    super.move(from, to);
  }
}

/// כשל שגם השחזור אינו מתאושש ממנו — ההתקנה נשארת חלקית.
class _UnrecoverableFileSystem extends _LockedFileSystem {
  _UnrecoverableFileSystem(super.lockedSource);

  @override
  void delete(String path) =>
      throw const FileSystemException('the file cannot be removed');
}

/// קובץ יעד שתהליך אחר מחזיק — בלי לנעול קובץ אמיתי במערכת ההפעלה.
class _HeldFileSystem extends SwapFileSystem {
  _HeldFileSystem(this.held);

  final Set<String> held;

  @override
  bool isHeldByAnotherProcess(String path) =>
      held.any((name) => p.basename(path) == p.basename(name));
}

String _hash(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

Map<String, String> _hashTree(Directory root) {
  final hashes = <String, String>{};
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File) continue;
    hashes[p.relative(entity.path, from: root.path).replaceAll('\\', '/')] =
        _hash(entity.path);
  }
  return hashes;
}

void _write(String path, String content) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

void main() {
  late Directory temp;
  late Directory install;
  late Directory staging;
  late Directory backup;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('otzaria-updater-swap');
    install = Directory(p.join(temp.path, 'install'))..createSync();
    staging = Directory(p.join(temp.path, 'work', 'staging'))
      ..createSync(recursive: true);
    backup = Directory(p.join(temp.path, 'work', 'backup'));

    _write(p.join(install.path, 'otzaria.exe'), 'old binary');
    _write(p.join(install.path, 'data', 'a.dat'), 'old a');
    _write(p.join(install.path, 'data', 'b.dat'), 'old b');
    _write(p.join(install.path, 'legacy.dll'), 'obsolete');
    // נתוני משתמש בתוך שורש ההתקנה — מצב נייד.
    _write(p.join(install.path, 'otzaria_data', 'settings.hive'), 'mine');

    _write(p.join(staging.path, 'otzaria.exe'), 'new binary');
    _write(p.join(staging.path, 'data', 'a.dat'), 'new a');
    _write(p.join(staging.path, 'data', 'b.dat'), 'new b');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  SwapPlan plan({List<SwapRemoval>? removals}) => SwapPlan(
    platform: 'windows',
    architecture: 'x64',
    fromReleaseTag: '0.9.97+100',
    toReleaseTag: '0.9.97+101',
    installRoot: install.path,
    stagingRoot: staging.path,
    backupRoot: backup.path,
    files: [
      for (final path in const ['otzaria.exe', 'data/a.dat', 'data/b.dat'])
        SwapFile(
          path: path,
          sha256: _hash(p.join(staging.path, path)),
          size: File(p.join(staging.path, path)).lengthSync(),
        ),
    ],
    removals:
        removals ??
        [
          SwapRemoval(
            path: 'legacy.dll',
            sha256: _hash(p.join(install.path, 'legacy.dll')),
          ),
        ],
  );

  test('החלפה מוצלחת כותבת את הקבצים החדשים ומסירה את המיושן', () {
    final result = applySwapPlan(plan());

    expect(result.outcome, SwapOutcome.succeeded);
    expect(result.installedFiles, 3);
    expect(
      File(p.join(install.path, 'otzaria.exe')).readAsStringSync(),
      'new binary',
    );
    expect(
      File(p.join(install.path, 'data', 'b.dat')).readAsStringSync(),
      'new b',
    );
    expect(File(p.join(install.path, 'legacy.dll')).existsSync(), isFalse);
    // הקובץ שהוסר שמור בגיבוי ולא נמחק לצמיתות בשלב הזה.
    expect(File(p.join(backup.path, 'legacy.dll')).existsSync(), isTrue);
  });

  test('נתוני המשתמש בשורש ההתקנה אינם נוגעים בהחלפה', () {
    final userFile = p.join(install.path, 'otzaria_data', 'settings.hive');
    applySwapPlan(plan());
    expect(File(userFile).readAsStringSync(), 'mine');
  });

  test('כשל באמצע ההחלפה משחזר את ההתקנה בית-בית', () {
    final before = _hashTree(install);

    final result = applySwapPlan(
      plan(),
      fs: _LockedFileSystem('b.dat'),
    );

    expect(result.outcome, SwapOutcome.rolledBack);
    expect(result.rollbackErrors, isEmpty);
    expect(result.error, contains('locked'));
    expect(_hashTree(install), before);
    expect(
      File(p.join(install.path, 'otzaria.exe')).readAsStringSync(),
      'old binary',
    );
    expect(File(p.join(install.path, 'legacy.dll')).existsSync(), isTrue);
  });

  test('כשל גם בשחזור: corrupted, עם מניין הקבצים שכבר הוחלפו', () {
    final result = applySwapPlan(
      plan(),
      fs: _UnrecoverableFileSystem('b.dat'),
    );

    expect(result.outcome, SwapOutcome.corrupted);
    expect(result.rollbackErrors, isNotEmpty);
    // שני הקבצים הראשונים כבר הותקנו לפני שהשלישי נכשל — בלעדיהם הלוג
    // אינו מראה כמה רחוק הגיעה ההחלפה.
    expect(result.installedFiles, 2);
  });

  test('התקנה חלקית אינה מופעלת מחדש, והמשתמש מקבל את נתיב הגיבוי', () {
    expect(shouldRelaunchAfterSwap(SwapOutcome.corrupted), isFalse);
    for (final outcome in [
      SwapOutcome.succeeded,
      SwapOutcome.rolledBack,
      SwapOutcome.abortedBeforeAnyChange,
    ]) {
      expect(shouldRelaunchAfterSwap(outcome), isTrue);
    }
    expect(corruptedInstallMessage(backup.path), contains(backup.path));
  });

  test('קובץ להסרה שאינו זהה למניפסט עוצר לפני כל שינוי', () {
    final built = plan();
    _write(p.join(install.path, 'legacy.dll'), 'the user replaced this');
    final before = _hashTree(install);

    final result = applySwapPlan(built);

    expect(result.outcome, SwapOutcome.abortedBeforeAnyChange);
    expect(_hashTree(install), before);
  });

  test('קובץ staging שאינו תואם את התוכנית עוצר לפני כל שינוי', () {
    final built = plan();
    _write(p.join(staging.path, 'data', 'a.dat'), 'tampered');
    final before = _hashTree(install);

    final result = applySwapPlan(built);

    expect(result.outcome, SwapOutcome.abortedBeforeAnyChange);
    expect(_hashTree(install), before);
  });

  test('תיקיית גיבוי בתוך ההתקנה נדחית', () {
    final inside = SwapPlan(
      platform: 'windows',
      architecture: 'x64',
      fromReleaseTag: 'a',
      toReleaseTag: 'b',
      installRoot: install.path,
      stagingRoot: staging.path,
      backupRoot: p.join(install.path, 'backup-inside'),
      files: const [],
      removals: const [],
    );
    expect(
      applySwapPlan(inside).outcome,
      SwapOutcome.abortedBeforeAnyChange,
    );
  });

  group('קובץ נעול', () {
    test('החלפה נדחית לפני כל שינוי כשקובץ יעד מוחזק', () {
      final before = _hashTree(install);

      final result = applySwapPlan(plan(), fs: _HeldFileSystem({'data/a.dat'}));

      expect(result.outcome, SwapOutcome.abortedBeforeAnyChange);
      expect(result.error, contains('held by another process'));
      expect(_hashTree(install), before);
      // ההחלפה נדחתה, ולכן גם אין ממה להתאושש.
      expect(backup.existsSync(), isFalse);
    });

    test('קובץ שנועד להסרה ומוחזק דוחה אף הוא', () {
      final result = applySwapPlan(plan(), fs: _HeldFileSystem({'legacy.dll'}));
      expect(result.outcome, SwapOutcome.abortedBeforeAnyChange);
    });
  });

  group('שחזור החלפה שנקטעה', () {
    /// מדמה מעדכן שנהרג אחרי שהחליף את `otzaria.exe` בלבד.
    SwapPlan halfApplied() {
      final built = plan();
      backup.createSync(recursive: true);
      File(
        p.join(install.path, 'otzaria.exe'),
      ).renameSync(p.join(backup.path, 'otzaria.exe'));
      File(
        p.join(staging.path, 'otzaria.exe'),
      ).renameSync(p.join(install.path, 'otzaria.exe'));
      return built;
    }

    test('ללא עדות להחלפה שנקטעה לא נוגעים בדבר', () {
      final before = _hashTree(install);
      final result = recoverInterruptedSwap(plan());

      expect(result.outcome, SwapRecovery.nothingToDo);
      expect(_hashTree(install), before);
    });

    test('כל הקבצים זמינים — ההתקנה מושלמת לגרסה החדשה', () {
      final result = recoverInterruptedSwap(halfApplied());

      expect(result.outcome, SwapRecovery.completed);
      expect(
        File(p.join(install.path, 'otzaria.exe')).readAsStringSync(),
        'new binary',
      );
      expect(
        File(p.join(install.path, 'data', 'a.dat')).readAsStringSync(),
        'new a',
      );
      expect(
        File(p.join(install.path, 'data', 'b.dat')).readAsStringSync(),
        'new b',
      );
      expect(File(p.join(install.path, 'legacy.dll')).existsSync(), isFalse);
      expect(
        File(
          p.join(install.path, 'otzaria_data', 'settings.hive'),
        ).readAsStringSync(),
        'mine',
      );
    });

    test('קובץ staging חסר — ההתקנה חוזרת כולה לגרסה הישנה', () {
      final built = halfApplied();
      File(p.join(staging.path, 'data', 'b.dat')).deleteSync();

      final result = recoverInterruptedSwap(built);

      expect(result.outcome, SwapRecovery.restored);
      expect(
        File(p.join(install.path, 'otzaria.exe')).readAsStringSync(),
        'old binary',
      );
      expect(
        File(p.join(install.path, 'data', 'a.dat')).readAsStringSync(),
        'old a',
      );
      expect(File(p.join(install.path, 'legacy.dll')).existsSync(), isTrue);
    });

    test('קובץ חדש שאין לו גיבוי מוסר בביטול', () {
      _write(p.join(staging.path, 'brandnew.dll'), 'brand new');
      final built = SwapPlan(
        platform: 'windows',
        architecture: 'x64',
        fromReleaseTag: '0.9.97+100',
        toReleaseTag: '0.9.97+101',
        installRoot: install.path,
        stagingRoot: staging.path,
        backupRoot: backup.path,
        files: [
          for (final path in const ['brandnew.dll', 'data/b.dat'])
            SwapFile(
              path: path,
              sha256: _hash(p.join(staging.path, path)),
              size: File(p.join(staging.path, path)).lengthSync(),
            ),
        ],
        removals: const [],
      );
      backup.createSync(recursive: true);
      File(
        p.join(staging.path, 'brandnew.dll'),
      ).renameSync(p.join(install.path, 'brandnew.dll'));
      File(p.join(staging.path, 'data', 'b.dat')).deleteSync();

      final result = recoverInterruptedSwap(built);

      expect(result.outcome, SwapRecovery.restored);
      expect(File(p.join(install.path, 'brandnew.dll')).existsSync(), isFalse);
      expect(
        File(p.join(install.path, 'data', 'b.dat')).readAsStringSync(),
        'old b',
      );
    });

    test('נתוני המשתמש אינם נוגעים בביטול ההחלפה', () {
      final built = halfApplied();
      File(p.join(staging.path, 'data', 'b.dat')).deleteSync();

      recoverInterruptedSwap(built);

      expect(
        File(
          p.join(install.path, 'otzaria_data', 'settings.hive'),
        ).readAsStringSync(),
        'mine',
      );
    });

    test('כשל בשחזור אינו מוחק את הגיבוי', () {
      final built = halfApplied();
      File(p.join(staging.path, 'data', 'b.dat')).deleteSync();

      final result = recoverInterruptedSwap(
        built,
        fs: _LockedFileSystem('otzaria.exe'),
      );

      expect(result.outcome, SwapRecovery.failed);
      expect(File(p.join(backup.path, 'otzaria.exe')).existsSync(), isTrue);
    });
  });

  group('חלון ההפעלה מחדש', () {
    test('פתוח מיד אחרי היציאה, סגור אחרי שחלף', () {
      final exitedAt = DateTime(2026, 1, 1, 12);
      const window = Duration(minutes: 2);

      expect(
        relaunchWindowStillOpen(
          exitedAt: exitedAt,
          now: exitedAt.add(const Duration(seconds: 30)),
          window: window,
        ),
        isTrue,
      );
      expect(
        relaunchWindowStillOpen(
          exitedAt: exitedAt,
          now: exitedAt.add(const Duration(minutes: 20)),
          window: window,
        ),
        isFalse,
      );
    });
  });

  group('תוכנית ההחלפה', () {
    test('round-trip שומר על כל השדות', () {
      final decoded = SwapPlan.decode(plan().encode());
      expect(decoded.files.map((f) => f.path), [
        'otzaria.exe',
        'data/a.dat',
        'data/b.dat',
      ]);
      expect(decoded.removals.single.path, 'legacy.dll');
      expect(decoded.installRoot, install.path);
      expect(decoded.waitTimeout, const Duration(minutes: 2));
    });

    test('נתיב נתוני משתמש בתוכנית נדחה בקריאה', () {
      final tampered = plan().encode().replaceFirst(
        '"legacy.dll"',
        '"otzaria_data/settings.hive"',
      );
      expect(
        () => SwapPlan.decode(tampered),
        throwsA(isA<SwapPlanException>()),
      );
    });

    test('נתיב מוחלט בתוכנית נדחה בקריאה', () {
      final tampered = plan().encode().replaceFirst(
        '"legacy.dll"',
        '"C:/Windows/System32/kernel32.dll"',
      );
      expect(
        () => SwapPlan.decode(tampered),
        throwsA(isA<SwapPlanException>()),
      );
    });
  });
}
