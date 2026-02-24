import 'dart:io';
import 'dart:typed_data';

/// בדיקה אם הפלטפורמה היא Windows
bool get isWindows => Platform.isWindows;

/// בדיקה אם הפלטפורמה היא macOS
bool get isMacOS => Platform.isMacOS;

/// בדיקה אם הפלטפורמה היא iOS
bool get isIOS => Platform.isIOS;

/// כתיבת שגיאה לקובץ (Native בלבד)
void writeErrorToFile(String error) {
  try {
    File('errors.txt').writeAsStringSync(error, mode: FileMode.append);
  } catch (e) {
    // Ignore file write errors
  }
}

/// יציאה מהאפליקציה (Native בלבד)
void exitApp(int code) {
  exit(code);
}

/// טעינת תעודת אבטחה (Native בלבד)
void loadCertificate(Uint8List certBytes) {
  SecurityContext.defaultContext.setTrustedCertificatesBytes(certBytes);
}
