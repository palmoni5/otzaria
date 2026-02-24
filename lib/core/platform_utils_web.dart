import 'dart:typed_data';

/// בדיקה אם הפלטפורמה היא Windows (תמיד false בווב)
bool get isWindows => false;

/// בדיקה אם הפלטפורמה היא macOS (תמיד false בווב)
bool get isMacOS => false;

/// בדיקה אם הפלטפורמה היא iOS (תמיד false בווב)
bool get isIOS => false;

/// כתיבת שגיאה לקובץ (no-op בווב)
void writeErrorToFile(String error) {
  // Web: log to console instead
  print('Error: $error');
}

/// יציאה מהאפליקציה (no-op בווב - אי אפשר לסגור טאב)
void exitApp(int code) {
  // Cannot exit in web - just log
  print('Exit requested with code: $code');
}

/// טעינת תעודת אבטחה (no-op בווב - הדפדפן מנהל תעודות)
void loadCertificate(Uint8List certBytes) {
  // Certificates are managed by the browser
}
