import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// משטח מילון מקונן למפתחות מנוקדים (a.b.c).
Map<String, String> _flatten(Map<String, dynamic> map, [String prefix = '']) {
  final result = <String, String>{};
  map.forEach((key, value) {
    final fullKey = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      result.addAll(_flatten(value, fullKey));
    } else {
      result[fullKey] = value.toString();
    }
  });
  return result;
}

Map<String, String> _loadFlat(String path) {
  final raw = File(path).readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return _flatten(json);
}

void main() {
  const hePath = 'assets/translations/he-IL.json';
  const enPath = 'assets/translations/en.json';

  test('he-IL.json ו-en.json מכילים בדיוק את אותם מפתחות', () {
    final he = _loadFlat(hePath);
    final en = _loadFlat(enPath);

    final missingInEn = (he.keys.toSet()..removeAll(en.keys)).toList()..sort();
    final missingInHe = (en.keys.toSet()..removeAll(he.keys)).toList()..sort();

    expect(
      missingInEn,
      isEmpty,
      reason:
          'מפתחות שקיימים ב-he-IL אך חסרים ב-en:\n${missingInEn.join('\n')}',
    );
    expect(
      missingInHe,
      isEmpty,
      reason:
          'מפתחות שקיימים ב-en אך חסרים ב-he-IL:\n${missingInHe.join('\n')}',
    );
  });

  test('כל מפתח שמופיע בקוד עם .tr() קיים ב-he-IL.json', () {
    final he = _loadFlat(hePath);
    final keysInJson = he.keys.toSet();

    // מזהה literal של מחרוזת שמיד אחריו מגיע .tr(.
    final trPattern = RegExp(r'''['"]([a-zA-Z][a-zA-Z0-9_.]*)['"]\s*\.tr\(''');

    final usedKeys = <String, String>{};
    final libDir = Directory('lib');
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      for (final m in trPattern.allMatches(content)) {
        usedKeys[m.group(1)!] = entity.path;
      }
    }

    final missing = <String>[];
    usedKeys.forEach((key, path) {
      if (!keysInJson.contains(key)) missing.add('$key  ($path)');
    });
    missing.sort();

    expect(
      missing,
      isEmpty,
      reason: 'מפתחות תרגום שבשימוש בקוד אך חסרים ב-he-IL.json:\n'
          '${missing.join('\n')}',
    );
  });
}
