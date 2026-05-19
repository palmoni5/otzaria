import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/storage/plugin_system_database.dart';

PluginManifest _manifest({String id = 'p', int? toolTabOrder}) {
  return PluginManifest.fromJson({
    'schemaVersion': 1,
    'id': id,
    'name': id,
    'version': '1.0.0',
    'entrypoint': 'index.html',
    'contributes': {
      'toolTab': {
        'title': id,
        if (toolTabOrder != null) 'order': toolTabOrder,
      },
    },
  });
}

InstalledPlugin _plugin({
  required String id,
  int? userOrder,
  int? manifestToolTabOrder,
  DateTime? installedAt,
}) {
  return InstalledPlugin(
    pluginId: id,
    name: id,
    version: '1.0.0',
    installPath: '/x/$id',
    entrypointPath: 'index.html',
    enabled: true,
    pinned: true,
    manifest: _manifest(id: id, toolTabOrder: manifestToolTabOrder),
    installedAt: installedAt ?? DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    userOrder: userOrder,
  );
}

/// Fake DB שמיישם רק את המתודות שהטסטים צריכים. שאר השיחות זורקות
/// `NoSuchMethodError` אם יקראו להן בטעות (זה רצוי לאיתור bugs בטסט).
class _FakeDb implements PluginSystemDatabase {
  final List<InstalledPlugin> plugins;
  final List<Map<String, int>> userOrderCalls = [];

  _FakeDb(this.plugins);

  @override
  Future<List<InstalledPlugin>> getAllInstalledPlugins() async =>
      List.of(plugins);

