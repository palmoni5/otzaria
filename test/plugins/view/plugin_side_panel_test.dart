import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/plugins/view/plugin_side_panel.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:path/path.dart' as p;
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_permission_grant.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:mockito/mockito.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _FakeSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _FakeSettingsBloc({bool isOfflineMode = false})
      : super(SettingsState.initial().copyWith(isOfflineMode: isOfflineMode)) {
    on<SettingsEvent>((_, __) {});
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

PluginManifest _manifestFor({
  required String id,
  required String name,
  bool networkEnabled = false,
}) {
  return PluginManifest(
    schemaVersion: 1,
    id: id,
    name: name,
    version: '1.0.0',
    description: 'test',
    author: 'tester',
    homepage: '',
    entrypoint: 'index.html',
    minAppVersion: '1.0.0',
    sdkVersion: '1.x',
    permissions: const [],
    networkEnabled: networkEnabled,
    networkAllowlist: const [],
    toolTabTitle: name,
    toolTabOrder: 100,
    defaultPinned: true,
    publishedDataTypes: const [],
  );
}

InstalledPlugin _pluginFor({
  required String id,
  required String name,
  bool networkEnabled = false,
}) {
  return InstalledPlugin(
    pluginId: id,
    name: name,
    version: '1.0.0',
    installPath: '/tmp/$id',
    entrypointPath: '/tmp/$id/index.html',
    enabled: true,
    pinned: true,
    manifest: _manifestFor(
      id: id,
      name: name,
      networkEnabled: networkEnabled,
    ),
    installedAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

class _StaticPluginSystemBloc
    extends Bloc<PluginSystemEvent, PluginSystemState>
    implements PluginSystemBloc {
  _StaticPluginSystemBloc(super.initial) {
    on<PluginSystemEvent>((_, __) {});
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap({
  required PluginSystemBloc pluginBloc,
  required SettingsBloc settingsBloc,
  bool showDevTools = true,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<PluginSystemBloc>.value(value: pluginBloc),
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
        ],
        child: PluginSidePanel(showDevTools: showDevTools),
      ),
    ),
  );
}

// Mock FilePicker platform to avoid MissingPluginException and LateInitializationError.
class FakeFilePickerPlatform extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  final String fakeDirectoryPath;
  FakeFilePickerPlatform(this.fakeDirectoryPath);

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    return FilePickerResult([PlatformFile(path: fakeDirectoryPath, name: 'dir', size: 0)]);
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    bool lockParentWindow = false,
  }) async {
    return fakeDirectoryPath;
  }
}

class FakePluginRegistryRepository extends Mock implements PluginRegistryRepository {
  List<InstalledPlugin> plugins = [];
  
  @override
  Future<void> saveDevelopmentPlugin(InstalledPlugin plugin) async {
    plugins.add(plugin);
  }

  @override Future<List<InstalledPlugin>> getAllPlugins() async => plugins;
  @override Future<List<InstalledPlugin>> getDevelopmentPlugins() async => plugins;
  @override Future<InstalledPlugin?> getPlugin(String id) async => null;
  @override Future<bool?> getPermission(String id, String perm) async => true;
  @override Future<void> setPermission(String id, String perm, bool granted) async {}
  @override Future<List<PluginPermissionGrant>> getPluginPermissions(String id) async => [];
  @override Future<int?> getNextUserOrderForNewPlugin() async => null;
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'Otzaria',
      packageName: 'com.otzaria.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('PluginSidePanel shows dev tools explicitly when flag is true', (WidgetTester tester) async {
    final mockRepo = FakePluginRegistryRepository();
    final bloc = PluginSystemBloc(repository: mockRepo);

