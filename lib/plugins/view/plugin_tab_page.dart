import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_network_allowlist.dart';
import 'package:otzaria/plugins/services/plugin_manifest_validator.dart';
import 'package:otzaria/plugins/bridge/plugin_bridge_handler.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:collection';
import 'package:path/path.dart' as p;
import 'package:otzaria/plugins/services/plugin_runtime_dispatcher.dart';
import 'package:otzaria/plugins/storage/plugin_system_database.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:otzaria/plugins/bridge/plugin_bridge_adapter.dart';
import 'package:otzaria/tools/calendar/utils/calendar_cubit.dart';
import 'package:otzaria/search/search_repository.dart';
import 'package:otzaria/personal_notes/repository/personal_notes_repository.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/workspaces/bloc/workspace_bloc.dart';
import 'package:otzaria/utils/navigation/book_open_coordinator.dart';
import 'package:otzaria/widgets/dialogs/dialogs_exports.dart';
import 'package:otzaria/plugins/view/plugin_dev_error_view.dart';
import 'package:otzaria/plugins/view/webview_environment_holder.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/services/plugin_crash_guard.dart';
import 'package:otzaria/plugins/services/plugin_store_link_parser.dart';
import 'package:otzaria/plugins/view/plugin_crashed_view.dart';

// ---------------------------------------------------------------------------
// Stub SDK — injected at AT_DOCUMENT_START before any page JS runs.
// Queues all Otzaria.on() calls so they survive the async boot gap.
// ---------------------------------------------------------------------------
const String _sdkStub = r'''
(function () {
  var _queue = [];
  var _realSdk = null;

  window.Otzaria = {
    call: function (method, payload) {
      if (_realSdk) return _realSdk.call(method, payload);
      return Promise.reject(new Error('Otzaria SDK not ready yet'));
    },
    on: function (event, cb) {
      if (_realSdk) { _realSdk.on(event, cb); }
      else { _queue.push({ event: event, cb: cb }); }
    },
    off: function (event, cb) {
      if (_realSdk) _realSdk.off(event, cb);
    },
    /* Called by Flutter once the real SDK + boot payload are ready */
    _boot: function (sdk, payload) {
      _realSdk = sdk;
      // Re-register all listeners that were queued before boot
      _queue.forEach(function (item) { sdk.on(item.event, item.cb); });
      _queue = [];
      window.dispatchEvent(new CustomEvent('plugin.boot', { detail: payload }));
      window.dispatchEvent(new CustomEvent('plugin.ready', { detail: null }));
    }
  };

  // Block window.open for security
  window.open = function () {
    console.error('window.open is locked for security.');
    return null;
  };
})();
''';

class PluginTabPage extends StatefulWidget {
  final InstalledPlugin plugin;

  const PluginTabPage({super.key, required this.plugin});

  @override
  State<PluginTabPage> createState() => _PluginTabPageState();
}

class _PluginTabPageState extends State<PluginTabPage> {
  static Future<void>? _webViewPrerequisitesFuture;

  InAppWebViewController? webViewController;
  Offset _pendingTrackpadDelta = Offset.zero;
  bool _trackpadFrameScheduled = false;
  late String localHtmlPath;
  late final PluginBridgeHandler _bridge;
  late final PluginBridgeAdapter _adapter;
  late final PluginRegistryRepository _pluginRegistryRepository;
  late final PluginSystemBloc _pluginSystemBloc;
  bool _hasError = false;
  String? _devErrorMessage;

  // Cache PackageInfo so the async gap in onLoadStop never crosses a dispose
  static PackageInfo? _cachedPackageInfo;

