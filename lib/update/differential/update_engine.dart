import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'swap_plan.dart';
import 'update_package.dart';
import 'zstd_runner.dart';

/// מה ייעשה עם ערך אחד של החבילה.
enum UpdateFileAction {
  /// הקובץ המקומי כבר בתוכן החדש — לא יורד, לא נפרס, לא מוחלף.
  alreadyUpToDate,

  /// הקובץ המקומי זהה-בית לבסיס ה-patch — ה-patch יוחל עליו.
  applyPatch,

  /// ייכתב הקובץ המלא הדחוס. אינו תלוי כלל בתוכן המקומי.
  writeFull,

  /// ה-patch אינו ישים כאן — הקובץ יושלם מחבילת הקבצים המלאים.
  fromFallbackPackage,
}

/// מביא את חבילת הקבצים המלאים. נקרא **רק** כשערך אחד לפחות נכשל, כדי
/// שעדכון שכל ה-patch שלו הוחל לא יוריד אותה כלל.
typedef FallbackPackageResolver = Future<File> Function();

/// החלטה לערך אחד.
class UpdateStep {
  UpdateStep(this.entry, this.action);

  final UpdatePackageEntry entry;
  final UpdateFileAction action;
}

/// תכנית העדכון: מה לעשות בכל ערך, ואילו קבצים להסיר.
class UpdatePlan {
  UpdatePlan({
    required this.manifest,
    required this.steps,
    required this.removals,
  });

  final UpdatePackageManifest manifest;
  final List<UpdateStep> steps;
  final List<ManagedRemoval> removals;

  Iterable<UpdateStep> get work =>
      steps.where((step) => step.action != UpdateFileAction.alreadyUpToDate);

  /// כמה בתים יש לפרוס בפועל. ערך שכבר מעודכן אינו נספר.
  int get payloadBytes =>
      work.fold(0, (sum, step) => sum + step.entry.entrySize);
}

/// עדכון שנבנה במלואו ב-staging ואומת מול המניפסט. ההתקנה החיה עדיין
/// לא נגעה — ההחלפה היא תפקידו של המעדכן העצמאי.
class StagedUpdate {
  StagedUpdate({
    required this.manifest,
    required this.installRoot,
    required this.stagingRoot,
    required this.backupRoot,
    required this.workRoot,
    required this.files,
    required this.removals,
  });

  final UpdatePackageManifest manifest;
  final Directory installRoot;
  final Directory stagingRoot;
  final Directory backupRoot;
  final Directory workRoot;
  final List<SwapFile> files;
  final List<SwapRemoval> removals;

  File get swapPlanFile => File(p.join(workRoot.path, kSwapPlanFileName));

  /// כותב את תוכנית ההחלפה שהמעדכן העצמאי מקבל כארגומנט.
  Future<File> writeSwapPlan({
    String? relaunchExecutable,
    int? waitForPid,
    Duration waitTimeout = const Duration(minutes: 2),
  }) async {
    final plan = SwapPlan(
      platform: manifest.platform,
      architecture: manifest.architecture,
      fromReleaseTag: manifest.fromReleaseTag,
      toReleaseTag: manifest.toReleaseTag,
      installRoot: installRoot.absolute.path,
      stagingRoot: stagingRoot.absolute.path,
      backupRoot: backupRoot.absolute.path,
      files: files,
      removals: removals,
      relaunchExecutable: relaunchExecutable,
      waitForPid: waitForPid,
      waitTimeout: waitTimeout,
    );
    final file = swapPlanFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(plan.encode());
    return file;
  }

  /// מוחק את כל תוצרי ההכנה. בטוח לקרוא גם אחרי החלפה מוצלחת.
  Future<void> discard() async {
    if (await workRoot.exists()) await workRoot.delete(recursive: true);
  }
}

/// מחשב את sha256 של קובץ בזרימה, בלי להחזיק אותו בזיכרון.
Future<String> sha256OfFile(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}

