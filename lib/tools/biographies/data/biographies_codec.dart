import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// מפענח את קובץ הביוגרפיות (`biographies.tsb`) שמופץ דרך GitHub Releases
/// של `ta-shma-to-otzaria`.
///
/// פורמט TSB1: 4 בייטים ASCII‏ `TSB1`, ואחריהם ‎gzip(JSON-UTF8)‎ שעבר XOR
/// בייט-בייט מול keystream של 32 בייט — ‎SHA-256 של מפתח העירפול — החוזר
/// מחזורית. זהו עירפול קל בלבד (המפתח מוטמע בקוד), שנועד למנוע פתיחה
/// אגבית של הקובץ, לא הצפנה.
class BiographiesCodec {
  BiographiesCodec._();

  static const String _magic = 'TSB1';

  /// מפתח פענוח הקובץ, מוזרק בזמן בנייה: `--dart-define=BIO_OBF_KEY=...`
  /// (הסוד `BIO_OBF_KEY` ב-CI). כך הוא אינו מופיע כטקסט בקוד המקור. ריק
  /// בבנייה מקומית ללא הגדרה — ואז הפענוח ייכשל וההודעה "אין נתונים" תוצג.
  static const String _obfKey = String.fromEnvironment('BIO_OBF_KEY');

  /// מפענח את בייטי הקובץ ומחזיר את ה-JSON העליון.
  ///
  /// זורק [FormatException] אם הכותרת אינה `TSB1` או שהתוכן אינו נפרש —
  /// קובץ פגום או מפתח לא תואם.
  static Map<String, dynamic> decode(Uint8List bytes) {
    if (bytes.length < _magic.length ||
        ascii.decode(bytes.sublist(0, _magic.length)) != _magic) {
      throw const FormatException('קובץ ביוגרפיות ללא כותרת TSB1');
    }
    final keystream = sha256.convert(utf8.encode(_obfKey)).bytes;
    final payload = Uint8List(bytes.length - _magic.length);
    for (var i = 0; i < payload.length; i++) {
      payload[i] = bytes[i + _magic.length] ^ keystream[i % keystream.length];
    }
    final List<int> plain;
    try {
      plain = gzip.decode(payload);
    } catch (e) {
      throw FormatException('פענוח gzip של קובץ הביוגרפיות נכשל: $e');
    }
    final json = jsonDecode(utf8.decode(plain));
    if (json is! Map<String, dynamic> ||
        json['format'] != 'tashma-biographies') {
      throw const FormatException('תוכן קובץ הביוגרפיות אינו במבנה הצפוי');
    }
    return json;
  }
}
