import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release/generate_release_manifest.dart';

/// ההצעות של מסייע ההורדה נגזרות מ-`type` ומ-`required` של הרכיבים. הכלל
/// נכתב פעם אחת ב-`download_assistant.iss`, והנתון שהוא פועל עליו הוא טבלת
/// [kKnownComponents]. כאן הכלל נקרא מהסקריפט ומופעל על הטבלה, כדי שיישאר
/// בלתי אפשרי ששינוי בטבלה יכניס צורה חלופית של התוכנה להצעה ברירת מחדל.

const _assistant = 'installer/download_assistant.iss';

String _script() =>
    File(_assistant).readAsStringSync().replaceAll('\r\n', '\n');

/// גוף `BuildPresets` — משם מגיעים הכללים האמיתיים של ההצעות.
String _buildPresets(String script) {
  final start = script.indexOf('procedure BuildPresets();');
  expect(start, greaterThanOrEqualTo(0));
  final end = script.indexOf('\nend;', start);
  return script.substring(start, end);
}

/// הסוג שההצעה "מלאה" מחפשת כחבילה אחת שכוללת הכול.
String _bundleType(String body) => RegExp(
  r"CompType\[I\] = '([^']+)'",
).firstMatch(body)!.group(1)!;

/// רשימות הסוגים של `CollectByTypes`, לפי סדר הופעתן בגוף השגרה.
List<({String types, bool requiredOnly})> _collectCalls(String body) =>
    RegExp(
      r"CollectByTypes\('([^']*)',\s*(False|True)\)",
    ).allMatches(body).map((m) {
      return (types: m.group(1)!, requiredOnly: m.group(2) == 'True');
    }).toList();

/// רכיב רלוונטי ליעד x64 — שכפול של `ComponentFitsTarget` בסקריפט.
bool _fitsTarget(ComponentSpec spec, String arch) {
  final platform = spec.platform;
  if (platform != null && platform != 'any' && platform != 'windows') {
    return false;
  }
  final architecture = spec.architecture;
  return architecture == null || architecture == 'any' || architecture == arch;
}

Set<String> _collect(
  List<ComponentSpec> specs,
  String arch, {
  required String types,
  required bool requiredOnly,
}) {
  final wanted = types.split(',').where((t) => t.isNotEmpty).toSet();
  return specs
      .where(
        (s) =>
            _fitsTarget(s, arch) &&
            (!requiredOnly || s.required) &&
            (wanted.isEmpty || wanted.contains(s.type)),
      )
      .map((s) => s.id)
      .toSet();
}

/// סגירת ה-`dependsOn`, כמו `WithDependencies`: תלות שאינה מתאימה ליעד
/// נדלגת ואינה נכנסת להצעה.
Set<String> _closed(
  Set<String> members,
  List<ComponentSpec> specs,
  String arch,
) {
  final result = {...members};
  var changed = true;
  while (changed) {
    changed = false;
    for (final spec in specs.where((s) => result.contains(s.id))) {
      for (final dependency in spec.dependsOn) {
        final target = specs.where((s) => s.id == dependency);
        if (target.isEmpty || !_fitsTarget(target.first, arch)) continue;
        changed = result.add(dependency) || changed;
      }
    }
  }
  return result;
}

/// חברות ההצעות עבור יעד [arch], בשמות שבהם הן מוצגות למשתמש.
Map<String, Set<String>> _presets(
  String script,
  List<ComponentSpec> specs,
  String arch,
) {
  final body = _buildPresets(script);
  final calls = _collectCalls(body);
  expect(
    calls.length,
    4,
    reason: 'מספר קריאות CollectByTypes השתנה — יש לעדכן את המיפוי כאן',
  );

  final bundles = specs
      .where((s) => _fitsTarget(s, arch) && s.type == _bundleType(body))
      .toList();
  final full = bundles.isEmpty
      ? _collect(
          specs,
          arch,
          types: calls[0].types,
          requiredOnly: calls[0].requiredOnly,
        )
      : {bundles.first.id};

  final raw = {
    'מלאה': full,
    'בסיסית': {
      ..._collect(
        specs,
        arch,
        types: calls[1].types,
        requiredOnly: calls[1].requiredOnly,
      ),
      ..._collect(
        specs,
        arch,
        types: calls[2].types,
        requiredOnly: calls[2].requiredOnly,
      ),
    },
    'עדכון': _collect(
      specs,
      arch,
      types: calls[3].types,
      requiredOnly: calls[3].requiredOnly,
    ),
  };
  return raw.map(
    (name, members) => MapEntry(name, _closed(members, specs, arch)),
  );
}