/// בונה מחבילה את קבוצת הקבצים החדשה בתיקיית עבודה נפרדת — לעולם לא
/// בהתקנה החיה. כל כשל הוא [DifferentialUpdateUnavailable].
class DifferentialUpdateEngine {
  DifferentialUpdateEngine({
    required this.installRoot,
    required this.workRoot,
    required this.platform,
    required this.architecture,
    required this.installedReleaseTag,
    this.zstd = const ZstdRunner.bundled(),
  });

  final Directory installRoot;

  /// תיקיית העבודה (staging + backup). חייבת להיות מחוץ להתקנה.
  final Directory workRoot;

  final String platform;
  final String architecture;
  final String installedReleaseTag;
  final ZstdRunner zstd;

  Directory get stagingRoot => Directory(p.join(workRoot.path, 'staging'));
  Directory get backupRoot => Directory(p.join(workRoot.path, 'backup'));

  /// המסלול המלא. [fallbackPackage] מביא את חבילת הקבצים המלאים, ונקרא
  /// רק אם ערך כלשהו בחבילת ה-patch לא ניתן להחלה.
  Future<StagedUpdate> prepare(
    File packageFile, {
    FallbackPackageResolver? fallbackPackage,
  }) async {
    final package = await UpdatePackage.open(packageFile);
    return stage(
      package,
      await planFor(package),
      fallbackPackage: fallbackPackage,
    );
  }

  /// בודק התאמת יעד וגרסת בסיס, ומסווג כל ערך לפי הקובץ המקומי.
  Future<UpdatePlan> planFor(UpdatePackage package) async {
    final manifest = package.manifest;
    if (manifest.platform != platform ||
        manifest.architecture != architecture) {
      throw DifferentialUpdateUnavailable(
        UpdateAbortReason.targetMismatch,
        'the package targets ${manifest.platform}/${manifest.architecture} '
        'but the install is $platform/$architecture',
      );
    }
    if (manifest.fromReleaseTag != installedReleaseTag) {
      throw DifferentialUpdateUnavailable(
        UpdateAbortReason.baseVersionMismatch,
        'the package upgrades from ${manifest.fromReleaseTag} '
        'but the install is $installedReleaseTag',
      );
    }
    if (!await installRoot.exists()) {
      throw DifferentialUpdateUnavailable(
        UpdateAbortReason.environment,
        'the install directory does not exist: ${installRoot.path}',
      );
    }
    _requireSeparateWorkRoot();

    final steps = <UpdateStep>[];
    for (final entry in manifest.entries) {
      final local = File(p.join(installRoot.path, entry.path));
      final localHash = await local.exists() ? await sha256OfFile(local) : null;

      if (localHash == entry.newSha256) {
        steps.add(UpdateStep(entry, UpdateFileAction.alreadyUpToDate));
        continue;
      }
      if (!entry.isPatch) {
        steps.add(UpdateStep(entry, UpdateFileAction.writeFull));
        continue;
      }
      if (localHash == entry.oldSha256) {
        steps.add(UpdateStep(entry, UpdateFileAction.applyPatch));
        continue;
      }
      // ה-patch הוא אופטימיזציה: קובץ מקומי שאינו הבסיס שלו אינו מפיל את
      // העדכון אלא מושלם מחבילת הקבצים המלאים.
      steps.add(UpdateStep(entry, UpdateFileAction.fromFallbackPackage));
    }
    return UpdatePlan(
      manifest: manifest,
      steps: steps,
      removals: manifest.removals,
    );
  }

