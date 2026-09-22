/// מחליף את קובצי ההתקנה אחרי שאוצריא יצאה. משוגר עם
/// `CREATE_BREAKAWAY_FROM_JOB`, אחרת ה-Job Object שלה היה הורג אותו.
library;

import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:otzaria/update/differential/swap_plan.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

import 'updater_swap.dart';

/// דגל פנימי: התהליך כבר רץ מהעותק הזמני ואינו צריך להעתיק את עצמו שוב.
const String kFromTempFlag = '--from-temp';

const int kExitSuccess = 0;
const int kExitAborted = 1;
const int kExitCorrupted = 2;
const int kExitUsage = 64;

void main(List<String> args) {
  final planPath = _option(args, '--plan');
  if (planPath == null) {
    stderr.writeln(
      'usage: otzaria_updater --plan <swap-plan.json> [--no-relaunch] '
      '[--recover] [--wait-pid <pid>]',
    );
    exitCode = kExitUsage;
    return;
  }

  if (!args.contains(kFromTempFlag)) {
    // הקובץ שלנו עשוי בעצמו להיות אחד מקובצי ההתקנה שמוחלפים, ולכן
    // ההחלפה חייבת לרוץ מעותק מחוץ לתיקיית ההתקנה.
    exitCode = _relaunchFromTemp(args) ? kExitSuccess : kExitAborted;
    return;
  }

  final planFile = File(planPath);
  final log = _Log(
    p.join(p.dirname(p.dirname(planFile.absolute.path)), 'otzaria-updater.log'),
  );

  final SwapPlan plan;
  try {
    plan = SwapPlan.decode(planFile.readAsStringSync());
  } catch (error) {
    log.write('the swap plan could not be read: $error');
    exitCode = kExitAborted;
    return;
  }

  // המשגר רשאי לדרוס את ה-pid שבתוכנית: בשחזור בעלייה התהליך שבתוכנית מת
  // מזמן, ומי שמחזיק את ההתקנה הוא המופע החדש של אוצריא.
  final pid = _intOption(args, '--wait-pid') ?? plan.waitForPid;
  if (pid != null && !_waitForProcessExit(pid, plan.waitTimeout)) {
    log.write(
      'otzaria (pid $pid) is still running after '
      '${plan.waitTimeout.inSeconds}s - nothing was changed',
    );
    _relaunch(plan, args, log);
    exitCode = kExitAborted;
    return;
  }
  final exitedAt = DateTime.now();

  if (args.contains('--recover')) {
    exitCode = _recover(plan, planFile, log);
    return;
  }

  final result = applySwapPlan(plan);
  log.write(
    'swap ${result.outcome.name}: '
    '${result.installedFiles} file(s) installed'
    '${result.error == null ? '' : ' - ${result.error}'}',
  );
  for (final error in result.rollbackErrors) {
    log.write('rollback error: $error');
  }

  if (result.succeeded) {
    _deleteQuietly(Directory(plan.backupRoot));
    _deleteQuietly(Directory(plan.stagingRoot));
    _deleteQuietly(planFile.parent);
  }
  if (!shouldRelaunchAfterSwap(result.outcome)) {
    final message = corruptedInstallMessage(plan.backupRoot);
    log.write(message.replaceAll('\n', ' '));
    _showErrorBox(message);
    exitCode = kExitCorrupted;
    return;
  }
  _relaunch(plan, args, log, exitedAt: exitedAt);
  exitCode = result.succeeded ? kExitSuccess : kExitAborted;
}

/// משלים או מבטל החלפה שנקטעה, ומנקה אחריה. אינו מפעיל את אוצריא מחדש:
/// הוא רץ כי המשתמש סגר אותה, ולא כי ביקש עדכון עכשיו.
int _recover(SwapPlan plan, File planFile, _Log log) {
  final result = recoverInterruptedSwap(plan);
  log.write(
    'recovery ${result.outcome.name}: ${result.changedFiles} file(s) changed'
    '${result.error == null ? '' : ' - ${result.error}'}',
  );
  if (result.outcome == SwapRecovery.failed) {
    final message = corruptedInstallMessage(plan.backupRoot);
    _showErrorBox(message);
    return kExitCorrupted;
  }
  _deleteQuietly(Directory(plan.backupRoot));
  _deleteQuietly(Directory(plan.stagingRoot));
  _deleteQuietly(planFile.parent);
  return kExitSuccess;
}

