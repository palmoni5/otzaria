import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/update/differential/swap_plan.dart';
import 'package:otzaria/update/differential/swap_recovery.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late Directory work;
  late Directory install;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('otzaria-swap-recovery');
    work = Directory(p.join(temp.path, 'work'))..createSync(recursive: true);
    install = Directory(p.join(temp.path, 'install'))
      ..createSync(recursive: true);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  void writePlan() =>
      File(p.join(work.path, kSwapPlanFileName)).writeAsStringSync('{}');

  void createBackup() =>
      Directory(p.join(work.path, kSwapBackupDirName)).createSync();

  test('בלי תוכנית ובלי גיבוי אין מה לשחזר', () {
    expect(pendingInterruptedSwapPlan(work), isNull);

    writePlan();
    expect(pendingInterruptedSwapPlan(work), isNull);
  });

  test('תוכנית לצד תיקיית גיבוי היא העדות להחלפה שנקטעה', () {
    writePlan();
    createBackup();

    final found = pendingInterruptedSwapPlan(work);
    expect(found, isNotNull);
    expect(p.basename(found!.path), kSwapPlanFileName);
  });

  test('המעדכן משוגר עם ה-pid הנוכחי ובלי הפעלה מחדש', () {
    writePlan();
    createBackup();
    File(p.join(install.path, kUpdaterHelperFileName)).writeAsStringSync('');

    String? launched;
    var passed = const <String>[];
    final ok = requestInterruptedSwapRecovery(
      planFile: pendingInterruptedSwapPlan(work)!,
      installRoot: install,
      waitForPid: 4321,
      launch: (executable, {List<String> arguments = const []}) {
        launched = executable;
        passed = arguments;
        return true;
      },
    );

    expect(ok, isTrue);
    expect(p.basename(launched!), kUpdaterHelperFileName);
    expect(passed, containsAllInOrder(['--wait-pid', '4321']));
    expect(passed, contains('--recover'));
    expect(passed, contains('--no-relaunch'));
    expect(
      passed,
      containsAllInOrder(['--plan', p.join(work.path, kSwapPlanFileName)]),
    );
  });

  test('בלי המעדכן בתיקיית ההתקנה לא משגרים דבר', () {
    writePlan();
    createBackup();

    var launches = 0;
    final ok = requestInterruptedSwapRecovery(
      planFile: pendingInterruptedSwapPlan(work)!,
      installRoot: install,
      waitForPid: 1,
      launch: (executable, {List<String> arguments = const []}) {
        launches++;
        return true;
      },
    );

    expect(ok, isFalse);
    expect(launches, 0);
  });
}
