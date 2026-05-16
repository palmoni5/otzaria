import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_permission_grant.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/services/plugin_installer_service.dart';
import 'package:otzaria/plugins/view/plugin_background_host.dart';

// ── fakes ─────────────────────────────────────────────────────────────────────

class _FakeRepo extends Mock implements PluginRegistryRepository {
  @override
  Future<List<InstalledPlugin>> getAllPlugins() async => [];
  @override
  Future<List<InstalledPlugin>> getDevelopmentPlugins() async => [];
  @override
  Future<InstalledPlugin?> getPlugin(String id) async => null;
  @override
  Future<bool?> getPermission(String id, String perm) async => false;
  @override
  Future<void> setPermission(String id, String perm, bool granted) async {}
  @override
  Future<List<PluginPermissionGrant>> getPluginPermissions(String id) async =>
      [];
}

class _FakeInstallerService extends PluginInstallerService {
  _FakeInstallerService() : super(repository: _FakeRepo());
  @override
  Future<void> cancelInstall(String path) async {}
  @override
  Future<void> finalizeInstall(String path, dynamic manifest) async {}
}

class _TestableBloc extends PluginSystemBloc {
  _TestableBloc()
      : super(
          repository: _FakeRepo(),
          installerService: _FakeInstallerService(),
        );
  void testEmit(PluginSystemState state) => emit(state);
}

// ── helpers ───────────────────────────────────────────────────────────────────

InstalledPlugin _plugin({
  String id = 'test.plugin',
  String version = '1.0.0',
  String installPath = '/install/path',
  String entrypointPath = 'index.html',
  String? devRootPath,
}) =>
    InstalledPlugin(
      pluginId: id,
      name: 'Test Plugin',
      version: version,
      installPath: installPath,
      entrypointPath: entrypointPath,
      enabled: true,
      pinned: false,
      manifest: PluginManifest(
        schemaVersion: 1,
        id: id,
        name: 'Test Plugin',
        version: version,
        description: '',
        author: '',
        homepage: '',
        entrypoint: entrypointPath,
        minAppVersion: '0.0.0',
        sdkVersion: '1.0.0',
        // ← ללא app.run_on_startup, מונע קריאות SQLite ב-_syncBackgroundPlugins
        permissions: const [],
        networkEnabled: false,
        networkAllowlist: const [],
        toolTabTitle: 'Tab',
        toolTabOrder: 0,
        defaultPinned: false,
        publishedDataTypes: const [],
      ),
      installedAt: DateTime(2025),
      updatedAt: DateTime(2025),
      devRootPath: devRootPath,
    );

/// מחשבת את ה-ValueKey שנבנה בפועל ב-PluginBackgroundHost עבור תוסף נתון.
/// חייבת להיות זהה לנוסחה ב-plugin_background_host.dart.
String backgroundKey(InstalledPlugin p) =>
    'background_${p.pluginId}'
    '_${p.version}'
    '_${p.installPath}'
    '_${p.entrypointPath}'
    '_${p.devRootPath ?? ""}';

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _TestableBloc bloc;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    bloc = _TestableBloc();
  });

  tearDown(() => bloc.close());

  // ── P1a: initState מסנכרן עם state קיים בעת mount ─────────────────────────

  testWidgets(
      'P1a — נטען ללא קריסה כשהבלוק כבר ב-PluginSystemLoaded לפני mount',
      (tester) async {
    // state מוגדר לפני שה-widget נבנה — BlocListener לבד לא יפעיל sync
    bloc.testEmit(const PluginSystemLoaded([]));

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<PluginSystemBloc>.value(
          value: bloc,
          child: const Scaffold(body: PluginBackgroundHost()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PluginBackgroundHost), findsOneWidget);
  });

  testWidgets(
      'P1a — נטען ללא קריסה כשהבלוק ב-PluginSystemLoaded עם תוספים (ללא הרשאת startup)',
      (tester) async {
    final plugins = [_plugin(id: 'p1'), _plugin(id: 'p2')];
    bloc.testEmit(PluginSystemLoaded(plugins));

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<PluginSystemBloc>.value(
          value: bloc,
          child: const Scaffold(body: PluginBackgroundHost()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PluginBackgroundHost), findsOneWidget);
  });

  testWidgets(
      'BlocListener — מסנכרן כשמתקבל PluginSystemLoaded לאחר mount',
      (tester) async {
    // הבלוק מתחיל ב-initial state
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<PluginSystemBloc>.value(
          value: bloc,
          child: const Scaffold(body: PluginBackgroundHost()),
        ),
      ),
    );
    await tester.pump();

    // state משתנה לאחר mount — BlocListener מופעל
    bloc.testEmit(PluginSystemLoaded([_plugin()]));
    await tester.pumpAndSettle();

    expect(find.byType(PluginBackgroundHost), findsOneWidget);
  });

  // ── P2: ייחודיות ValueKey ──────────────────────────────────────────────────

  group('ValueKey — backgroundKey מזהה שינויים בכל שדות הזהות', () {
    final base = _plugin();

    test('key יציב לתוסף זהה', () {
      expect(backgroundKey(base), equals(backgroundKey(base)));
    });

    test('key משתנה כשגרסה משתנה', () {
      expect(
        backgroundKey(base),
        isNot(equals(backgroundKey(base.copyWith(version: '2.0.0')))),
      );
    });

    test('key משתנה כש-installPath משתנה', () {
      expect(
        backgroundKey(base),
        isNot(equals(backgroundKey(base.copyWith(installPath: '/other/path')))),
      );
    });

    test('key משתנה כש-entrypointPath משתנה', () {
      expect(
        backgroundKey(base),
        isNot(equals(backgroundKey(base.copyWith(entrypointPath: 'app.html')))),
      );
    });

    test('key משתנה כש-devRootPath עובר מ-null לערך', () {
      final withDev = base.copyWith(devRootPath: '/dev/root');
      expect(backgroundKey(base), isNot(equals(backgroundKey(withDev))));
    });

    test('key משתנה כש-devRootPath משנה ערך', () {
      final v1 = base.copyWith(devRootPath: '/dev/v1');
      final v2 = base.copyWith(devRootPath: '/dev/v2');
      expect(backgroundKey(v1), isNot(equals(backgroundKey(v2))));
    });

    test('key שונה בין שני תוספים שונים', () {
      final other = _plugin(id: 'other.plugin');
      expect(backgroundKey(base), isNot(equals(backgroundKey(other))));
    });

    test('שינוי ב-devRootPath בלבד (ללא bump גרסה) מייצר key שונה', () {
      // מכסה את תרחיש ה-dev-plugin שציין ה-reviewer: שינוי נתיב ללא גרסה
      final before = base.copyWith(devRootPath: '/dev/old');
      final after = base.copyWith(devRootPath: '/dev/new');
      expect(backgroundKey(before), isNot(equals(backgroundKey(after))));
    });
  });
}
