import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';

PluginManifest _manifest({
  String id = 'test.plugin',
  int? toolTabOrder,
}) {
  return PluginManifest.fromJson({
    'schemaVersion': 1,
    'id': id,
    'name': 'Test',
    'version': '1.0.0',
    'entrypoint': 'index.html',
    'contributes': {
      'toolTab': {
        'title': 'T',
        if (toolTabOrder != null) 'order': toolTabOrder,
      },
    },
  });
}

InstalledPlugin _plugin({
  bool enabled = true,
  bool pinned = true,
  bool pinnedToNavRail = false,
  int? userOrder,
  int? manifestToolTabOrder,
}) {
  return InstalledPlugin(
    pluginId: 'test.plugin',
    name: 'Test',
    version: '1.0.0',
    installPath: '/tmp/test',
    entrypointPath: 'index.html',
    enabled: enabled,
    pinned: pinned,
    pinnedToNavRail: pinnedToNavRail,
    manifest: _manifest(toolTabOrder: manifestToolTabOrder),
    installedAt: DateTime.utc(2026, 5, 10, 12, 0),
    updatedAt: DateTime.utc(2026, 5, 10, 12, 0),
    userOrder: userOrder,
  );
}

void main() {
  group('InstalledPlugin', () {
    test('default value of pinnedToNavRail is false', () {
      final plugin = InstalledPlugin(
        pluginId: 'p',
        name: 'p',
        version: '1.0.0',
        installPath: '/x',
        entrypointPath: 'i.html',
        enabled: true,
        pinned: true,
        // pinnedToNavRail intentionally omitted
        manifest: _manifest(),
        installedAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(plugin.pinnedToNavRail, isFalse);
    });

    test('toDbMap serializes pinnedToNavRail as 0/1', () {
      expect(
          _plugin(pinnedToNavRail: false).toDbMap()['pinned_to_nav_rail'], 0);
      expect(
          _plugin(pinnedToNavRail: true).toDbMap()['pinned_to_nav_rail'], 1);
    });

    test('fromDbMap reads pinned_to_nav_rail = 1 as true', () {
      final original = _plugin(pinnedToNavRail: true);
      final restored = InstalledPlugin.fromDbMap(original.toDbMap());
      expect(restored.pinnedToNavRail, isTrue);
    });

    test('fromDbMap reads pinned_to_nav_rail = 0 as false', () {
      final original = _plugin(pinnedToNavRail: false);
      final restored = InstalledPlugin.fromDbMap(original.toDbMap());
      expect(restored.pinnedToNavRail, isFalse);
    });

    test(
        'fromDbMap defaults pinnedToNavRail to false when column is absent '
        '(legacy DB before migration)', () {
      // מדמה רשומה משורת DB ישנה לפני שהמיגרציה רצה — אין כלל מפתח כזה.
      final legacyMap = _plugin(pinnedToNavRail: true).toDbMap();
      legacyMap.remove('pinned_to_nav_rail');
      final restored = InstalledPlugin.fromDbMap(legacyMap);
      expect(restored.pinnedToNavRail, isFalse,
          reason: 'A pre-migration row must not crash and must default to false');
    });

    test('round-trip toDbMap → fromDbMap preserves both pin flags', () {
      final original = _plugin(pinned: true, pinnedToNavRail: true);
      final restored = InstalledPlugin.fromDbMap(original.toDbMap());
      expect(restored.pinned, isTrue);
      expect(restored.pinnedToNavRail, isTrue);
    });

    test('round-trip preserves the two flags independently', () {
      // pinned=false, navRail=true
      final a = _plugin(pinned: false, pinnedToNavRail: true);
      final restoredA = InstalledPlugin.fromDbMap(a.toDbMap());
      expect(restoredA.pinned, isFalse);
      expect(restoredA.pinnedToNavRail, isTrue);

      // pinned=true, navRail=false
      final b = _plugin(pinned: true, pinnedToNavRail: false);
      final restoredB = InstalledPlugin.fromDbMap(b.toDbMap());
      expect(restoredB.pinned, isTrue);
      expect(restoredB.pinnedToNavRail, isFalse);
    });

    test('copyWith updates pinnedToNavRail without touching pinned', () {
      final original = _plugin(pinned: true, pinnedToNavRail: false);
      final updated = original.copyWith(pinnedToNavRail: true);
      expect(updated.pinned, isTrue, reason: 'pinned must be unchanged');
      expect(updated.pinnedToNavRail, isTrue);
    });

    test('copyWith without pinnedToNavRail preserves the existing value', () {
      final original = _plugin(pinnedToNavRail: true);
      final updated = original.copyWith(pinned: false);
      expect(updated.pinnedToNavRail, isTrue,
          reason: 'omitted parameter should keep current value');
      expect(updated.pinned, isFalse);
    });
  });

  group('InstalledPlugin.userOrder + effectiveToolTabOrder', () {
    test('default userOrder is null (no manual ordering yet)', () {
      final plugin = _plugin();
      expect(plugin.userOrder, isNull);
    });

    test(
        'effectiveToolTabOrder falls back to manifest.toolTabOrder '
        'when userOrder is null', () {
      final plugin = _plugin(manifestToolTabOrder: 250);
      expect(plugin.userOrder, isNull);
      expect(plugin.effectiveToolTabOrder, 250);
    });

    test(
        'userOrder=0 maps to userOrderToolTabOffset (1000), not to 0 — '
        'this keeps reordered plugins after the built-in tools (orders 10-100)',
        () {
      final plugin =
          _plugin(userOrder: 0, manifestToolTabOrder: 50);
      expect(plugin.effectiveToolTabOrder,
          InstalledPlugin.userOrderToolTabOffset);
      expect(plugin.effectiveToolTabOrder,
          greaterThan(100),
          reason: 'must stay after built-in tools (10..100)');
    });

    test('effectiveToolTabOrder = offset + userOrder for positive index', () {
      final plugin = _plugin(userOrder: 5, manifestToolTabOrder: 50);
      expect(plugin.effectiveToolTabOrder,
          InstalledPlugin.userOrderToolTabOffset + 5);
    });

    test(
        'userOrder overrides manifest.toolTabOrder even when manifest is high',
        () {
      // לתוסף manifest order של 9999 (אחרון בסדר ברירת מחדל), אבל המשתמש
      // קבע userOrder=0 כדי שיהיה ראשון בין התוספים.
      final plugin = _plugin(userOrder: 0, manifestToolTabOrder: 9999);
      expect(plugin.effectiveToolTabOrder,
          InstalledPlugin.userOrderToolTabOffset);
    });

    test('relative order between plugins reflects userOrder ordering', () {
      // הסדר היחסי הוא מה שמשנה — הוא צריך להיות עקבי עם userOrder.
      final a = _plugin(userOrder: 0);
      final b = _plugin(userOrder: 1);
      final c = _plugin(userOrder: 2);
      expect(a.effectiveToolTabOrder, lessThan(b.effectiveToolTabOrder));
      expect(b.effectiveToolTabOrder, lessThan(c.effectiveToolTabOrder));
    });

    test('toDbMap serializes userOrder=null as null', () {
      final plugin = _plugin();
      expect(plugin.toDbMap()['user_order'], isNull);
    });

    test('toDbMap serializes userOrder=5 as 5', () {
      final plugin = _plugin(userOrder: 5);
      expect(plugin.toDbMap()['user_order'], 5);
    });

    test('round-trip toDbMap → fromDbMap preserves userOrder=null', () {
      final original = _plugin();
      final restored = InstalledPlugin.fromDbMap(original.toDbMap());
      expect(restored.userOrder, isNull);
    });

    test('round-trip toDbMap → fromDbMap preserves userOrder=7', () {
      final original = _plugin(userOrder: 7);
      final restored = InstalledPlugin.fromDbMap(original.toDbMap());
      expect(restored.userOrder, 7);
    });

    test(
        'fromDbMap defaults userOrder to null when column is absent '
        '(legacy DB before migration)', () {
      // מדמה רשומה משורת DB ישנה לפני שהמיגרציה רצה — אין כלל מפתח כזה.
      final legacyMap = _plugin(userOrder: 3).toDbMap();
      legacyMap.remove('user_order');
      final restored = InstalledPlugin.fromDbMap(legacyMap);
      expect(restored.userOrder, isNull,
          reason:
              'pre-migration row must not crash and must default to null');
    });

    test('copyWith updates userOrder', () {
      final original = _plugin();
      final updated = original.copyWith(userOrder: 4);
      expect(updated.userOrder, 4);
    });

    test('copyWith without userOrder preserves the existing value', () {
      final original = _plugin(userOrder: 9);
      final updated = original.copyWith(pinned: false);
      expect(updated.userOrder, 9,
          reason: 'omitted userOrder should keep current value');
    });

    test('copyWith with clearUserOrder=true sets userOrder back to null', () {
      final original = _plugin(userOrder: 9);
      final updated = original.copyWith(clearUserOrder: true);
      expect(updated.userOrder, isNull);
    });

    test(
        'copyWith with both userOrder=X and clearUserOrder=true clears '
        '(clear flag wins)', () {
      final original = _plugin(userOrder: 9);
      final updated =
          original.copyWith(userOrder: 3, clearUserOrder: true);
      expect(updated.userOrder, isNull,
          reason: 'clearUserOrder must take precedence over userOrder');
    });
  });
}
