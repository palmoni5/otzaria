import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';

enum _PluginRuntimeShutdownMode { idle, restart }

/// מזהה ייחודי לכל instance של webview (foreground/background) של אותו plugin.
typedef PluginInstanceId = String;

class PluginRuntimeDispatcher {
  static final PluginRuntimeDispatcher instance = PluginRuntimeDispatcher._();
  PluginRuntimeDispatcher._();

  /// מיפוי pluginId → רשימת controllers פעילים. תוסף יכול לרוץ בכמה
  /// מקומות במקביל: instance רגיל ב-PluginTabPage + instance רקע
  /// ב-PluginBackgroundHost כשהוענקה ההרשאה `app.run_on_startup`.
  final Map<String, Map<PluginInstanceId, InAppWebViewController>>
      _controllersByPlugin = {};
  final PluginRegistryRepository _repository = PluginRegistryRepository();
  _PluginRuntimeShutdownMode _shutdownMode = _PluginRuntimeShutdownMode.idle;

  // Cache in-memory למניעת שאילתות SQLite חוזרות במסלול החם
  final Map<String, bool> _enabledCache = {};
  final Map<String, Map<String, bool?>> _permissionCache = {};

  /// callback לטעינה מחדש של תוסף — מופעל פר instance כדי שכל
  /// host יוכל לרענן את ה-webview שלו בנפרד.
  final Map<String, Map<PluginInstanceId, Future<void> Function()>>
      _reloadCallbacks = {};

  void registerController(
    String pluginId,
    InAppWebViewController controller, {
    PluginInstanceId instanceId = 'default',
  }) {
    _shutdownMode = _PluginRuntimeShutdownMode.idle;
    final instances = _controllersByPlugin.putIfAbsent(pluginId, () => {});
    instances[instanceId] = controller;
  }

  void unregisterController(
    String pluginId, {
    PluginInstanceId instanceId = 'default',
  }) {
    final instances = _controllersByPlugin[pluginId];
    if (instances != null) {
      instances.remove(instanceId);
      if (instances.isEmpty) {
        _controllersByPlugin.remove(pluginId);
      }
    }
    // ה-cache הוא ברמת ה-plugin; ננקה רק כשלא נשאר אף instance.
    if (_controllersByPlugin[pluginId] == null) {
      _enabledCache.remove(pluginId);
      _permissionCache.remove(pluginId);
    }
  }

  /// מנקה את ה-cache של תוסף ספציפי - יש לקרוא כשמשתמש משנה enabled/permissions
  void invalidatePlugin(String pluginId) {
    _enabledCache.remove(pluginId);
    _permissionCache.remove(pluginId);
  }

  Future<void> prepareForAppRestart() async {
    await _prepareControllersForTeardown(_PluginRuntimeShutdownMode.restart);
  }

  Future<void> _prepareControllersForTeardown(
    _PluginRuntimeShutdownMode shutdownMode,
  ) async {
    _shutdownMode = shutdownMode;
    final allControllers = <InAppWebViewController>[];
    for (final instances in _controllersByPlugin.values) {
      allControllers.addAll(instances.values);
    }

    _controllersByPlugin.clear();
    _enabledCache.clear();
    _permissionCache.clear();
    _reloadCallbacks.clear();

    for (final controller in allControllers) {
      try {
        await controller.loadUrl(
          urlRequest: URLRequest(
            url: WebUri.uri(Uri.parse('about:blank')),
          ),
        );
      } catch (e) {
        // The underlying WebView may already be tearing down.
        debugPrint(
            'PluginRuntimeDispatcher: error during controller teardown: $e');
      }
    }
  }

  void registerReloadCallback(
    String pluginId,
    Future<void> Function() callback, {
    PluginInstanceId instanceId = 'default',
  }) {
    final instances = _reloadCallbacks.putIfAbsent(pluginId, () => {});
    instances[instanceId] = callback;
  }

