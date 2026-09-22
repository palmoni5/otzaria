import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:otzaria/update/differential/swap_plan.dart';
import 'package:path/path.dart' as p;

/// כל פעולות מערכת הקבצים של ההחלפה, בנקודה אחת, כדי שאפשר יהיה להזריק
/// כשל אמיתי בבדיקות ולבדוק את השחזור.
class SwapFileSystem {
  const SwapFileSystem();

  bool exists(String path) => File(path).existsSync();

  void createParent(String path) =>
      Directory(p.dirname(path)).createSync(recursive: true);

  /// העברה. `rename` נכשל בין כוננים — אז נופלים להעתקה ומחיקה.
  void move(String from, String to) {
    createParent(to);
    try {
      File(from).renameSync(to);
    } on FileSystemException {
      File(from).copySync(to);
      File(from).deleteSync();
    }
  }

  void copy(String from, String to) {
    createParent(to);
    File(from).copySync(to);
  }

  void delete(String path) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }

  int lengthOf(String path) => File(path).lengthSync();

  /// האם תהליך אחר מחזיק את הקובץ. פתיחה לכתיבה (בלי לכתוב דבר) נכשלת
  /// ב-Windows על exe/dll שממופה כתמונת תהליך חי — בדיוק הנעילה שמפילה החלפה.
  bool isHeldByAnotherProcess(String path) {
    try {
      File(path).openSync(mode: FileMode.append).closeSync();
      return false;
    } on FileSystemException {
      return true;
    }
  }

  String hashOf(String path) =>
      sha256.convert(File(path).readAsBytesSync()).toString();
}

enum SwapOutcome { succeeded, abortedBeforeAnyChange, rolledBack, corrupted }

/// תוצאת ההחלפה. [SwapOutcome.corrupted] הוא המצב היחיד שבו ההתקנה אינה
/// שלמה — הוא מדווח את הקבצים שיש לשחזר ידנית מתיקיית הגיבוי.
class SwapResult {
  SwapResult({
    required this.outcome,
    this.error,
    this.installedFiles = 0,
    this.rollbackErrors = const [],
  });

  final SwapOutcome outcome;
  final String? error;
  final int installedFiles;
  final List<String> rollbackErrors;

  bool get succeeded => outcome == SwapOutcome.succeeded;
}

/// התקנה חלקית אסור להפעיל: אוצריא הייתה עולה עם תערובת של שתי גרסאות.
bool shouldRelaunchAfterSwap(SwapOutcome outcome) =>
    outcome != SwapOutcome.corrupted;

/// האם עדיין ראוי להפעיל את אוצריא מחדש אחרי ההחלפה. מי שסגר אותה וכבר
/// עבר הלאה — או מכבה את המחשב — אינו רוצה חלון שנפתח מולו.
bool relaunchWindowStillOpen({
  required DateTime exitedAt,
  required DateTime now,
  required Duration window,
}) => now.difference(exitedAt) <= window;

/// ההודעה שהמשתמש רואה כשההחלפה והשחזור נכשלו שניהם.
String corruptedInstallMessage(String backupRoot) =>
    'העדכון נכשל באמצע, והשחזור האוטומטי לא הצליח. ההתקנה של אוצריא '
    'אינה שלמה כרגע ואין להפעיל אותה.\n\n'
    'הקבצים המקוריים שמורים בתיקייה:\n$backupRoot\n\n'
    'אפשר להעתיק אותם בחזרה לתיקיית ההתקנה, או להתקין את אוצריא מחדש '
    'מהמתקין המלא.';

class _Op {
  _Op.backedUp(this.target, this.backup) : installed = false;
  _Op.installed(this.target) : backup = null, installed = true;

  final String target;
  final String? backup;
  final bool installed;
}