  /// בונה ומאמת כל קובץ ב-staging. ערך שאי אפשר להחיל נדחה לחבילת
  /// הקבצים המלאים, שנטענת רק אם נדרשה בפועל.
  Future<StagedUpdate> stage(
    UpdatePackage package,
    UpdatePlan plan, {
    FallbackPackageResolver? fallbackPackage,
  }) async {
    _requireSeparateWorkRoot();
    if (!await zstd.isAvailable) {
      throw DifferentialUpdateUnavailable(
        UpdateAbortReason.environment,
        'zstd is not available, so the package cannot be unpacked',
      );
    }

    final staging = stagingRoot;
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    final scratch = Directory(p.join(workRoot.path, 'scratch'));
    if (await scratch.exists()) await scratch.delete(recursive: true);
    await scratch.create(recursive: true);

    final payloadFile = File(p.join(scratch.path, 'payload.bin'));
    final files = <SwapFile>[];
    final deferred = <UpdatePackageEntry>[];
    try {
      for (final step in plan.work) {
        final entry = step.entry;
        if (step.action == UpdateFileAction.fromFallbackPackage) {
          deferred.add(entry);
          continue;
        }
        try {
          await _writeEntry(
            package: package,
            entry: entry,
            action: step.action,
            payloadFile: payloadFile,
            staging: staging,
          );
        } on DifferentialUpdateUnavailable catch (error) {
          if (!_isRecoverableEntryFailure(error.reason)) rethrow;
          // חצי קובץ ב-staging היה עובר את סריקת הסיום כאילו נכתב.
          final partial = File(p.join(staging.path, entry.path));
          if (await partial.exists()) await partial.delete();
          deferred.add(entry);
          continue;
        }
        files.add(
          SwapFile(
            path: entry.path,
            sha256: entry.newSha256,
            size: entry.newSize,
          ),
        );
      }

      if (deferred.isNotEmpty) {
        files.addAll(
          await _completeFromFallback(
            deferred: deferred,
            manifest: plan.manifest,
            fallbackPackage: fallbackPackage,
            payloadFile: payloadFile,
            staging: staging,
          ),
        );
      }

      await _verifyStaging(staging, files);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    } finally {
      if (await scratch.exists()) await scratch.delete(recursive: true);
    }

    return StagedUpdate(
      manifest: plan.manifest,
      installRoot: installRoot,
      stagingRoot: staging,
      backupRoot: backupRoot,
      workRoot: workRoot,
      files: files,
      removals: [
        for (final removal in plan.removals)
          SwapRemoval(path: removal.path, sha256: removal.oldSha256),
      ],
    );
  }

  /// כותב ערך אחד ל-staging ומאמת אותו מיד מול המניפסט. האימות המיידי הוא
  /// מה שמאפשר לדחות דווקא את הערך שנכשל לחבילת הקבצים המלאים.
  Future<void> _writeEntry({
    required UpdatePackage package,
    required UpdatePackageEntry entry,
    required UpdateFileAction action,
    required File payloadFile,
    required Directory staging,
  }) async {
    await payloadFile.writeAsBytes(package.payloadOf(entry), flush: true);
    final target = File(p.join(staging.path, entry.path));
    await target.parent.create(recursive: true);

    if (action == UpdateFileAction.applyPatch) {
      await zstd.applyPatch(
        base: File(p.join(installRoot.path, entry.path)),
        patch: payloadFile,
        output: target,
      );
    } else {
      await zstd.decompress(input: payloadFile, output: target);
    }
    await _verifyStagedFile(
      target,
      path: entry.path,
      sha256: entry.newSha256,
      size: entry.newSize,
    );
  }

  /// כשל בערך בודד שראוי להשלמה מחבילת הקבצים המלאים. כשל סביבה
  /// (zstd חסר, דיסק מלא) אינו כזה — הורדה נוספת רק תיכשל גם היא.
  bool _isRecoverableEntryFailure(UpdateAbortReason reason) =>
      reason == UpdateAbortReason.packageCorrupt ||
      reason == UpdateAbortReason.localFileUnusable ||
      reason == UpdateAbortReason.stagingVerificationFailed;