const _portableIds = [
  'otzaria-windows-portable-x64',
  'otzaria-windows-portable-arm64',
];

ComponentSpec _spec(String id) =>
    kKnownComponents.firstWhere((s) => s.id == id);

void main() {
  group('הגרסה הניידת אינה רכיב נוסף של אותה התקנה', () {
    test('הסוג שלה נפרד מסוג המתקין', () {
      final installer = _spec('otzaria-windows-x64').type;
      for (final id in _portableIds) {
        expect(
          _spec(id).type,
          isNot(installer),
          reason: 'סוג משותף עם המתקין מחזיר את צירוף שתי הצורות להצעה',
        );
      }
      expect(
        _portableIds.map((id) => _spec(id).type).toSet(),
        {'application-portable'},
        reason: 'שתי הגרסאות הניידות חולקות סוג אחד',
      );
      expect(
        _spec('otzaria-windows-portable-arm64').architecture,
        'arm64',
        reason: 'הניידת של ARM אינה מוצעת למחשב x64',
      );
    });

    test('אינה נכנסת לאף הצעה שאינה "בחירה אישית"', () {
      final script = _script();
      for (final arch in const ['x64', 'arm64']) {
        final presets = _presets(script, kKnownComponents, arch);
        presets.forEach((name, members) {
          for (final id in _portableIds) {
            expect(
              members,
              isNot(contains(id)),
              reason: 'ההצעה "$name" ביעד $arch מורידה גם את הגרסה הניידת',
            );
          }
        });
      }
    });
  });

  group('כל הצעה נשארת בעלת תוכן', () {
    test('אף הצעה אינה יוצאת ריקה, ו"מלאה" מביאה חבילה אחת', () {
      final script = _script();
      for (final arch in const ['x64', 'arm64']) {
        final presets = _presets(script, kKnownComponents, arch);
        presets.forEach((name, members) {
          expect(
            members,
            isNotEmpty,
            reason: 'ההצעה "$name" ביעד $arch אינה בוחרת דבר',
          );
        });
        expect(presets['בסיסית'], contains('otzaria-windows-$arch'));
        expect(presets['עדכון'], contains('otzaria-windows-$arch'));
      }

      // ל-x64 יש חבילה שכוללת הכול, ולכן "מלאה" היא קובץ אחד; ל-ARM64 אין
      // כזו, והנפילה לאחור מרכיבה אותה מהתוכנה והספרייה.
      expect(_presets(script, kKnownComponents, 'x64')['מלאה']!.length, 1);
      expect(
        _presets(script, kKnownComponents, 'arm64')['מלאה'],
        containsAll(['otzaria-windows-arm64', 'library-full-indexed']),
      );
    });

    test('"בסיסית" ו"עדכון" מתלכדות כשאין רכיב required נוסף', () {
      final script = _script();
      final presets = _presets(script, kKnownComponents, 'x64');
      expect(
        presets['בסיסית'],
        presets['עדכון'],
        reason: 'איחוד ההצעות הזהות הוא מה שמשאיר שתי שורות בלבד במסך',
      );
    });
  });

  group('רכיב עתידי נוחת במקום סביר בלי שינוי קוד', () {
    const futureRequired = ComponentSpec(
      id: 'future-required',
      name: 'רכיב חדש נדרש',
      description: 'סוג שהסקריפט אינו מכיר.',
      type: 'runtime-blob',
      required: true,
      installOrder: 15,
      platform: 'windows',
      assets: [AssetSpec(pattern: r'^future\.bin$')],
    );
    const futureOptional = ComponentSpec(
      id: 'future-optional',
      name: 'רכיב חדש רשות',
      description: 'סוג שהסקריפט אינו מכיר.',
      type: 'runtime-blob',
      required: false,
      installOrder: 15,
      platform: 'windows',
      assets: [AssetSpec(pattern: r'^future-opt\.bin$')],
    );

    test('סוג לא מוכר עם required נכנס ל"בסיסית"', () {
      final presets = _presets(_script(), [
        ...kKnownComponents,
        futureRequired,
      ], 'x64');
      expect(presets['בסיסית'], contains('future-required'));
    });

    test('סוג לא מוכר ברשות נשאר ל"בחירה אישית" בלבד', () {
      final presets = _presets(_script(), [
        ...kKnownComponents,
        futureOptional,
      ], 'x64');
      presets.forEach((name, members) {
        expect(members, isNot(contains('future-optional')), reason: name);
      });
    });
  });
}
