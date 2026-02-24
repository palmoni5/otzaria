import 'package:hive/hive.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

// Conditional imports for platform-specific initialization
import 'hive_data_provider_stub.dart'
    if (dart.library.io) 'hive_data_provider_io.dart'
    if (dart.library.html) 'hive_data_provider_web.dart';

/// A cache access provider class for shared preferences using Hive library
class HiveCache extends CacheProvider {
  Box? _preferences;
  final String keyName = 'app_preferences';

  @override
  Future<void> init() async {
    // Initialize Hive with platform-specific configuration
    await initHive();
    
    _preferences = Hive.box(
      name: keyName,
      maxSizeMiB: 100,
    );
  }

  Set get keys => getKeys();

  @override
  bool? getBool(String key, {bool? defaultValue}) {
    return _preferences?.get(key);
  }

  @override
  double? getDouble(String key, {double? defaultValue}) {
    return _preferences?.get(key);
  }

  @override
  int? getInt(String key, {int? defaultValue}) {
    return _preferences?.get(key);
  }

  @override
  String? getString(String key, {String? defaultValue}) {
    return _preferences?.get(key);
  }

  @override
  Future<void> setBool(String key, bool? value) async {
    _preferences?.put(key, value);
  }

  @override
  Future setDouble(String key, double? value) async {
    _preferences?.put(key, value);
  }

  @override
  Future<void> setInt(String key, int? value) async {
    _preferences?.put(key, value);
  }

  @override
  Future<void> setString(String key, String? value) async {
    _preferences?.put(key, value);
  }

  @override
  Future<void> setObject<T>(String key, T? value) async {
    _preferences?.put(key, value);
  }

  @override
  bool containsKey(String key) {
    return _preferences?.containsKey(key) ?? false;
  }

  @override
  Set getKeys() {
    return _preferences?.keys.toSet() ?? {};
  }

  @override
  Future<void> remove(String key) async {
    if (containsKey(key)) {
      _preferences?.delete(key);
    }
  }

  @override
  Future<void> removeAll() async {
    final keys = getKeys();
    _preferences?.deleteAll(keys.where((element) => true) as Iterable<String>);
  }

  @override
  T? getValue<T>(String key, {T? defaultValue}) {
    var value = _preferences?.get(key);
    if (value is T) {
      return value;
    }
    return defaultValue;
  }
}
