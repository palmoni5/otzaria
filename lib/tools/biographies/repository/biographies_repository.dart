import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/tools/biographies/data/biographies_codec.dart';
import 'package:otzaria/tools/biographies/models/biography.dart';

/// שכבת הנתונים של אזור הביוגרפיות.
///
/// הקובץ מגיע משני מקורות, לפי סדר עדיפות: העותק שמערכת העדכונים הורידה
/// לשורש תיקיית הנתונים, ואם אין — הקובץ הארוז באפליקציה עצמה (מוזרק
/// לחבילה בזמן בנייה, ולכן כלול בכל מתקין ועובד מיד גם ללא רשת).
class BiographiesRepository {
  /// כמו `DictionaryLookupRepository`: singleton שנצרך ישירות מהמסכים,
  /// עם constructor להזרקת מקורות חלופיים בבדיקות.
  static final BiographiesRepository instance = BiographiesRepository();

  static const String bundledAssetKey = 'assets/bio/biographies.tsb';

  final Future<String> Function() _updatedPathProvider;
  final Future<ByteData> Function(String key) _loadAsset;

  Future<List<Biography>>? _loading;

  BiographiesRepository({
    Future<String> Function()? updatedPathProvider,
    Future<ByteData> Function(String key)? loadAsset,
  }) : _updatedPathProvider = updatedPathProvider ?? AppPaths.getBiographiesPath,
       _loadAsset = loadAsset ?? rootBundle.load;

  /// טוען את כל הביוגרפיות, ממוינות לפי שם. הטעינה מתבצעת פעם אחת;
  /// קריאות חוזרות (גם מקבילות) מקבלות את אותו Future.
  ///
  /// זורק [StateError] כשאין קובץ בשום מקור.
  Future<List<Biography>> loadAll() => _loading ??= _load();

  Future<List<Biography>> _load() async {
    try {
      final bytes = await _readBytes();
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

  Future<Uint8List> _readBytes() async {
    final updated = File(await _updatedPathProvider());
    if (await updated.exists()) return updated.readAsBytes();
    try {
      final data = await _loadAsset(bundledAssetKey);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      throw StateError('נתוני הביוגרפיות אינם זמינים');
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
