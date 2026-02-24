/// שכבת הפשטה לניהול אחסון בפלטפורמות שונות
/// מאפשרת גישה אחידה לקבצים ונתונים בכל הפלטפורמות
abstract class StorageProvider {
  /// מחזירה את נתיב תיקיית התמיכה של האפליקציה
  Future<String> getApplicationSupportDirectory();
  
  /// מחזירה את נתיב תיקיית המסמכים
  Future<String> getApplicationDocumentsDirectory();
  
  /// מחזירה את נתיב תיקיית האחסון החיצוני (Android בלבד)
  Future<String?> getExternalStorageDirectory();
  
  /// מחזירה את נתיב תיקיית מסדי הנתונים
  Future<String> getDatabasesPath();
  
  /// בודקת אם תיקייה קיימת
  Future<bool> directoryExists(String path);
  
  /// יוצרת תיקייה (כולל תיקיות אב אם נדרש)
  Future<void> createDirectory(String path, {bool recursive = false});
  
  /// קוראת קובץ כטקסט
  Future<String> readFileAsString(String path);
  
  /// קוראת קובץ כבייטים
  Future<List<int>> readFileAsBytes(String path);
  
  /// כותבת טקסט לקובץ
  Future<void> writeFileAsString(String path, String content);
  
  /// כותבת בייטים לקובץ
  Future<void> writeFileAsBytes(String path, List<int> bytes);
  
  /// בודקת אם קובץ קיים
  Future<bool> fileExists(String path);
  
  /// מוחקת קובץ
  Future<void> deleteFile(String path);
  
  /// מוחקת תיקייה
  Future<void> deleteDirectory(String path, {bool recursive = false});
  
  /// מחזירה רשימת קבצים בתיקייה
  Future<List<String>> listFiles(String path);
  
  /// מחזירה רשימת תיקיות בתיקייה
  Future<List<String>> listDirectories(String path);
}