  @override
  void initState() {
    super.initState();
    _pluginSystemBloc = context.read<PluginSystemBloc>();
    localHtmlPath =
        '${widget.plugin.resolvedRootPath}/${widget.plugin.entrypointPath}';
    final historyBloc = context.read<HistoryBloc>();
    final tabsBloc = context.read<TabsBloc>();
    final navigationBloc = context.read<NavigationBloc>();
    final calendarCubit = context.read<CalendarCubit>();
    final workspaceBloc = context.read<WorkspaceBloc>();
    final searchRepository = SearchRepository();
    final personalNotesRepository = PersonalNotesRepository();
    final pluginRegistryRepository = PluginRegistryRepository();

    final dependencies = PluginBridgeDependencies(
      historyBloc: historyBloc,
      tabsBloc: tabsBloc,
      navigationBloc: navigationBloc,
      calendarCubit: calendarCubit,
      workspaceBloc: workspaceBloc,
      searchRepository: searchRepository,
      personalNotesRepository: personalNotesRepository,
      bookOpenCoordinator: BookOpenCoordinator(
        tabsBloc: tabsBloc,
        historyBloc: historyBloc,
        navigationBloc: navigationBloc,
      ),
      themePayloadBuilder: () {
        if (!mounted) {
          return {
            'mode': 'light',
            'colorScheme': <String, dynamic>{},
            'typography': <String, dynamic>{},
          };
        }
        return buildThemePayload(context);
      },
      showConfirmDialog: ({
        required String title,
        required String content,
      }) async {
        if (!mounted) return false;
        return await showTwoActionsDialog(
              context: context,
              title: title,
              content: content,
              cancelText: 'common.cancel'.tr(),
              confirmText: 'common.ok'.tr(),
            ) ==
            true;
      },
      showWarningDialog: ({
        required String title,
        required String content,
        required String subtitle,
      }) async {
        if (!mounted) return false;
        return await showWarningDialog(
              context: context,
              title: title,
              content: content,
              subtitle: subtitle,
              cancelText: 'common.cancel'.tr(),
              confirmText: 'common.continue_action'.tr(),
            ) ==
            true;
      },
      requestPluginInstall: (downloadUrl) {
        _pluginSystemBloc.add(InstallRemotePluginRequested(downloadUrl));
      },
    );

    _pluginRegistryRepository = pluginRegistryRepository;
    _adapter = PluginBridgeAdapter(
      widget.plugin,
      dependencies: dependencies,
      pluginRepository: pluginRegistryRepository,
    );
    _bridge = PluginBridgeHandler(
      widget.plugin,
      adapter: _adapter,
      registry: pluginRegistryRepository,
    );
    // Pre-fetch so onLoadStop has no async gap
    _ensurePackageInfo();

    PluginRuntimeDispatcher.instance.registerReloadCallback(
      widget.plugin.pluginId,
      _reloadFromDisk,
    );
  }

