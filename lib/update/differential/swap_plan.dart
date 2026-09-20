/// החוזה בין מנוע העדכון למעדכן העצמאי. נטול תלות ב-Flutter: המעדכן
/// מקומפל ב-`dart compile exe`.
library;

import 'dart:convert';

import 'managed_paths.dart';

/// גרסת הסכמה של תוכנית ההחלפה. מעדכן ישן חייב לדחות תוכנית חדשה יותר.
const int kSwapPlanSchemaVersion = 1;

/// שם קובץ התוכנית בשורש תיקיית העבודה (לצד `staging` ו-`backup`).
const String kSwapPlanFileName = 'swap-plan.json';

/// תוכנית שאינה תקפה. תמיד עוצרת לפני שנגעו בהתקנה.
class SwapPlanException implements Exception {
  SwapPlanException(this.message);
  final String message;
  @override
  String toString() => 'SwapPlanException: $message';
}

Never _invalid(String message) => throw SwapPlanException(message);

/// קובץ אפליקציה שייכתב על ההתקנה.
class SwapFile {
  SwapFile({required this.path, required this.sha256, required this.size});

  final String path;
  final String sha256;
  final int size;

  Map<String, Object?> toJson() => {
    'path': path,
    'sha256': sha256,
    'size': size,
  };
}

/// קובץ אפליקציה שיימחק. ה-hash נבדק לפני המחיקה: קובץ שאינו זהה לקובץ
/// שהמניפסט מתאר אינו נמחק, אלא מפיל את ההחלפה כולה.
class SwapRemoval {
  SwapRemoval({required this.path, required this.sha256});

  final String path;
  final String sha256;

  Map<String, Object?> toJson() => {'path': path, 'sha256': sha256};
}

/// התוכנית המלאה: מה להחליף, על מה להמתין, ולאן לחזור בכישלון.
class SwapPlan {
  SwapPlan({
    required this.platform,
    required this.architecture,
    required this.fromReleaseTag,
    required this.toReleaseTag,
    required this.installRoot,
    required this.stagingRoot,
    required this.backupRoot,
    required this.files,
    required this.removals,
    this.relaunchExecutable,
    this.waitForPid,
    this.waitTimeout = const Duration(minutes: 2),
  });

  final String platform;
  final String architecture;
  final String fromReleaseTag;
  final String toReleaseTag;
  final String installRoot;
  final String stagingRoot;
  final String backupRoot;
  final List<SwapFile> files;
  final List<SwapRemoval> removals;
  final String? relaunchExecutable;
  final int? waitForPid;
  final Duration waitTimeout;

  Map<String, Object?> toJson() => {
    'schemaVersion': kSwapPlanSchemaVersion,
    'platform': platform,
    'architecture': architecture,
    'fromReleaseTag': fromReleaseTag,
    'toReleaseTag': toReleaseTag,
    'installRoot': installRoot,
    'stagingRoot': stagingRoot,
    'backupRoot': backupRoot,
    if (relaunchExecutable != null) 'relaunchExecutable': relaunchExecutable,
    if (waitForPid != null) 'waitForPid': waitForPid,
    'waitTimeoutSeconds': waitTimeout.inSeconds,
    'files': [for (final file in files) file.toJson()],
    'removals': [for (final removal in removals) removal.toJson()],
  };

  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  /// קורא תוכנית ומאמת אותה מחדש. המעדכן לעולם אינו סומך על הכותב:
  /// נתיב שאינו קובץ אפליקציה מנוהל מפיל את הקריאה כאן.
  factory SwapPlan.decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (error) {
      _invalid('the swap plan is not valid JSON: $error');
    }
    if (decoded is! Map) _invalid('the swap plan is not a JSON object');
    final plan = decoded;

    if (plan['schemaVersion'] != kSwapPlanSchemaVersion) {
      _invalid(
        'unsupported swap plan schemaVersion '
        '${plan['schemaVersion']}',
      );
    }

    String requireString(String key) {
      final value = plan[key];
      if (value is! String || value.trim().isEmpty) {
        _invalid('$key must be a non-empty string');
      }
      return value;
    }

    String requireHash(Object? value, String what) {
      if (value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
        _invalid('$what: sha256 must be 64 lowercase hex characters');
      }
      return value;
    }

    final rawFiles = plan['files'];
    final rawRemovals = plan['removals'];
    if (rawFiles is! List) _invalid('files must be a list');
    if (rawRemovals is! List) _invalid('removals must be a list');

    final seen = <String>{};
    final files = <SwapFile>[];
    for (final raw in rawFiles) {
      if (raw is! Map) _invalid('a file entry is not a JSON object');
      final path = raw['path'];
      if (path is! String) _invalid('a file entry has no path');
      final error = managedApplicationPathError(path);
      if (error != null) _invalid('file $path: $error');
      if (!seen.add(path)) _invalid('file $path: duplicate path');
      final size = raw['size'];
      if (size is! int || size < 0) {
        _invalid('file $path: size must be a non-negative integer');
      }
      files.add(
        SwapFile(
          path: path,
          sha256: requireHash(raw['sha256'], 'file $path'),
          size: size,
        ),
      );
    }

    final removals = <SwapRemoval>[];
    for (final raw in rawRemovals) {
      if (raw is! Map) _invalid('a removal is not a JSON object');
      final path = raw['path'];
      if (path is! String) _invalid('a removal has no path');
      final error = managedApplicationPathError(path);
      if (error != null) _invalid('removal $path: $error');
      if (!seen.add(path)) _invalid('removal $path: duplicate path');
      removals.add(
        SwapRemoval(
          path: path,
          sha256: requireHash(raw['sha256'], 'removal $path'),
        ),
      );
    }

    final timeout = plan['waitTimeoutSeconds'];
    if (timeout is! int || timeout <= 0) {
      _invalid('waitTimeoutSeconds must be a positive integer');
    }
    final pid = plan['waitForPid'];
    if (pid != null && pid is! int) _invalid('waitForPid must be an integer');
    final relaunch = plan['relaunchExecutable'];
    if (relaunch != null && relaunch is! String) {
      _invalid('relaunchExecutable must be a string');
    }

    return SwapPlan(
      platform: requireString('platform'),
      architecture: requireString('architecture'),
      fromReleaseTag: requireString('fromReleaseTag'),
      toReleaseTag: requireString('toReleaseTag'),
      installRoot: requireString('installRoot'),
      stagingRoot: requireString('stagingRoot'),
      backupRoot: requireString('backupRoot'),
      files: files,
      removals: removals,
      relaunchExecutable: relaunch as String?,
      waitForPid: pid as int?,
      waitTimeout: Duration(seconds: timeout),
    );
  }
}
