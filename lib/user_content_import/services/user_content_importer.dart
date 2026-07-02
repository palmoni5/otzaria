import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/user_content_import/models/user_import_models.dart';
import 'package:otzaria/user_content_import/repository/user_content_repository.dart';
import 'package:otzaria/user_content_import/services/user_import_parser.dart';
import 'package:otzaria/user_content_import/services/user_link_ref_resolver.dart';

/// תוצאת ייבוא נתוני-משתמש מקבצים: ספירות + שגיאות מרוכזות (עם הקשר קובץ).
class UserImportResult {
  final int generationsApplied;
  final int linksApplied;
  final int booksWithLinks;
  final List<String> errors;

  const UserImportResult({
    this.generationsApplied = 0,
    this.linksApplied = 0,
    this.booksWithLinks = 0,
    this.errors = const [],
  });

  bool get hasAny =>
      generationsApplied > 0 || linksApplied > 0 || errors.isNotEmpty;
}

/// קולט קבצי CSV/JSON שהמשתמש בחר ידנית, וכותב את הדורות והקישורים
/// ל-user_books.db לצמיתות. הייבוא מצטבר: דור דורס דור קודם לאותו ספר,
/// וקישור דורס קישור זהה (ראה [UserContentRepository.upsertUserLink]).
/// מחיקה אינה נגזרת מהקבצים — לאיפוס משמשת פעולת "נקה הכל".
///
/// סוג כל קובץ נקבע משמו:
/// - `דורות.csv` / `generations.csv` — דורות (עמודות: ספר, דור).
/// - `קישורים.csv|json` / `links.csv|json` — קישורים רוחביים (עם ספר_מקור).
/// - `<שם הספר>.links.csv` / `<שם הספר>.links.json` — קישורים לספר בודד.
///
/// קובץ קישורים ב-JSON הוא מערך אובייקטים באותה סמנטיקה כמו ה-CSV
/// (ראה [UserImportParser.parseLinksJson]).
class UserContentImporter {
  static const _generationFileNames = {'דורות.csv', 'generations.csv'};
  static const _folderLinkFileNames = {
    'קישורים.csv',
    'links.csv',
    'קישורים.json',
    'links.json',
  };

  /// ייבוא של קבצים נבחרים כפעולה אחת אטומית: מפענח את כולם, וכל שגיאה
  /// (פענוח, ספר-לא-נמצא, או כתובת-יעד שלא נפתרה) חוסמת כתיבה כלשהי — לא
  /// כותבים חלקית, כך שטעות לא תפגע בנתונים קיימים. אם אין שגיאות — מיישם
  /// בדריסה מצטברת. [resolveRef] מאפשר הזרקת פותר-כתובות לבדיקות.
  static Future<UserImportResult> importFiles(
    Iterable<String> filePaths,
    MyDatabase userDb, {
    UserLinkRefResolver resolveRef = resolveUserLinkTargetLine,
    UserLinkSourceChecker sourceExists = userLinkSourceBookExists,
  }) async {
    final repo = UserContentRepository(userDb);
    final errors = <String>[];

    // bookId → שם דור (אחרון מנצח); רשימת קישורים שטוחה לכל הקבצים.
    final generationByBook = <int, String>{};
    final links = <UserLinkRecord>[];

    for (final filePath in filePaths) {
      final file = File(filePath);
      if (!await file.exists()) {
        errors.add('${_baseName(filePath)}: הקובץ לא נמצא');
        continue;
      }
      final name = _baseName(filePath);
      final lower = name.toLowerCase();
      if (_generationFileNames.contains(name)) {
        await _ingestGenerations(file, repo, generationByBook, errors);
      } else if (_folderLinkFileNames.contains(name)) {
        await _ingestLinks(file, repo, links, errors,
            bookTitleFromFile: null,
            resolveRef: resolveRef,
            sourceExists: sourceExists);
      } else if (lower.endsWith('.links.csv')) {
        final bookTitle = name.substring(0, name.length - '.links.csv'.length);
        await _ingestLinks(file, repo, links, errors,
            bookTitleFromFile: bookTitle,
            resolveRef: resolveRef,
            sourceExists: sourceExists);
      } else if (lower.endsWith('.links.json')) {
        final bookTitle = name.substring(0, name.length - '.links.json'.length);
        await _ingestLinks(file, repo, links, errors,
            bookTitleFromFile: bookTitle,
            resolveRef: resolveRef,
            sourceExists: sourceExists);
      } else {
        errors.add(
            '$name: קובץ לא מזוהה (צפוי "דורות.csv" או "<ספר>.links.csv")');
      }
    }

    if (errors.isNotEmpty) {
      return UserImportResult(errors: errors);
    }

    for (final entry in generationByBook.entries) {
      await repo.setBookGeneration(entry.key, entry.value);
    }
    for (final link in links) {
      await repo.upsertUserLink(link);
    }

    return UserImportResult(
      generationsApplied: generationByBook.length,
      linksApplied: links.length,
      booksWithLinks: links
          .map((l) => '${l.sourceIsUserBook}|${l.sourceCategoryId}|'
              '${l.sourceTitle}')
          .toSet()
          .length,
      errors: errors,
    );
  }

