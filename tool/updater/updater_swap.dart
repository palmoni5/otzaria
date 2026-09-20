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