  void unregisterReloadCallback(
    String pluginId, {
    PluginInstanceId instanceId = 'default',
  }) {
    final instances = _reloadCallbacks[pluginId];
    if (instances != null) {
      instances.remove(instanceId);
      if (instances.isEmpty) {
        _reloadCallbacks.remove(pluginId);
      }
    }
  }

  Future<void> reloadPlugin(String pluginId) async {
    if (_shutdownMode != _PluginRuntimeShutdownMode.idle) return;
    final callbacks = _reloadCallbacks[pluginId];
    if (callbacks == null || callbacks.isEmpty) return;
    // עותק כדי לא לקרוס אם callback משתמש ב-unregister באמצעו
    final snapshot = callbacks.values.toList(growable: false);
    for (final cb in snapshot) {
      await cb();
    }
  }

  Future<void> dispatchEvent(String topic, Map<String, dynamic> payload) async {
    if (_shutdownMode != _PluginRuntimeShutdownMode.idle) return;
    final jsonPayload = jsonEncode(payload);
    debugPrint('PluginRuntimeDispatcher: Dispatching $topic');

    for (final entry in _controllersByPlugin.entries) {
      final pluginId = entry.key;
      final instances = entry.value;
      if (instances.isEmpty) continue;

      try {
        // בדוק שהתוסף מופעל - עם cache למניעת שאילתות SQLite חוזרות
        final isEnabled =
            _enabledCache[pluginId] ?? await _repository.getIsEnabled(pluginId);
        _enabledCache[pluginId] = isEnabled;
        if (!isEnabled) continue;

        // בדוק הרשאה - עם cache
        _permissionCache[pluginId] ??= {};
        final permKey = 'events.subscribe:$topic';
        if (!_permissionCache[pluginId]!.containsKey(permKey)) {
          _permissionCache[pluginId]![permKey] =
              await _repository.getPermission(pluginId, permKey);
        }
        if (_permissionCache[pluginId]![permKey] != true) continue;

        // כשקיים instance foreground ('default') ו-instance background במקביל,
        // שולחים רק ל-foreground — מונע כפילות של handlers גלובליים.
        final targetControllers = instances.containsKey('default')
            ? [instances['default']!]
            : instances.values.toList();
        for (final controller in targetControllers) {
          try {
            await controller.evaluateJavascript(
                source:
                    "window.dispatchEvent(new CustomEvent('$topic', { detail: $jsonPayload }));");
          } catch (e) {
            debugPrint('Failed to dispatch $topic to plugin $pluginId: $e');
          }
        }
      } catch (e) {
        debugPrint('Failed to dispatch $topic to plugin $pluginId: $e');
      }
    }
  }

  /// שולח event לפלאגין ספציפי בלבד (ללא בדיקת הרשאת subscribe).
  /// משמש לאירועים ממוקדים כמו reader.context_menu_item_clicked.
  Future<void> dispatchEventToPlugin(
    String pluginId,
    String topic,
    Map<String, dynamic> payload,
  ) async {
    if (_shutdownMode != _PluginRuntimeShutdownMode.idle) return;
    final instances = _controllersByPlugin[pluginId];
    if (instances == null || instances.isEmpty) return;
    try {
      final isEnabled =
          _enabledCache[pluginId] ?? await _repository.getIsEnabled(pluginId);
      _enabledCache[pluginId] = isEnabled;
      if (!isEnabled) return;
      final jsonPayload = jsonEncode(payload);
      final targetControllers = instances.containsKey('default')
          ? [instances['default']!]
          : instances.values.toList();
      for (final controller in targetControllers) {
        try {
          await controller.evaluateJavascript(
            source:
                "window.dispatchEvent(new CustomEvent('$topic', { detail: $jsonPayload }));",
          );
        } catch (e) {
          debugPrint('Failed to dispatch $topic to plugin $pluginId: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed to dispatch $topic to plugin $pluginId: $e');
    }
  }
}