    await tester.pumpWidget(_wrap(
      pluginBloc: bloc,
      settingsBloc: _FakeSettingsBloc(),
      showDevTools: true,
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(FluentIcons.folder_add_24_regular), findsOneWidget);
  });

  testWidgets('PluginSidePanel hides dev tools explicitly when flag is false', (WidgetTester tester) async {
    final mockRepo = FakePluginRegistryRepository();
    final bloc = PluginSystemBloc(repository: mockRepo);

    await tester.pumpWidget(_wrap(
      pluginBloc: bloc,
      settingsBloc: _FakeSettingsBloc(),
      showDevTools: false,
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(FluentIcons.folder_add_24_regular), findsNothing);
  });

  testWidgets('PluginSidePanel triggers picker and bloc on dev button tap', (WidgetTester tester) async {
    // Pre-cache package info to prevent method channel hang during widget test async pumped frames
    await PackageInfo.fromPlatform();

    final mockRepo = FakePluginRegistryRepository();
    final bloc = PluginSystemBloc(repository: mockRepo);

    final tempDir = Directory.systemTemp.createTempSync('otzaria_test_sidepanel');
    final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
    manifestFile.writeAsStringSync(jsonEncode({
      'schemaVersion': 1,
      'id': 'test.ui.plugin',
      'version': '1.0.0',
      'name': 'UI Dev Plugin',
      'entrypoint': 'index.html',
      'permissions': [],
      'minAppVersion': '1.0.0',
      'description': 'test',
      'author': 'tester',
      'homepage': 'https://test.com',
      'sdkVersion': '1.0.0',
      'networkEnabled': false,
      'networkAllowlist': [],
      'toolTabTitle': 'Tab',
      'toolTabOrder': 0,
      'publishedDataTypes': []
    }));
    File(p.join(tempDir.path, 'index.html')).createSync();

    // Use our custom Fake FilePicker instead of method channels
    FilePickerPlatform.instance = FakeFilePickerPlatform(tempDir.path);

    await tester.pumpWidget(_wrap(
      pluginBloc: bloc,
      settingsBloc: _FakeSettingsBloc(),
      showDevTools: true,
    ));
    await tester.pumpAndSettle();

    // Register the stream expectation BEFORE the action that triggers it.
    // emitsThrough allows intermediate states (e.g. PluginSystemLoading) before the target.
    final loadedExpectation = expectLater(
      bloc.stream,
      emitsThrough(isA<PluginSystemLoaded>()),
    );

    await tester.tap(find.byIcon(FluentIcons.folder_add_24_regular));
    await tester.pump();

    // The DevLoader uses real dart:io which needs real async — runAsync lets
    // the Dart event loop run freely while we wait for the stream to emit.
    await tester.runAsync(() => loadedExpectation);

    // Flush the UiSnack overlay timer so the test teardown doesn't complain.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    // Verify UI is still intact
    expect(find.byIcon(FluentIcons.folder_add_24_regular), findsOneWidget);

    // Deep verification: the repository received the correct plugin data
    expect(mockRepo.plugins.isNotEmpty, isTrue);
    expect(mockRepo.plugins.first.pluginId, 'test.ui.plugin');
    expect(mockRepo.plugins.first.name, 'UI Dev Plugin');
    expect(mockRepo.plugins.first.sourceType, 'development');

    tempDir.deleteSync(recursive: true);
  });

  group('סינון לפי מצב מנותק', () {
    testWidgets('במצב מקוון מציג גם תוספים שדורשים אינטרנט וגם שלא דורשים',
        (tester) async {
      final pluginBloc = _StaticPluginSystemBloc(PluginSystemLoaded([
        _pluginFor(id: 'local.plugin', name: 'תוסף מקומי'),
        _pluginFor(
            id: 'cloud.plugin', name: 'תוסף ענן', networkEnabled: true),
      ]));
      addTearDown(pluginBloc.close);

      await tester.pumpWidget(_wrap(
        pluginBloc: pluginBloc,
        settingsBloc: _FakeSettingsBloc(isOfflineMode: false),
      ));
      await tester.pumpAndSettle();

      expect(find.text('תוסף מקומי'), findsOneWidget);
      expect(find.text('תוסף ענן'), findsOneWidget);
    });

    testWidgets('במצב מנותק מסתיר תוספים שדורשים אינטרנט',
        (tester) async {
      final pluginBloc = _StaticPluginSystemBloc(PluginSystemLoaded([
        _pluginFor(id: 'local.plugin', name: 'תוסף מקומי'),
        _pluginFor(
            id: 'cloud.plugin', name: 'תוסף ענן', networkEnabled: true),
      ]));
      addTearDown(pluginBloc.close);

      await tester.pumpWidget(_wrap(
        pluginBloc: pluginBloc,
        settingsBloc: _FakeSettingsBloc(isOfflineMode: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('תוסף מקומי'), findsOneWidget);
      expect(find.text('תוסף ענן'), findsNothing);
    });

    testWidgets(
        'במצב מנותק כשכל התוספים דורשים אינטרנט - מציג הודעת empty state ייעודית',
        (tester) async {
      final pluginBloc = _StaticPluginSystemBloc(PluginSystemLoaded([
        _pluginFor(
            id: 'cloud.plugin', name: 'תוסף ענן', networkEnabled: true),
      ]));
      addTearDown(pluginBloc.close);

      await tester.pumpWidget(_wrap(
        pluginBloc: pluginBloc,
        settingsBloc: _FakeSettingsBloc(isOfflineMode: true),
      ));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('הוסתרו במצב מנותק'),
        findsOneWidget,
      );
    });

    testWidgets(
        'כשאין תוספים מותקנים - מציג הודעת empty state רגילה גם במצב מנותק',
        (tester) async {
      final pluginBloc =
          _StaticPluginSystemBloc(const PluginSystemLoaded([]));
      addTearDown(pluginBloc.close);

      await tester.pumpWidget(_wrap(
        pluginBloc: pluginBloc,
        settingsBloc: _FakeSettingsBloc(isOfflineMode: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('לא הותקנו תוספים'), findsOneWidget);
    });
  });

  group('OfflineModePluginFilter extension', () {
    test('במצב מקוון מחזיר את הרשימה ללא שינוי', () {
      final plugins = [
        _pluginFor(id: 'a', name: 'A'),
        _pluginFor(id: 'b', name: 'B', networkEnabled: true),
      ];
      expect(plugins.filterForOfflineMode(false), equals(plugins));
    });

    test('במצב מנותק מסנן רק תוספים עם networkEnabled=true', () {
      final local = _pluginFor(id: 'a', name: 'A');
      final cloud =
          _pluginFor(id: 'b', name: 'B', networkEnabled: true);
      final filtered = [local, cloud].filterForOfflineMode(true);
      expect(filtered, [local]);
    });

    test('רשימה ריקה מוחזרת כרשימה ריקה', () {
      expect(<InstalledPlugin>[].filterForOfflineMode(true), isEmpty);
      expect(<InstalledPlugin>[].filterForOfflineMode(false), isEmpty);
    });
  });

  group('InstalledPlugin.requiresNetwork', () {
    test('מחזיר true כאשר manifest.networkEnabled=true', () {
      final plugin =
          _pluginFor(id: 'a', name: 'A', networkEnabled: true);
      expect(plugin.requiresNetwork, isTrue);
    });

    test('מחזיר false כאשר manifest.networkEnabled=false', () {
      final plugin = _pluginFor(id: 'a', name: 'A');
      expect(plugin.requiresNetwork, isFalse);
    });
  });

  group('Reorder UI', () {
    testWidgets('drag handle is shown for each plugin row', (tester) async {
      final pluginBloc = _StaticPluginSystemBloc(PluginSystemLoaded([
        _pluginFor(id: 'a', name: 'A'),
        _pluginFor(id: 'b', name: 'B'),
      ]));
      addTearDown(pluginBloc.close);

      await tester.pumpWidget(_wrap(
        pluginBloc: pluginBloc,
        settingsBloc: _FakeSettingsBloc(),
      ));
      await tester.pumpAndSettle();

      // לכל תוסף יש drag handle נפרד.
      expect(find.byIcon(FluentIcons.re_order_dots_vertical_24_regular), findsNWidgets(2));
    });

    testWidgets(
        'drag handle exposes a "גרור ושחרר" tooltip so the user knows '
        'what the icon does', (tester) async {
      final pluginBloc = _StaticPluginSystemBloc(PluginSystemLoaded([
        _pluginFor(id: 'a', name: 'A'),
      ]));
      addTearDown(pluginBloc.close);

      await tester.pumpWidget(_wrap(
        pluginBloc: pluginBloc,
        settingsBloc: _FakeSettingsBloc(),
      ));
      await tester.pumpAndSettle();

      // ה-Tooltip נטען בעץ — אנחנו מחפשים את ההודעה שלו ישירות.
      final tooltipFinder = find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == 'גרור ושחרר לסידור מחדש',
      );
      expect(tooltipFinder, findsAtLeastNWidgets(1));
    });

    testWidgets(
        'mounting inside a LayoutBuilder ancestor does not crash — '
        'regression for the _RenderLayoutBuilder mutation assert and the '
        '_retakeInactiveElement assert that fired when ReorderableListView '
        'tried to use a root OverlayPortal through outer LayoutBuilders',
        (tester) async {
      final pluginBloc = _StaticPluginSystemBloc(PluginSystemLoaded([
        _pluginFor(id: 'a', name: 'A'),
        _pluginFor(id: 'b', name: 'B'),
        _pluginFor(id: 'c', name: 'C'),
      ]));
      addTearDown(pluginBloc.close);

      // מדמים את המסגרת האמיתית בה הפאנל נמצא ב-ToolsScreen: עטוף
      // ב-LayoutBuilder (FloatingPanel/ContextOverlayPanel) ובלי Material
      // ישיר. אם הקריסה תחזור — היא תתפוס פה לפני שתגיע למשתמש.
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Scaffold(
            body: LayoutBuilder(
              builder: (ctx, constraints) => SizedBox(
                width: 400,
                height: constraints.maxHeight,
                child: MultiBlocProvider(
                  providers: [
                    BlocProvider<PluginSystemBloc>.value(value: pluginBloc),
                    BlocProvider<SettingsBloc>.value(
                        value: _FakeSettingsBloc()),
                  ],
                  child: const PluginSidePanel(showDevTools: false),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // הפאנל נטען בהצלחה והרשימה רנדרה — אין FlutterError ב-tester.
      expect(tester.takeException(), isNull);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets(
        'dragging plugin A onto plugin C dispatches ReorderPluginsRequested '
        'with the new order [B, C, A]', (tester) async {
      final repo = _ReorderingFakeRepository();
      final bloc = PluginSystemBloc(repository: repo);
      addTearDown(bloc.close);

      // טוענים תוספים A, B, C ומחכים שה-Loaded יתפרסם.
      repo.plugins = [
        _pluginFor(id: 'a', name: 'A'),
        _pluginFor(id: 'b', name: 'B'),
        _pluginFor(id: 'c', name: 'C'),
      ];
      bloc.add(LoadPlugins());

      await tester.pumpWidget(_wrap(
        pluginBloc: bloc,
        settingsBloc: _FakeSettingsBloc(),
        showDevTools: false,
      ));
      await tester.pumpAndSettle();

      // מאתרים את ה-drag handles ומבצעים גרירה מ-A אל C.
      final handles = find.byIcon(FluentIcons.re_order_dots_vertical_24_regular);
      expect(handles, findsNWidgets(3));

      final handleA = handles.at(0);
      final handleC = handles.at(2);
      final centerC = tester.getCenter(handleC);

      final gesture =
          await tester.startGesture(tester.getCenter(handleA));
      // pump לפני התזוזה כדי שהדיווח של Draggable יתחיל
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(centerC);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      // לא משתמשים ב-pumpAndSettle כי ה-Tooltip על drag handle מציג
      // fade-out animation עם showDuration ארוך שגורם ל-pumpAndSettle
      // להישאר תקוע. די בכמה pumps כדי לתת ל-Bloc dispatch להסתיים.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      // ה-repository קיבל קריאה ל-reorder עם הסדר החדש.
      expect(repo.reorderCalls, isNotEmpty,
          reason: 'drag-and-drop should trigger reorderPlugins');
      // A נגרר על C — A צריך להגיע אחרי B במיקום של C.
      expect(repo.reorderCalls.last, ['b', 'c', 'a']);
    });

    testWidgets('dropping a plugin onto itself does not call reorder',
        (tester) async {
      final repo = _ReorderingFakeRepository();
      final bloc = PluginSystemBloc(repository: repo);
      addTearDown(bloc.close);

      repo.plugins = [
        _pluginFor(id: 'a', name: 'A'),
        _pluginFor(id: 'b', name: 'B'),
      ];
      bloc.add(LoadPlugins());

      await tester.pumpWidget(_wrap(
        pluginBloc: bloc,
        settingsBloc: _FakeSettingsBloc(),
        showDevTools: false,
      ));
      await tester.pumpAndSettle();

      final handles = find.byIcon(FluentIcons.re_order_dots_vertical_24_regular);
      final handleA = handles.at(0);
      final centerA = tester.getCenter(handleA);

      final gesture = await tester.startGesture(centerA);
      await tester.pump(const Duration(milliseconds: 100));
      // תזוזה מינימלית כדי להפעיל את Draggable, אבל לשחרר באותו פריט.
      await gesture.moveBy(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      // ראו ההסבר על Tooltip+pumpAndSettle בטסט שלפני.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.reorderCalls, isEmpty,
          reason: 'self-drop must be a no-op (DragTarget rejects own data)');
    });

    testWidgets(
        'offline reorder preserves the relative position of hidden plugins — '
        'the bloc receives ALL plugin ids including the cloud one that is '
        'not visible on screen', (tester) async {
      final repo = _ReorderingFakeRepository();
      final bloc = PluginSystemBloc(repository: repo);
      addTearDown(bloc.close);

      // a (local), b (cloud-only — hidden when offline), c (local)
      repo.plugins = [
        _pluginFor(id: 'a', name: 'A'),
        _pluginFor(id: 'b', name: 'B', networkEnabled: true),
        _pluginFor(id: 'c', name: 'C'),
      ];
      bloc.add(LoadPlugins());

      await tester.pumpWidget(_wrap(
        pluginBloc: bloc,
        settingsBloc: _FakeSettingsBloc(isOfflineMode: true),
        showDevTools: false,
      ));
      await tester.pumpAndSettle();

      // המשתמש רואה רק [a, c] במצב מנותק.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsNothing);
      expect(find.text('C'), findsOneWidget);

      // יש 2 drag handles — אחד ל-A ואחד ל-C.
      final handles =
          find.byIcon(FluentIcons.re_order_dots_vertical_24_regular);
      expect(handles, findsNWidgets(2));

      // גוררים את A (handle 0, מבין הגלויים) אל C (handle 1).
      final handleA = handles.at(0);
      final handleC = handles.at(1);
      final centerC = tester.getCenter(handleC);

      final gesture = await tester.startGesture(tester.getCenter(handleA));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(centerC);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      // ראו ההסבר על Tooltip+pumpAndSettle בטסט הראשון של Reorder UI.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.reorderCalls, isNotEmpty);
      // הקריטריון הקריטי: גם 'b' המוסתר חייב להיות ברשימה שנשלחת
      // ל-reorder, אחרת user_order שלו יישאר ישן ויגרום לכפילויות.
      expect(repo.reorderCalls.last, contains('b'),
          reason:
              'reorder under offline mode must still include hidden plugins '
              'in the ordering vector — otherwise their user_order stays '
              'stale and breaks ordering when going back online');
      // הסדר הצפוי: A הוסר ממיקום 0, הוכנס במיקום של C (היה 2).
      // אחרי remove: [b, c]; insert(2, a) → [b, c, a].
      expect(repo.reorderCalls.last, ['b', 'c', 'a']);
    });
  });
}

/// Fake repository ש"מאחסן" תוספים בזיכרון ומיישם reorderPlugins כדי
/// שהזרימה bloc→repository→bloc תעבוד בטסט.
class _ReorderingFakeRepository extends FakePluginRegistryRepository {
  final List<List<String>> reorderCalls = [];

  @override
  Future<void> reorderPlugins(List<String> orderedPluginIds) async {
    reorderCalls.add(List.of(orderedPluginIds));
    final byId = {for (final p in plugins) p.pluginId: p};
    plugins = [
      for (final id in orderedPluginIds)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }
}