/// מחליף את קובצי ההתקנה בקבצים שב-staging. שום קובץ אינו נמחק: הישן עובר
/// לגיבוי, וכשל בכל שלב מחזיר למקומו את כל מה שכבר הוזז.
SwapResult applySwapPlan(
  SwapPlan plan, {
  SwapFileSystem fs = const SwapFileSystem(),
}) {
  String inInstall(String path) => p.join(plan.installRoot, path);
  String inStaging(String path) => p.join(plan.stagingRoot, path);
  String inBackup(String path) => p.join(plan.backupRoot, path);

  try {
    _preflight(plan, fs, inStaging: inStaging, inInstall: inInstall);
  } catch (error) {
    return SwapResult(
      outcome: SwapOutcome.abortedBeforeAnyChange,
      error: '$error',
    );
  }

  final journal = <_Op>[];
  var installed = 0;
  try {
    for (final file in plan.files) {
      final target = inInstall(file.path);
      if (fs.exists(target)) {
        final backup = inBackup(file.path);
        fs.move(target, backup);
        journal.add(_Op.backedUp(target, backup));
      }
      fs.move(inStaging(file.path), target);
      journal.add(_Op.installed(target));
      installed++;
    }
    for (final removal in plan.removals) {
      final target = inInstall(removal.path);
      if (!fs.exists(target)) continue;
      final backup = inBackup(removal.path);
      fs.move(target, backup);
      journal.add(_Op.backedUp(target, backup));
    }
  } catch (error) {
    final errors = _rollback(journal, fs);
    return SwapResult(
      outcome: errors.isEmpty ? SwapOutcome.rolledBack : SwapOutcome.corrupted,
      error: '$error',
      installedFiles: installed,
      rollbackErrors: errors,
    );
  }
  return SwapResult(outcome: SwapOutcome.succeeded, installedFiles: installed);
}

enum SwapRecovery {
  /// אין עדות להחלפה שנקטעה.
  nothingToDo,

  /// ההחלפה הושלמה — ההתקנה כולה בגרסה החדשה.
  completed,

  /// ההחלפה בוטלה — ההתקנה כולה בגרסה הישנה.
  restored,

  /// לא הושלמה ולא בוטלה. תיקיית הגיבוי נשארת במקומה.
  failed,
}

class SwapRecoveryResult {
  SwapRecoveryResult(this.outcome, {this.error, this.changedFiles = 0});

  final SwapRecovery outcome;
  final String? error;
  final int changedFiles;
}

/// משלים או מבטל החלפה שהמעדכן נהרג באמצעה. המצב נגזר מהדיסק בלבד: קובץ
/// שכבר הותקן זהה ל-hash שבתוכנית, וקובץ שטרם הותקן עדיין יושב ב-staging.
///
/// הכיוון נבחר פעם אחת לכל ההחלפה — קדימה רק כשכל קובץ בתוכנית זמין —
/// ולכן ההתקנה מסתיימת בגרסה אחת שלמה ולא בתערובת.
SwapRecoveryResult recoverInterruptedSwap(
  SwapPlan plan, {
  SwapFileSystem fs = const SwapFileSystem(),
}) {
  String inInstall(String path) => p.join(plan.installRoot, path);
  String inStaging(String path) => p.join(plan.stagingRoot, path);
  String inBackup(String path) => p.join(plan.backupRoot, path);

  if (!Directory(plan.backupRoot).existsSync()) {
    return SwapRecoveryResult(SwapRecovery.nothingToDo);
  }

  bool isInstalled(SwapFile file) {
    final target = inInstall(file.path);
    return fs.exists(target) && fs.hashOf(target) == file.sha256;
  }

  bool isStaged(SwapFile file) {
    final staged = inStaging(file.path);
    return fs.exists(staged) &&
        fs.lengthOf(staged) == file.size &&
        fs.hashOf(staged) == file.sha256;
  }

  var changed = 0;
  try {
    final canComplete = plan.files.every(
      (file) => isInstalled(file) || isStaged(file),
    );

    if (canComplete) {
      for (final file in plan.files) {
        if (isInstalled(file)) continue;
        final target = inInstall(file.path);
        if (fs.exists(target)) fs.move(target, inBackup(file.path));
        fs.move(inStaging(file.path), target);
        changed++;
      }
      for (final removal in plan.removals) {
        final target = inInstall(removal.path);
        if (!fs.exists(target)) continue;
        if (fs.hashOf(target) != removal.sha256) continue;
        fs.move(target, inBackup(removal.path));
        changed++;
      }
      return SwapRecoveryResult(SwapRecovery.completed, changedFiles: changed);
    }

    final byPath = {for (final file in plan.files) file.path: file};
    for (final path in [
      for (final file in plan.files) file.path,
      for (final removal in plan.removals) removal.path,
    ]) {
      final backup = inBackup(path);
      final target = inInstall(path);
      if (fs.exists(backup)) {
        fs.delete(target);
        fs.move(backup, target);
        changed++;
        continue;
      }
      // קובץ שהגרסה החדשה הוסיפה: אין לו גיבוי, וההתקנה הישנה בלעדיו.
      final file = byPath[path];
      if (file != null && isInstalled(file)) {
        fs.delete(target);
        changed++;
      }
    }
    return SwapRecoveryResult(SwapRecovery.restored, changedFiles: changed);
  } catch (error) {
    return SwapRecoveryResult(
      SwapRecovery.failed,
      error: '$error',
      changedFiles: changed,
    );
  }
}

