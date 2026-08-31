@Tags(['manual'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/tools/biographies/data/biographies_codec.dart';
import 'package:otzaria/tools/biographies/models/biography.dart';

/// אימות מול קובץ רילייס אמיתי. ידני בלבד — דורש קובץ מקומי ומפתח:
/// `flutter test test/tools/biographies_real_file_test.dart --tags manual`
/// `--dart-define=BIO_OBF_KEY=<המפתח> --dart-define=BIO_FILE=<נתיב הקובץ>`
void main() {
  const path = String.fromEnvironment('BIO_FILE');

  test('מפענח קובץ רילייס אמיתי', () {
    final bytes = File(path).readAsBytesSync();
    final payload = BiographiesCodec.decode(bytes);
    final entries = (payload['entries'] as List)
        .whereType<Map<String, dynamic>>()
        .map(Biography.fromEntry)
        .toList();

    expect(entries.length, greaterThan(3000));
    expect(entries.every((b) => b.name.trim().isNotEmpty), isTrue);
    expect(entries.where((b) => b.summary != null), isNotEmpty);
    expect(entries.where((b) => b.biographyShort != null), isNotEmpty);
    expect(entries.where((b) => b.deathHebrew != null), isNotEmpty);

    // כל ערך חייב שם תצוגה — כולל ערכים שיש להם רק כינוי ולא שם פרטי.
    expect(entries.map((b) => b.id).toSet().length, entries.length);
  }, skip: path.isEmpty ? 'BIO_FILE not provided' : false);
}