/// תיבת הודעה של המערכת. למעדכן אין ממשק משלו, וזו הדרך היחידה שלו
/// להגיע למשתמש.
void _showErrorBox(String message) {
  final text = message.toNativeUtf16();
  final caption = 'עדכון אוצריא'.toNativeUtf16();
  try {
    MessageBox(
      null,
      PCWSTR(text),
      PCWSTR(caption),
      MB_OK | MB_ICONERROR | MB_SETFOREGROUND,
    );
  } finally {
    free(text);
    free(caption);
  }
}

/// מעתיק את עצמו ל-temp ומשגר משם. מחזיר false אם לא הצליח.
bool _relaunchFromTemp(List<String> args) {
  try {
    final temp = Directory.systemTemp.createTempSync('otzaria-updater');
    final self = File(Platform.resolvedExecutable);
    final copy = p.join(temp.path, p.basename(self.path));
    self.copySync(copy);
    Process.start(
      copy,
      [...args, kFromTempFlag],
      mode: ProcessStartMode.detached,
    );
    return true;
  } catch (error) {
    stderr.writeln('could not start the updater from a temp copy: $error');
    return false;
  }
}

/// מפעיל את אוצריא מחדש — אבל רק אם ההחלפה הסתיימה סמוך ליציאתה.
///
/// [exitedAt] הוא הרגע שבו התהליך יצא; החלון הוא `plan.waitTimeout`, אותו
/// גבול שכבר מגדיר כמה זמן העדכון הזה רשאי לקחת. מעבר לו החלון היה נפתח
/// מול משתמש שכבר עבר הלאה — או מול מכונה שנכבית.
void _relaunch(
  SwapPlan plan,
  List<String> args,
  _Log log, {
  DateTime? exitedAt,
}) {
  final executable = plan.relaunchExecutable;
  if (executable == null || args.contains('--no-relaunch')) return;
  if (exitedAt != null &&
      !relaunchWindowStillOpen(
        exitedAt: exitedAt,
        now: DateTime.now(),
        window: plan.waitTimeout,
      )) {
    log.write(
      'the swap finished more than ${plan.waitTimeout.inSeconds}s after '
      'otzaria exited - not relaunching it',
    );
    return;
  }
  try {
    Process.start(executable, const [], mode: ProcessStartMode.detached);
  } catch (error) {
    log.write('could not relaunch $executable: $error');
  }
}

/// ממתין ליציאת התהליך. מחזיר true אם יצא (או שאינו קיים כלל), false
/// בפקיעת הזמן — לעולם לא ממתין ללא גבול.
bool _waitForProcessExit(int pid, Duration timeout) {
  final handle = OpenProcess(PROCESS_SYNCHRONIZE, false, pid).value;
  if (!handle.isValid) return true;
  try {
    return WaitForSingleObject(handle, timeout.inMilliseconds).value ==
        WAIT_OBJECT_0;
  } finally {
    handle.close();
  }
}

void _deleteQuietly(Directory directory) {
  try {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  } catch (_) {
    // שאריות ב-temp אינן מצדיקות כישלון של עדכון שהצליח.
  }
}

String? _option(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}

int? _intOption(List<String> args, String name) {
  final value = _option(args, name);
  return value == null ? null : int.tryParse(value);
}

class _Log {
  _Log(this.path);
  final String path;

  void write(String message) {
    final line = '${DateTime.now().toIso8601String()} $message\n';
    stdout.write(line);
    try {
      File(path).writeAsStringSync(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // לוג אינו תנאי להחלפה.
    }
  }
}
