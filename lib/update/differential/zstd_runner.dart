import 'dart:io';

import 'package:path/path.dart' as p;

import 'update_package.dart';

/// חלון 2GB — חייב להיות זהה לזה שבו נבנה ה-patch
/// (`tool/release/generate_update_package.dart`), אחרת הפענוח מסרב.
const String kZstdLongWindow = '--long=31';

/// מריץ את ה-CLI של zstd. מוזרק למנוע כדי שאפשר יהיה להחליפו בבדיקות
/// ובפלטפורמות שבהן הבינארי מגיע ממקום אחר.
class ZstdRunner {
  const ZstdRunner({this.executable = 'zstd'});

  /// ה-zstd שנארז לצד קובץ ההרצה. בבנייה שאין בו, המסלול הדיפרנציאלי
  /// מדווח שאינו זמין והעדכון נשאר המתקין המלא.
  const ZstdRunner.bundled() : executable = '';

  final String executable;

  /// הנתיב שיורץ בפועל. ריק = הבינארי הארוז.
  String get resolvedExecutable =>
      executable.isNotEmpty ? executable : bundledZstdPath();

  /// הנתיב לבינארי הארוז ליד קובץ ההרצה.
  static String bundledZstdPath() => Platform.isWindows
      ? p.join(p.dirname(Platform.resolvedExecutable), 'zstd.exe')
      : 'zstd';

  Future<bool> get isAvailable async {
    final path = resolvedExecutable;
    // בדיקת קיום לפני יצירת תהליך: בבנייה בלי zstd ארוז זה החיסכון
    // היחיד מהפעלת תהליך שנכשל בכל בדיקת עדכון.
    if (p.isAbsolute(path) && !File(path).existsSync()) return false;
    try {
      final result = await Process.run(path, const ['--version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  /// פורס קובץ דחוס מלא.
  Future<void> decompress({required File input, required File output}) => _run([
    '-q',
    '-d',
    '--force',
    '-o',
    output.path,
    input.path,
  ], 'decompress ${input.path}');

  /// מחיל patch על [base]. [base] חייב להיות זהה-בית לקובץ שממנו נבנה.
  Future<void> applyPatch({
    required File base,
    required File patch,
    required File output,
  }) => _run([
    '-q',
    '-d',
    kZstdLongWindow,
    '--patch-from=${base.path}',
    '--force',
    '-o',
    output.path,
    patch.path,
  ], 'apply patch to ${base.path}');

  Future<void> _run(List<String> args, String what) async {
    final ProcessResult result;
    try {
      result = await Process.run(resolvedExecutable, args);
    } on ProcessException catch (error) {
      throw DifferentialUpdateUnavailable(
        UpdateAbortReason.environment,
        'zstd could not be started to $what: ${error.message}',
      );
    }
    if (result.exitCode != 0) {
      throw DifferentialUpdateUnavailable(
        UpdateAbortReason.packageCorrupt,
        'zstd failed to $what (exit ${result.exitCode}): ${result.stderr}',
      );
    }
  }
}