  static Future<void> _ingestGenerations(
    File file,
    UserContentRepository repo,
    Map<int, String> out,
    List<String> errors,
  ) async {
    final fileName = _baseName(file.path);
    final ParseResult<ParsedBookGeneration> parsed;
    try {
      parsed = UserImportParser.parseGenerations(await file.readAsString());
    } catch (e) {
      errors.add('$fileName: קריאת הקובץ נכשלה ($e)');
      return;
    }
    for (final err in parsed.errors) {
      errors.add('$fileName ${err.message} (שורה ${err.lineNumber})');
    }
    for (final row in parsed.rows) {
      final bookId =
          await repo.bookIdByTitle(row.bookTitle, categoryId: row.categoryId);
      if (bookId == null) {
        errors.add('$fileName: הספר "${row.bookTitle}" לא נמצא בספרייה האישית');
        continue;
      }
      out[bookId] = row.eraName;
    }
  }

  static Future<void> _ingestLinks(
    File file,
    UserContentRepository repo,
    List<UserLinkRecord> out,
    List<String> errors, {
    required String? bookTitleFromFile,
    required UserLinkRefResolver resolveRef,
    required UserLinkSourceChecker sourceExists,
  }) async {
    final fileName = _baseName(file.path);
    final ParseResult<ParsedUserLink> parsed;
    try {
      final content = await file.readAsString();
      parsed = fileName.toLowerCase().endsWith('.json')
          ? UserImportParser.parseLinksJson(content)
          : UserImportParser.parseLinks(content);
    } catch (e) {
      errors.add('$fileName: קריאת הקובץ נכשלה ($e)');
      return;
    }
    for (final err in parsed.errors) {
      errors.add('$fileName ${err.message} (שורה ${err.lineNumber})');
    }
    for (final row in parsed.rows) {
      final sourceTitle = bookTitleFromFile ?? row.sourceBookTitle;
      if (sourceTitle == null || sourceTitle.isEmpty) {
        errors.add('$fileName: חסר ספר מקור (עמודת "ספר_מקור")');
        continue;
      }
      // מקור אישי מאומת מול user_books.db הנתון (כמו קודם); מקור רשמי מול
      // seforim.db דרך [sourceExists] — כדי לחסום כותרת שגויה שתיצור קישור מת.
      final bool found;
      if (row.sourceIsUserBook) {
        found = await repo.bookIdByTitle(sourceTitle,
                categoryId: row.sourceCategoryId) !=
            null;
      } else {
        found = await sourceExists(
            title: sourceTitle,
            categoryId: row.sourceCategoryId,
            isUserBook: false);
      }
      if (!found) {
        errors.add('$fileName: ספר המקור "$sourceTitle" לא נמצא');
        continue;
      }
      final record =
          await _resolveRecord(sourceTitle, row, resolveRef, fileName, errors);
      if (record != null) out.add(record);
    }
  }

  /// בונה רשומת קישור עם אינדקס-שורה ביעד. "מיקום_יעד" מספרי = אינדקס שורה
  /// ישיר (1-based); אחרת זו כתובת טקסטואלית שנפתרת לשורה דרך [resolveRef].
  /// מחזיר null (ומוסיף שגיאה) אם חסרה כתובת או שהכתובת לא נפתרה.
  static Future<UserLinkRecord?> _resolveRecord(
    String sourceTitle,
    ParsedUserLink row,
    UserLinkRefResolver resolveRef,
    String fileName,
    List<String> errors,
  ) async {
    final ref = row.targetRef?.trim();
    if (ref == null || ref.isEmpty) {
      errors.add('$fileName: חסר מיקום_יעד לקישור אל "${row.targetTitle}"');
      return null;
    }
    final numeric = int.tryParse(ref);
    final int targetLineIndex;
    if (numeric != null) {
      if (numeric < 1) {
        errors.add('$fileName: מיקום_יעד לא חוקי: "$ref"');
        return null;
      }
      targetLineIndex = numeric - 1;
    } else {
      final resolved = await resolveRef(
        targetTitle: row.targetTitle,
        targetCategoryId: row.targetCategoryId,
        targetIsUserBook: row.targetIsUserBook,
        ref: ref,
      );
      if (resolved == null) {
        errors
            .add('$fileName: לא נמצא המיקום "$ref" בספר "${row.targetTitle}"');
        return null;
      }
      targetLineIndex = resolved;
    }
    return UserLinkRecord(
      sourceTitle: sourceTitle,
      sourceCategoryId: row.sourceCategoryId,
      sourceIsUserBook: row.sourceIsUserBook,
      sourceLineIndex: row.sourceLineNumber - 1,
      targetTitle: row.targetTitle,
      targetCategoryId: row.targetCategoryId,
      targetIsUserBook: row.targetIsUserBook,
      // כתובת טקסטואלית נשמרת להצגה; מספרית מיותרת (heRef נופל לכותרת היעד).
      targetRef: numeric != null ? null : ref,
      targetLineIndex: targetLineIndex,
      connectionType: row.connectionType,
    );
  }

  static String _baseName(String path) =>
      path.replaceAll('\\', '/').split('/').last;
}

/// עטיפה בטוחה לייבוא קבצים נבחרים — לעולם לא זורקת, רק מדווחת.
Future<UserImportResult> importUserFilesSafe(
  Iterable<String> filePaths,
  MyDatabase userDb,
) async {
  try {
    return await UserContentImporter.importFiles(filePaths, userDb);
  } catch (e) {
    debugPrint('⚠️ [UserContentImport] failed: $e');
    return UserImportResult(errors: ['ייבוא נתוני-המשתמש נכשל: $e']);
  }
}
