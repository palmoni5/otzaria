/// שכבת הפשטה לניהול חלונות בפלטפורמות שונות
abstract class WindowManagerService {
  /// מגדירה מצב מסך מלא
  Future<void> setFullScreen(bool fullscreen);
  
  /// בודקת אם החלון במצב מסך מלא
  Future<bool> isFullScreen();
  
  /// ממזערת את החלון
  Future<void> minimize();
  
  /// סוגרת את החלון
  Future<void> close();
  
  /// מגדילה את החלון
  Future<void> maximize();
  
  /// משחזרת את החלון לגודל רגיל
  Future<void> unmaximize();
  
  /// בודקת אם החלון מוגדל
  Future<bool> isMaximized();
  
  /// מגדירה את גודל החלון
  Future<void> setSize(double width, double height);
  
  /// מחזירה את גודל החלון
  Future<Map<String, double>> getSize();
  
  /// מגדירה את מיקום החלון
  Future<void> setPosition(double x, double y);
  
  /// מחזירה את מיקום החלון
  Future<Map<String, double>> getPosition();
  
  /// מגדירה את כותרת החלון
  Future<void> setTitle(String title);
  
  /// מציגה את החלון
  Future<void> show();
  
  /// מסתירה את החלון
  Future<void> hide();
  
  /// בודקת אם החלון גלוי
  Future<bool> isVisible();
  
  /// מגדירה האם החלון תמיד למעלה
  Future<void> setAlwaysOnTop(bool alwaysOnTop);
  
  /// בודקת אם החלון תמיד למעלה
  Future<bool> isAlwaysOnTop();
}
