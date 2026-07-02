import 'dart:io';

import 'package:otzaria/utils/text/text_manipulation.dart';

/// מחיל על שורת ספר את אותן טרנספורמציות טקסט שנדרשות לפני ייצוא.
String applyTextBookExportTextTransforms(
  String input, {
  required bool removeNikud,
  required bool removeTaamim,
  required bool shouldReplaceHolyNames,
  required bool stripHtml,
}) {
  var text = input;
  if (removeNikud && removeTaamim) {
    text = removeVolwels(text);
  } else if (removeNikud && !removeTaamim) {
    text = text
        .replaceAll('־', ' ')
        .replaceAll('׀', ' ')
        .replaceAll('|', ' ')
        .replaceAll(RegExp(r'[\u05B0-\u05C7]'), '');
  } else if (!removeNikud && removeTaamim) {
    text = removeTeamim(text);
  }
  if (shouldReplaceHolyNames) {
    text = replaceHolyNames(text);
  }
  return stripHtml ? stripHtmlIfNeeded(text) : text;
}

/// מנקה שם ספר כך שיהיה תקין כשם קובץ במערכות הקבצים הנתמכות.
String sanitizeTextBookExportFileName(String value) {
  final sanitized = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  return sanitized.isEmpty ? 'ספר' : sanitized;
}

/// מחזיר נתיב ייצוא עם הסיומת שנבחרה בפועל על ידי המשתמש.
String normalizeTextBookExportPath(
  String path, {
  required String defaultExtension,
}) {
  final extension = extensionOfTextBookExportPath(path);
  if (extension == defaultExtension) {
    return path;
  }
  if (extension.isNotEmpty) {
    return path.substring(0, path.length - extension.length) + defaultExtension;
  }
  return '$path.$defaultExtension';
}

/// מחלץ סיומת מנתיב ייצוא, באותיות קטנות וללא הנקודה.
String extensionOfTextBookExportPath(String path) {
  final lastWindowsSeparator = path.lastIndexOf('\\');
  final lastPosixSeparator = path.lastIndexOf('/');
  final fileNameStart = lastWindowsSeparator > lastPosixSeparator
      ? lastWindowsSeparator + 1
      : lastPosixSeparator + 1;
  final fileName = path.substring(fileNameStart);
  final parts = fileName.split('.');
  if (parts.length < 2) return '';
  return parts.last.toLowerCase();
}

/// מזהה שגיאות Windows נפוצות של קובץ יעד פתוח או נעול.
bool isLockedTextBookExportFileException(FileSystemException e) {
  final code = e.osError?.errorCode;
  return code == 32 || code == 33;
}