/// כל הבדיקות שאפשר לעשות לפני שנוגעים בהתקנה. כשל כאן משאיר אותה כפי
/// שהייתה בדיוק.
void _preflight(
  SwapPlan plan,
  SwapFileSystem fs, {
  required String Function(String) inStaging,
  required String Function(String) inInstall,
}) {
  if (!Directory(plan.installRoot).existsSync()) {
    throw StateError('the install directory is missing: ${plan.installRoot}');
  }
  if (!Directory(plan.stagingRoot).existsSync()) {
    throw StateError('the staging directory is missing: ${plan.stagingRoot}');
  }
  if (p.equals(plan.backupRoot, plan.installRoot) ||
      p.isWithin(plan.installRoot, plan.backupRoot) ||
      p.isWithin(plan.installRoot, plan.stagingRoot)) {
    throw StateError(
      'the staging and backup directories must be outside '
      'the install directory',
    );
  }
  // עדיף "העדכון לא קרה" על "העדכון בוטל באמצע": קובץ נעול מפיל את ההחלפה
  // בדרכה ומחייב שחזור, וכאן ההתקנה עוד לא נגעה.
  for (final path in [
    for (final file in plan.files) file.path,
    for (final removal in plan.removals) removal.path,
  ]) {
    final target = inInstall(path);
    if (fs.exists(target) && fs.isHeldByAnotherProcess(target)) {
      throw StateError('$path: the file is still held by another process');
    }
  }

  if (Directory(plan.backupRoot).existsSync()) {
    Directory(plan.backupRoot).deleteSync(recursive: true);
  }
  Directory(plan.backupRoot).createSync(recursive: true);

  for (final file in plan.files) {
    final staged = inStaging(file.path);
    if (!fs.exists(staged)) {
      throw StateError('${file.path}: the staged file is missing');
    }
    if (fs.lengthOf(staged) != file.size || fs.hashOf(staged) != file.sha256) {
      throw StateError('${file.path}: the staged file does not match the plan');
    }
  }
  for (final removal in plan.removals) {
    final target = inInstall(removal.path);
    if (!fs.exists(target)) continue;
    if (fs.hashOf(target) != removal.sha256) {
      throw StateError(
        '${removal.path}: the local file is not the file being removed',
      );
    }
  }
}

/// מחזיר את ההתקנה למצבה לפני ההחלפה. מחזיר את השגיאות שנותרו — רשימה
/// ריקה פירושה שהשחזור היה מלא.
List<String> _rollback(List<_Op> journal, SwapFileSystem fs) {
  final errors = <String>[];
  for (final op in journal.reversed) {
    try {
      if (op.installed) {
        fs.delete(op.target);
      } else {
        final backup = op.backup!;
        try {
          fs.move(backup, op.target);
        } on FileSystemException {
          fs.copy(backup, op.target);
        }
      }
    } catch (error) {
      errors.add('${op.target}: $error');
    }
  }
  return errors;
}