  /// משלים את הערכים שנדחו מתוך חבילת הקבצים המלאים. כשל כאן הוא סוף
  /// המסלול הדיפרנציאלי — אין נסיגה שנייה.
  Future<List<SwapFile>> _completeFromFallback({
    required List<UpdatePackageEntry> deferred,
    required UpdatePackageManifest manifest,
    required FallbackPackageResolver? fallbackPackage,
    required File payloadFile,
    required Directory staging,
  }) async {
    if (fallbackPackage == null) {
      throw DifferentialUpdateUnavailable(
        UpdateAbortReason.fallbackUnavailable,
        '${deferred.length} file(s) need the full-files package, which was '
        'not offered',
      );
    }
    final File file;
    try {
      file = await fallbackPackage();
    } catch (error) {
      throw DifferentialUpdateUnavailable(
        UpdateAbortReason.fallbackUnavailable,
        'the full-files package could not be fetched: $error',
      );
    }

    final fallback = await UpdatePackage.open(file);
    final fallbackManifest = fallback.manifest;
    if (fallbackManifest.kind != UpdatePackageKind.full ||
        fallbackManifest.platform != manifest.platform ||
        fallbackManifest.architecture != manifest.architecture ||
        fallbackManifest.fromReleaseTag != manifest.fromReleaseTag ||
        fallbackManifest.toReleaseTag != manifest.toReleaseTag) {
      throw DifferentialUpdateUnavailable(
        UpdateAbortReason.fallbackUnavailable,
        'the full-files package does not match the patch package',
      );
    }

    final byPath = {
      for (final entry in fallbackManifest.entries) entry.path: entry,
    };
    final files = <SwapFile>[];
    for (final wanted in deferred) {
      final entry = byPath[wanted.path];
      if (entry == null || entry.newSha256 != wanted.newSha256) {
        throw DifferentialUpdateUnavailable(
          UpdateAbortReason.fallbackUnavailable,
          '${wanted.path}: the full-files package has no matching copy',
        );
      }
      await _writeEntry(
        package: fallback,
        entry: entry,
        action: UpdateFileAction.writeFull,
        payloadFile: payloadFile,
        staging: staging,
      );
      files.add(
        SwapFile(
          path: entry.path,
          sha256: entry.newSha256,
          size: entry.newSize,
        ),
      );
    }
    return files;
  }

  Future<void> _verifyStagedFile(
    File staged, {
    required String path,
    required String sha256,
    required int size,
  }) async {
    if (!await staged.exists()) {
      throw DifferentialUpdateUnavailable(
        UpdateAbortReason.stagingVerificationFailed,
        '$path: the staged file is missing',
      );
    }
    if (await staged.length() != size || await sha256OfFile(staged) != sha256) {
      throw DifferentialUpdateUnavailable(
        UpdateAbortReason.stagingVerificationFailed,
        '$path: the staged file does not match the manifest',
      );
    }
  }

  /// סריקה סופית: כל קובץ ב-staging קיים, בגודל ובתוכן שהמניפסט מתאר.
  Future<void> _verifyStaging(Directory staging, List<SwapFile> files) async {
    for (final file in files) {
      await _verifyStagedFile(
        File(p.join(staging.path, file.path)),
        path: file.path,
        sha256: file.sha256,
        size: file.size,
      );
    }
  }

  /// תיקיית העבודה בתוך ההתקנה הייתה הופכת את גיבוי ההחלפה לחלק ממה
  /// שמוחלף. שתי התיקיות חייבות להיות נפרדות לחלוטין.
  void _requireSeparateWorkRoot() {
    final install = p.canonicalize(installRoot.absolute.path);
    final work = p.canonicalize(workRoot.absolute.path);
    if (p.equals(install, work) ||
        p.isWithin(install, work) ||
        p.isWithin(work, install)) {
      throw DifferentialUpdateUnavailable(
        UpdateAbortReason.environment,
        'the work directory must be outside the install directory',
      );
    }
  }
}
