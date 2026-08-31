import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/tools/biographies/data/biographies_codec.dart';
import 'package:otzaria/tools/biographies/models/biography.dart';

/// שכבת הנתונים של אזור הביוגרפיות: מפענחת את קובץ `biographies.tsb`
/// המקומי וטוענת את הערכים לזיכרון.
///
/// ההורדה והעדכון של הקובץ הם באחריות מערכת עדכוני הנכסים הנלווים
/// (`CompanionAssetsService`) שרצה בהפעלה — כמו שאר הנכסים. בהיעדר קובץ
/// המסך מציג "אין נתונים" עד שהעדכון הבא יוריד אותו.
class BiographiesRepository {
  /// כמו `DictionaryLookupRepository`: singleton שנצרך ישירות מהמסכים,
  /// עם constructor להזרקת נתיב חלופי בבדיקות.
  static final BiographiesRepository instance = BiographiesRepository();

  final Future<String> Function() _pathProvider;

  Future<List<Biography>>? _loading;

  BiographiesRepository({Future<String> Function()? pathProvider})
    : _pathProvider = pathProvider ?? AppPaths.getBiographiesPath;

  /// טוען את כל הביוגרפיות, ממוינות לפי שם. הטעינה מתבצעת פעם אחת;
  /// קריאות חוזרות (גם מקבילות) מקבלות את אותו Future.
  ///
  /// זורק [StateError] כשהקובץ עדיין לא הורד.
  Future<List<Biography>> loadAll() => _loading ??= _load();

  Future<List<Biography>> _load() async {
    try {
      final file = File(await _pathProvider());
      if (!await file.exists()) {
        throw StateError('קובץ הביוגרפיות עדיין לא הורד');
      }
      final bytes = await file.readAsBytes();
      // הפענוח (XOR + gzip + JSON של ~2.3MB) רץ ב-isolate כדי לא לחסום את ה-UI.
      final entries = await compute(_decodeAndParse, bytes);
      entries.sort((a, b) => a.name.compareTo(b.name));
      return entries;
    } catch (_) {
      // כישלון לא ננעל: פתיחה הבאה תנסה שוב (למשל אחרי שהעדכון הוריד).
      _loading = null;
      rethrow;
    }
  }

  static List<Biography> _decodeAndParse(Uint8List bytes) {
    final payload = BiographiesCodec.decode(bytes);
    return ((payload['entries'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Biography.fromEntry)
        .toList();
  }
}
