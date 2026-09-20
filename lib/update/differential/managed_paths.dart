/// כללי הנתיבים המנוהלים. חייב להישאר נטול תלות ב-Flutter: המעדכן העצמאי
/// מקומפל ב-`dart compile exe` ומייבא אותו.
library;

/// תיקיות נתוני משתמש שעלולות לשבת בתוך שורש ההתקנה (מצב נייד שומר את
/// `otzaria_data` ליד ה-executable). ראה [AppPaths].
const Set<String> kUserDataFolderNames = {
  'otzaria_data',
  'books',
  'index',
  'databases',
  'backups',
  'אוצריא',
};

/// קבצים ליד ה-executable שאינם חלק מהאפליקציה המנוהלת.
const Set<String> kUserDataFileNames = {
  'portable.marker',
  'library_path.txt',
  'system_install.marker',
};

/// מחזיר את הסיבה שנתיב אינו נתיב מנוהל חוקי, או null אם הוא תקין.
/// נתיב מנוהל הוא תמיד יחסי לשורש ההתקנה, עם `/` כמפריד.
String? managedPathError(String path) {
  if (path.isEmpty) return 'path is empty';
  if (path.contains('\\')) return 'path must use forward slashes';
  if (path.startsWith('/')) return 'path must be relative';
  if (RegExp(r'^[A-Za-z]:').hasMatch(path)) return 'path must be relative';
  for (final segment in path.split('/')) {
    if (segment.isEmpty) return 'path has an empty segment';
    if (segment == '.' || segment == '..') return 'path escapes the root';
  }
  return null;
}

/// האם הנתיב נראה כנתוני משתמש. השכבה האחרונה של ההגנה: רשימת הקבצים
/// לכתיבה ולמחיקה נגזרת ממניפסט הבנייה בלבד, שאינו מכיל נתוני משתמש כלל.
bool isUserDataPath(String path) {
  final segments = path.split('/');
  if (kUserDataFolderNames.contains(segments.first)) return true;
  return segments.length == 1 && kUserDataFileNames.contains(segments.first);
}

/// מחזיר את הסיבה שהנתיב אינו קובץ אפליקציה שמותר לכתוב עליו או למחוק אותו.
String? managedApplicationPathError(String path) {
  final error = managedPathError(path);
  if (error != null) return error;
  if (isUserDataPath(path)) return 'path is user data and is never managed';
  return null;
}