  @override
  Future<void> updatePluginsUserOrder(Map<String, int> ordering) async {
    userOrderCalls.add(Map.of(ordering));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  group('PluginRegistryRepository.reorderPlugins', () {
    test('maps an ordered list of ids to {id: 0, id: 1, ...}', () async {
      final fake = _FakeDb([]);
      final repo = PluginRegistryRepository(database: fake);

      await repo.reorderPlugins(['c.id', 'a.id', 'b.id']);

      expect(fake.userOrderCalls, hasLength(1));
      expect(fake.userOrderCalls.single, {
        'c.id': 0,
        'a.id': 1,
        'b.id': 2,
      });
    });

    test('empty list still forwards an empty map (caller decides no-op)',
        () async {
      final fake = _FakeDb([]);
      final repo = PluginRegistryRepository(database: fake);

      await repo.reorderPlugins([]);

      expect(fake.userOrderCalls, hasLength(1));
      expect(fake.userOrderCalls.single, isEmpty);
    });

    test('a single id gets order 0', () async {
      final fake = _FakeDb([]);
      final repo = PluginRegistryRepository(database: fake);

      await repo.reorderPlugins(['only.one']);

      expect(fake.userOrderCalls.single, {'only.one': 0});
    });
  });

  group('PluginRegistryRepository.getAllPlugins sorting', () {
    test('orders by effectiveToolTabOrder (manifest order when no userOrder)',
        () async {
      final fake = _FakeDb([
        _plugin(id: 'late', manifestToolTabOrder: 900),
        _plugin(id: 'early', manifestToolTabOrder: 100),
        _plugin(id: 'mid', manifestToolTabOrder: 500),
      ]);
      final repo = PluginRegistryRepository(database: fake);

      final result = await repo.getAllPlugins();

      expect(result.map((p) => p.pluginId).toList(),
          ['early', 'mid', 'late']);
    });

    test('userOrder beats manifest order (always pushed after built-ins)',
        () async {
      // 'b' has the lowest manifest order (50) but no userOrder.
      // 'a' has high manifest order (9999) but userOrder=0 → ends up
      // at offset+0=1000 — AFTER 'b' (50), not before.
      final fake = _FakeDb([
        _plugin(id: 'a', userOrder: 0, manifestToolTabOrder: 9999),
        _plugin(id: 'b', manifestToolTabOrder: 50),
      ]);
      final repo = PluginRegistryRepository(database: fake);

      final result = await repo.getAllPlugins();

      expect(result.map((p) => p.pluginId).toList(), ['b', 'a'],
          reason:
              'plugins without userOrder (relying on manifest) sort by '
              'manifest order; userOrder is offset by 1000 to stay after '
              'built-in tools');
    });

    test('between two plugins with userOrder, the lower index comes first',
        () async {
      final fake = _FakeDb([
        _plugin(id: 'second', userOrder: 1),
        _plugin(id: 'first', userOrder: 0),
        _plugin(id: 'third', userOrder: 2),
      ]);
      final repo = PluginRegistryRepository(database: fake);

      final result = await repo.getAllPlugins();

      expect(result.map((p) => p.pluginId).toList(),
          ['first', 'second', 'third']);
    });

    test('empty plugin list returns empty', () async {
      final fake = _FakeDb([]);
      final repo = PluginRegistryRepository(database: fake);
      expect(await repo.getAllPlugins(), isEmpty);
    });

    test(
        'ties on effectiveToolTabOrder are broken deterministically by '
        'installedAt then pluginId (the common case: many plugins with the '
        'default manifest order of 900)', () async {
      // הקלט מסודר *הפוך* מהצפי כדי לוודא שהמיון באמת רץ.
      final fake = _FakeDb([
        _plugin(
            id: 'z',
            manifestToolTabOrder: 900,
            installedAt: DateTime.utc(2026, 1, 3)),
        _plugin(
            id: 'a',
            manifestToolTabOrder: 900,
            installedAt: DateTime.utc(2026, 1, 1)),
        _plugin(
            id: 'm',
            manifestToolTabOrder: 900,
            installedAt: DateTime.utc(2026, 1, 2)),
      ]);
      final repo = PluginRegistryRepository(database: fake);

      final result = await repo.getAllPlugins();

      expect(result.map((p) => p.pluginId).toList(), ['a', 'm', 'z'],
          reason: 'tied orders must be broken by installedAt (ascending)');
    });

    test(
        'identical installedAt falls back to pluginId — fully deterministic '
        'even when timestamps collide', () async {
      final sameTime = DateTime.utc(2026, 1, 1, 12);
      final fake = _FakeDb([
        _plugin(
            id: 'beta',
            manifestToolTabOrder: 900,
            installedAt: sameTime),
        _plugin(
            id: 'alpha',
            manifestToolTabOrder: 900,
            installedAt: sameTime),
      ]);
      final repo = PluginRegistryRepository(database: fake);

      final result = await repo.getAllPlugins();

      expect(result.map((p) => p.pluginId).toList(), ['alpha', 'beta'],
          reason: 'tied orders + tied installedAt → pluginId asc');
    });
  });

  group('PluginRegistryRepository.getNextUserOrderForNewPlugin', () {
    test('returns null when no plugin has a manual userOrder', () async {
      final fake = _FakeDb([
        _plugin(id: 'a'),
        _plugin(id: 'b'),
      ]);
      final repo = PluginRegistryRepository(database: fake);

      expect(await repo.getNextUserOrderForNewPlugin(), isNull,
          reason: 'no manual order yet → new plugin keeps manifest order');
    });

    test('returns null when the plugin list is empty (very first install)',
        () async {
      final fake = _FakeDb([]);
      final repo = PluginRegistryRepository(database: fake);

      expect(await repo.getNextUserOrderForNewPlugin(), isNull);
    });

    test(
        'returns max(userOrder) + 1 so a freshly installed plugin lands '
        'AFTER the user-ordered block — not before (which is what would '
        'happen with userOrder=null, since manifest.toolTabOrder defaults '
        'to 900 which is below the 1000 offset)', () async {
      final fake = _FakeDb([
        _plugin(id: 'a', userOrder: 0),
        _plugin(id: 'b', userOrder: 1),
        _plugin(id: 'c', userOrder: 2),
      ]);
      final repo = PluginRegistryRepository(database: fake);

      expect(await repo.getNextUserOrderForNewPlugin(), 3);
    });

    test(
        'ignores plugins with userOrder=null when computing the max — '
        'mixed state (some sorted, some not) still picks the highest '
        'manual value', () async {
      final fake = _FakeDb([
        _plugin(id: 'a', userOrder: 5),
        _plugin(id: 'b'), // userOrder=null
        _plugin(id: 'c', userOrder: 2),
      ]);
      final repo = PluginRegistryRepository(database: fake);

      expect(await repo.getNextUserOrderForNewPlugin(), 6);
    });
  });
}