  Future<void> _reloadFromDisk() async {
    if (!mounted) return;
    if (!widget.plugin.isDevelopment) return;

    try {
      await _ensurePackageInfo();
      final manifestFile =
          File(p.join(widget.plugin.resolvedRootPath, 'manifest.json'));
      if (!manifestFile.existsSync()) {
        setState(
            () => _devErrorMessage = 'plugins.tab.manifest_missing'.tr());
        return;
      }
      final manifestStr = await manifestFile.readAsString();
      final manifestJson = jsonDecode(manifestStr);

      // Perform strict manifest validation
      final manifest = PluginManifest.fromJson(manifestJson);

      await PluginManifestValidator.validateManifest(
        manifest: manifest,
        directoryPath: widget.plugin.resolvedRootPath,
        currentAppVersion: _cachedPackageInfo?.version,
      );

      if (manifest.id != widget.plugin.pluginId) {
        setState(() => _devErrorMessage = 'plugins.tab.id_changed'.tr(
              namedArgs: {
                'expected': widget.plugin.pluginId,
                'found': manifest.id,
              },
            ));
        return;
      }

      setState(() => _devErrorMessage = null);

      try {
        await InAppWebViewController.clearAllCache();
      } catch (_) {}

      localHtmlPath =
          p.join(widget.plugin.resolvedRootPath, manifest.entrypoint);
      await webViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri.uri(Uri.file(localHtmlPath))));
    } catch (e) {
      if (mounted) {
        setState(
          () => _devErrorMessage = 'plugins.tab.refresh_error'
              .tr(namedArgs: {'error': '$e'}),
        );
      }
    }
  }

  Future<void> _ensurePackageInfo() async {
    _cachedPackageInfo ??= await PackageInfo.fromPlatform();
  }

  @override
  void dispose() {
    // dispose רץ רק כשמחזור החיים הרגיל של Flutter קורא לו — כלומר התהליך
    // חי. אם הייתה קריסה native, dispose לא היה רץ בכלל. לכן מנקים את ה-
    // canary של ה-crash guard גם פה: סגירה רגילה של האפליקציה / החלפת
    // טאב / unmount של הוויג'ט = לא קריסה, ואין סיבה לחסום בהפעלה הבאה.
    // משתמשים בגרסה sync כדי שהכתיבה תושלם גם אם dispose נקרא בתוך סגירה
    // של האפליקציה שלא יספיק להריץ async writes.
    PluginCrashGuard.markLoadSuccessSync(widget.plugin.pluginId);
    _adapter.dispose();
    PluginRuntimeDispatcher.instance
        .unregisterController(widget.plugin.pluginId);
    PluginRuntimeDispatcher.instance
        .unregisterReloadCallback(widget.plugin.pluginId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.plugin.enabled) {
      return Center(
        child: Text(
          'plugins.tab.disabled_by_user'.tr(),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (_devErrorMessage != null) {
      return PluginDevErrorView(
        plugin: widget.plugin,
        errorMessage: _devErrorMessage!,
      );
    }

    if (_hasError) {
      return Center(
          child: Text('plugins.tab.load_file_error'
              .tr(namedArgs: {'path': localHtmlPath})));
    }

    if (!File(localHtmlPath).existsSync()) {
      return const SizedBox.shrink(); // התוסף כבר הוסר — הטאב ייסגר בקרוב
    }

    // אם בהפעלה הקודמת התוסף הזה הקריס את התוכנה (נשאר ב-PluginCrashGuard),
    // אנחנו לא טוענים אותו אוטומטית — מציגים מסך הסבר עם כפתור "נסה שוב".
    // כשהבאג יתוקן (upstream או דרך עדכון WebView2), הטעינה הראשונה
    // המוצלחת תקרא ל-markLoadSuccess ותסיר את הסימון לבד.
    if (PluginCrashGuard.isBlocked(widget.plugin.pluginId)) {
      return PluginCrashedView(
        pluginId: widget.plugin.pluginId,
        pluginName: widget.plugin.name,
        onRetry: () {
          if (mounted) setState(() {});
        },
      );
    }

    if (_needsWebViewPrerequisites) {
      return FutureBuilder<void>(
        future: _ensureWebViewPrerequisitesConfigured(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          if (snapshot.hasError) {
            debugPrint('WebView prerequisites init error: ${snapshot.error}');
            return Center(
              child: Text(
                'plugins.tab.webview_init_error'
                    .tr(namedArgs: {'error': '${snapshot.error}'}),
                textDirection: TextDirection.rtl,
              ),
            );
          }
          return _buildWebView();
        },
      );
    }

    return _buildWebView();
  }

  Widget _buildWebView() {
    final webView = InAppWebView(
      webViewEnvironment: WebViewEnvironmentHolder.environment,
      initialUrlRequest: URLRequest(url: WebUri.uri(Uri.file(localHtmlPath))),
      initialSettings: InAppWebViewSettings(
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        useShouldOverrideUrlLoading: true,
        useShouldInterceptRequest: true,
        cacheEnabled: !widget.plugin.isDevelopment,
        isInspectable: kDebugMode,
      ),
      // Stub SDK — injected BEFORE any page JS runs
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: _sdkStub,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      onWebViewCreated: (controller) {
        // מסמנים שמתחיל ניסיון טעינה. שימוש בגרסה הסינכרונית מבטיח שהקובץ
        // מתעדכן מיד (לפני שיש הזדמנות ל-dispose לרוץ ולנקות ריק) — אחרת
        // קיים race שבו סגירה מהירה של הטאב לפני שה-Future של ה-async
        // markLoadAttempt הספיק להוסיף לזיכרון, מוביל ל-canary שגוי.
        // הסימון נשאר ב-disk **רק** אם התהליך מת native לפני שהגענו
        // לאחד מנתיבי הסיום ב-Dart (catch / success / dispose).
        PluginCrashGuard.markLoadAttemptSync(widget.plugin.pluginId);
        try {
          webViewController = controller;
          PluginRuntimeDispatcher.instance
              .registerController(widget.plugin.pluginId, controller);
          _bridge.register(controller);
        } catch (e) {
          // bridge.register נכשל — התהליך חי, לא קריסה native. מנקים גם את
          // ה-registration הלא שלם וגם את ה-canary של ה-crash guard.
          PluginRuntimeDispatcher.instance
              .unregisterController(widget.plugin.pluginId);
          unawaited(PluginCrashGuard.markLoadSuccess(widget.plugin.pluginId));
          debugPrint(
              'Plugin [${widget.plugin.pluginId}] WebView init error: $e');
          if (mounted) setState(() => _hasError = true);
        }
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        try {
          final uri = navigationAction.request.url;
          if (uri == null) return NavigationActionPolicy.CANCEL;

          if (uri.scheme == 'otzaria') {
            final request = PluginStoreLinkParser.parseUri(uri);
            if (request != null) {
              _pluginSystemBloc.add(InstallRemotePluginRequested(
                request.downloadUri.toString(),
                forceOverwrite: request.forceOverwrite,
              ));
            }
            return NavigationActionPolicy.CANCEL;
          }

          if (uri.scheme == 'file') {
            final normalizedUri = p.normalize(uri.toFilePath());
            final normalizedInstall =
                p.normalize(widget.plugin.resolvedRootPath);
            if (p.isWithin(normalizedInstall, normalizedUri) ||
                normalizedUri == normalizedInstall) {
              return NavigationActionPolicy.ALLOW;
            }
          } else if (uri.scheme == 'data' ||
              uri.scheme == 'blob' ||
              uri.scheme == 'about') {
            return NavigationActionPolicy.ALLOW;
          }

          if (uri.scheme == 'http' || uri.scheme == 'https') {
            if (widget.plugin.manifest.networkEnabled) {
              final granted = await _pluginRegistryRepository.getPermission(
                widget.plugin.pluginId,
                'network.access',
              );
              if (granted == true && isUriAllowedForPluginNetwork(uri)) {
                return NavigationActionPolicy.ALLOW;
              }
            }
          }

          return NavigationActionPolicy.CANCEL;
        } catch (e) {
          debugPrint(
              'Plugin [${widget.plugin.pluginId}] URL override error: $e');
          return NavigationActionPolicy.CANCEL;
        }
      },
      shouldInterceptRequest: (controller, request) async {
        try {
          final uri = request.url;
          if (uri.scheme == 'file') {
            final normalizedUri = p.normalize(uri.toFilePath());
            final normalizedInstall =
                p.normalize(widget.plugin.resolvedRootPath);
            if (!p.isWithin(normalizedInstall, normalizedUri) &&
                normalizedUri != normalizedInstall) {
              return WebResourceResponse(
                  statusCode: 403, reasonPhrase: 'Forbidden');
            }
          }
          if (uri.scheme == 'http' || uri.scheme == 'https') {
            if (widget.plugin.manifest.networkEnabled) {
              final granted = await _pluginRegistryRepository.getPermission(
                widget.plugin.pluginId,
                'network.access',
              );
              if (granted == true && isUriAllowedForPluginNetwork(uri)) {
                return null;
              }
            }
            return WebResourceResponse(
                statusCode: 403, reasonPhrase: 'Forbidden');
          }
          return null;
        } catch (e) {
          debugPrint(
              'Plugin [${widget.plugin.pluginId}] intercept request error: $e');
          return WebResourceResponse(
              statusCode: 403, reasonPhrase: 'Forbidden');
        }
      },
      onLoadStop: (controller, url) async {
        try {
          // לוכד theme לפני ה-await (context חייב להישמר synchronously)
          final theme = buildThemePayload(context);

          // טוען CSS עם @font-face לגופנים המובנים, כדי שה-WebView
          // יוכל לפענח שמות כמו 'FrankRuhlCLM' שמגיעים ב-theme payload
          // (אחרת ב-macOS ה-fallback של המערכת לעברית נראה דקורטיבי).
          final fontFaceCss = await buildPluginFontFaceCss();
          if (!mounted) return;

          // Use cached PackageInfo — avoids async gap crossing a dispose
          final packageInfo =
              _cachedPackageInfo ?? await PackageInfo.fromPlatform();
          if (!mounted) return;
          final permissions =
              await _pluginRegistryRepository.getPluginPermissions(
            widget.plugin.pluginId,
          );
          if (!mounted) return;
          final bootPayload = {
            'plugin': {
              'id': widget.plugin.pluginId,
              'version': widget.plugin.version,
            },
            'app': {
              'version': packageInfo.version,
              'platform': Platform.operatingSystem,
              'locale': 'he-IL',
              'textDirection': 'rtl',
            },
            'theme': theme,
            'permissions': permissions
                .where((permission) => permission.granted)
                .map((permission) => permission.permission)
                .toList(),
          };

          final jsonPayload = jsonEncode(bootPayload);
          final fontFaceJson = jsonEncode(fontFaceCss);

          // Real SDK — injected after load, calls _boot() which re-plays queued
          // Otzaria.on() calls and then fires plugin.boot
          await controller.evaluateJavascript(source: '''
(function () {
  try {
    var __css = $fontFaceJson;
    if (__css) {
      var __style = document.createElement('style');
      __style.setAttribute('data-otzaria-fonts', '1');
      __style.appendChild(document.createTextNode(__css));
      (document.head || document.documentElement).appendChild(__style);
    }
  } catch (e) { console.error('font-face inject failed', e); }
  var _ls = {};
  var realSdk = {
    call: function (method, payload) {
      return window.flutter_inappwebview.callHandler('otzaria_rpc', {
        method: method,
        payload: payload || {}
      });
    },
    on: function (event, cb) {
      if (!_ls[event]) _ls[event] = [];
      var w = function (e) { cb(e.detail); };
      _ls[event].push({ orig: cb, wrap: w });
      window.addEventListener(event, w);
    },
    off: function (event, cb) {
      var list = _ls[event];
      if (!list) return;
      for (var i = 0; i < list.length; i++) {
        if (list[i].orig === cb) {
          window.removeEventListener(event, list[i].wrap);
          list.splice(i, 1);
          break;
        }
      }
    }
  };
  window.Otzaria._boot(realSdk, $jsonPayload);
})();
''');
          // הטעינה הצליחה עד הסוף (גם ה-stub וגם ה-boot payload הוזרקו).
          // מסירים את התוסף מ-quarantine כדי שהפעלה הבאה תאפשר טעינה רגילה.
          unawaited(PluginCrashGuard.markLoadSuccess(widget.plugin.pluginId));
        } catch (e, st) {
          // Boot ב-Dart נכשל — התהליך חי, לא קריסה native. מנקים את ה-canary
          // כדי שלא נחסום בהפעלה הבאה תוסף שפשוט החזיר שגיאת אתחול רגילה.
          unawaited(PluginCrashGuard.markLoadSuccess(widget.plugin.pluginId));
          debugPrint('Plugin [${widget.plugin.pluginId}] boot error: $e\n$st');
          PluginSystemDatabase.instance
              .writeLog(widget.plugin.pluginId, 'ERROR', 'Boot failed: $e');
          if (!mounted) return;
          if (widget.plugin.isDevelopment) {
            setState(() => _devErrorMessage = 'plugins.tab.plugin_init_error'
                .tr(namedArgs: {'error': '$e'}));
          } else {
            setState(() => _hasError = true);
          }
        }
      },
      onReceivedError: (controller, request, error) {
        // only fail the view for the entrypoint file load itself
        if (request.url.scheme == 'file') {
          // שגיאת רשת/קובץ נתפסה ב-Dart — התהליך חי, לא קריסה native.
          // מנקים את ה-canary כדי שלא נחסום שגיאה רגילה כ"קריסה".
          unawaited(PluginCrashGuard.markLoadSuccess(widget.plugin.pluginId));
          if (mounted) setState(() => _hasError = true);
        }
      },
      onConsoleMessage: (controller, consoleMessage) {
        try {
          if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR ||
              consoleMessage.messageLevel == ConsoleMessageLevel.WARNING) {
            PluginSystemDatabase.instance.writeLog(widget.plugin.pluginId,
                consoleMessage.messageLevel.toString(), consoleMessage.message);
          }
          debugPrint(
              'Plugin [${widget.plugin.pluginId}]: ${consoleMessage.message}');
        } catch (e) {
          debugPrint(
              'Plugin [${widget.plugin.pluginId}] console log error: $e');
        }
      },
    );

    if (!Platform.isWindows) return webView;

    return Listener(
      onPointerPanZoomUpdate: (event) {
        final ctrl = webViewController;
        if (ctrl == null) return;
        _pendingTrackpadDelta += event.panDelta;
        if (_trackpadFrameScheduled) return;
        _trackpadFrameScheduled = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _trackpadFrameScheduled = false;
          if (!mounted) return;
          final delta = _pendingTrackpadDelta;
          _pendingTrackpadDelta = Offset.zero;
          ctrl.evaluateJavascript(source: buildTrackpadScrollJs(delta));
        });
      },
      child: webView,
    );
  }

  static bool get _needsWebViewPrerequisites {
    return !kIsWeb && (Platform.isAndroid || Platform.isWindows);
  }

  static Future<void> _ensureWebViewPrerequisitesConfigured() {
    return _webViewPrerequisitesFuture ??= _configureWebViewPrerequisites();
  }

  static Future<void> _configureWebViewPrerequisites() async {
    if (Platform.isAndroid) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
    }
    if (Platform.isWindows) {
      await WebViewEnvironmentHolder.initialize();
    }
  }
}

/// בונה פקודת JavaScript לגלילת WebView בתגובה ל-PointerPanZoomUpdate.
///
/// [panDelta] — כמות הגלילה בפיקסלים (תנועת האצבעות בלוח המגע).
/// ערך חיובי ב-dy גורם לגלילה למטה; חיובי ב-dx — גלילה ימינה.
@visibleForTesting
String buildTrackpadScrollJs(Offset panDelta) =>
    'window.scrollBy(${panDelta.dx.toStringAsFixed(2)},${panDelta.dy.toStringAsFixed(2)});';
