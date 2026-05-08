import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

/// Validator for keyboard shortcuts to detect conflicts
class ShortcutValidator {
  static const String currentWindowSearchKey =
      'key-shortcut-search-current-window';
  static const String legacySearchInBookKey = 'key-shortcut-search-in-book';

  static const Set<Set<String>> _compatibleShortcutGroups = {
    {
      'key-shortcut-add-note',
      'key-shortcut-calendar-toggle-events',
    },
    {
      'key-shortcut-calendar-toggle-times',
      'key-shortcut-shamor-zachor-cycle-filter',
    },
  };

  static const Map<String, List<String>> legacyShortcutAliases = {
    currentWindowSearchKey: [legacySearchInBookKey],
  };

  /// List of all shortcut setting keys
  static const List<String> shortcutKeys = [
    'key-shortcut-open-library-browser',
    currentWindowSearchKey,
    'key-shortcut-open-find-ref',
    'key-shortcut-close-tab',
    'key-shortcut-close-all-tabs',
    'key-shortcut-open-reading-screen',
    'key-shortcut-open-new-search',
    'key-shortcut-open-settings',
    'key-shortcut-open-more',
    'key-shortcut-open-bookmarks',
    'key-shortcut-open-history',
    'key-shortcut-add-bookmark',
    'key-shortcut-add-note',
    'key-shortcut-switch-workspace',
    'key-shortcut-print',
    'key-shortcut-toggle-pdf-view',
    'key-shortcut-calendar-toggle-times',
    'key-shortcut-calendar-toggle-events',
    'key-shortcut-calendar-today',
    'key-shortcut-calendar-create-event',
    'key-shortcut-calendar-toggle-view',
    'key-shortcut-shamor-zachor-cycle-filter',
    'key-shortcut-toggle-nav-pane',
    'key-shortcut-toggle-commentators-pane',
    'key-shortcut-open-commentators-tab',
  ];

  /// Default values for shortcuts
  static const Map<String, String> defaultShortcuts = {
    'key-shortcut-open-library-browser': 'ctrl+l',
    currentWindowSearchKey: 'ctrl+f',
    'key-shortcut-open-find-ref': 'ctrl+o',
    'key-shortcut-close-tab': 'ctrl+w',
    'key-shortcut-close-all-tabs': 'ctrl+shift+w',
    'key-shortcut-open-reading-screen': 'ctrl+r',
    'key-shortcut-open-new-search': 'ctrl+shift+f',
    'key-shortcut-open-settings': 'ctrl+comma',
    'key-shortcut-open-more': 'ctrl+m',
    'key-shortcut-open-bookmarks': 'ctrl+shift+b',
    'key-shortcut-open-history': 'ctrl+h',
    'key-shortcut-add-bookmark': 'ctrl+b',
    'key-shortcut-add-note': 'ctrl+n',
    'key-shortcut-switch-workspace': 'ctrl+k',
    'key-shortcut-print': 'ctrl+p',
    'key-shortcut-toggle-pdf-view': 'ctrl+shift+p',
    'key-shortcut-calendar-toggle-times': 'ctrl+e',
    'key-shortcut-calendar-toggle-events': 'ctrl+n',
    'key-shortcut-calendar-today': 'ctrl+d',
    'key-shortcut-calendar-create-event': 'ctrl+shift+n',
    'key-shortcut-calendar-toggle-view': 'ctrl+shift+e',
    'key-shortcut-shamor-zachor-cycle-filter': 'ctrl+e',
    'key-shortcut-toggle-nav-pane': 'ctrl+shift+l',
    'key-shortcut-toggle-commentators-pane': 'ctrl+shift+c',
    'key-shortcut-open-commentators-tab': '',
  };

  /// Shortcut names for display (translated at access time)
  static Map<String, String> get shortcutNames => {
        'key-shortcut-open-library-browser': 'settings.shortcuts.library'.tr(),
        currentWindowSearchKey:
            'settings.shortcuts.current_window_search'.tr(),
        'key-shortcut-open-find-ref': 'settings.shortcuts.find_ref'.tr(),
        'key-shortcut-close-tab': 'settings.shortcuts.close_tab'.tr(),
        'key-shortcut-close-all-tabs':
            'settings.shortcuts.close_all_tabs'.tr(),
        'key-shortcut-open-reading-screen':
            'settings.shortcuts.reading_screen'.tr(),
        'key-shortcut-open-new-search': 'settings.shortcuts.new_search'.tr(),
        'key-shortcut-open-settings': 'settings.shortcuts.settings'.tr(),
        'key-shortcut-open-more': 'settings.shortcuts.tools'.tr(),
        'key-shortcut-open-bookmarks': 'settings.shortcuts.bookmarks'.tr(),
        'key-shortcut-open-history': 'settings.shortcuts.history'.tr(),
        'key-shortcut-add-bookmark': 'settings.shortcuts.add_bookmark'.tr(),
        'key-shortcut-add-note': 'settings.shortcuts.add_note'.tr(),
        'key-shortcut-switch-workspace':
            'settings.shortcuts.switch_workspace'.tr(),
        'key-shortcut-print': 'settings.shortcuts.print'.tr(),
        'key-shortcut-toggle-pdf-view':
            'settings.shortcuts.toggle_pdf_view'.tr(),
        'key-shortcut-calendar-toggle-times':
            'settings.shortcuts.calendar_toggle_times'.tr(),
        'key-shortcut-calendar-toggle-events':
            'settings.shortcuts.calendar_toggle_events'.tr(),
        'key-shortcut-calendar-today':
            'settings.shortcuts.calendar_today'.tr(),
        'key-shortcut-calendar-create-event':
            'settings.shortcuts.calendar_create_event'.tr(),
        'key-shortcut-calendar-toggle-view':
            'settings.shortcuts.calendar_toggle_view'.tr(),
        'key-shortcut-shamor-zachor-cycle-filter':
            'settings.shortcuts.shamor_zachor_cycle_filter'.tr(),
        'key-shortcut-toggle-nav-pane':
            'settings.shortcuts.toggle_nav_pane'.tr(),
        'key-shortcut-toggle-commentators-pane':
            'settings.shortcuts.toggle_commentators_pane'.tr(),
        'key-shortcut-open-commentators-tab':
            'settings.shortcuts.open_commentators_tab'.tr(),
      };

  /// Check for conflicts in current shortcuts
  /// Returns a map of conflicting shortcuts: {shortcut: [key1, key2, ...]}
  static Map<String, List<String>> checkConflicts() {
    final Map<String, List<String>> conflicts = {};
    final Map<String, List<String>> shortcutToKeys = {};

    for (final key in shortcutKeys) {
      final value = getShortcutValue(key) ?? '';
      if (value.isNotEmpty) {
        shortcutToKeys.putIfAbsent(value, () => []).add(key);
      }
    }

    for (final entry in shortcutToKeys.entries) {
      final conflictingKeys = entry.value;
      if (conflictingKeys.length > 1 &&
          !_isCompatibleGroup(conflictingKeys.toSet())) {
        conflicts[entry.key] = conflictingKeys;
      }
    }

    return conflicts;
  }

  /// Get a human-readable description of conflicts
  static String getConflictsDescription() {
    final conflicts = checkConflicts();

    if (conflicts.isEmpty) {
      return 'settings.shortcuts.conflicts_none'.tr();
    }

    final buffer = StringBuffer('settings.shortcuts.conflicts_found'.tr());

    for (final entry in conflicts.entries) {
      final shortcut = entry.key;
      final keys = entry.value;

      buffer.writeln('settings.shortcuts.conflict_used_for'
          .tr(namedArgs: {'shortcut': shortcut}));
      for (final key in keys) {
        final name = shortcutNames[key] ?? key;
        buffer.writeln('  • $name');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Check if a specific shortcut has conflicts
  static bool hasConflict(String settingKey) {
    final value = getShortcutValue(settingKey);
    if (value == null || value.isEmpty) return false;

    final matchingKeys = <String>{};
    for (final key in shortcutKeys) {
      final keyValue = getShortcutValue(key) ?? '';
      if (keyValue == value) {
        matchingKeys.add(key);
      }
    }

    return matchingKeys.length > 1 && !_isCompatibleGroup(matchingKeys);
  }

  /// מחזיר את ערך הקיצור הנוכחי עבור [settingKey] או את ברירת המחדל שלו.
  static String? getShortcutValue(String settingKey) {
    final normalizedKey = canonicalSettingKey(settingKey);
    final directValue = Settings.getValue<String>(normalizedKey);
    if (directValue != null && directValue.isNotEmpty) {
      return directValue;
    }

    for (final legacyKey in legacyShortcutAliases[normalizedKey] ?? const []) {
      final legacyValue = Settings.getValue<String>(legacyKey);
      if (legacyValue != null && legacyValue.isNotEmpty) {
        return legacyValue;
      }
    }

    return defaultShortcuts[normalizedKey];
  }

  static bool canShareShortcut(String firstKey, String secondKey) {
    final normalizedFirst = canonicalSettingKey(firstKey);
    final normalizedSecond = canonicalSettingKey(secondKey);
    if (normalizedFirst == normalizedSecond) return true;

    for (final group in _compatibleShortcutGroups) {
      if (group.contains(normalizedFirst) && group.contains(normalizedSecond)) {
        return true;
      }
    }

    return false;
  }

  static String canonicalSettingKey(String settingKey) {
    if (settingKey == legacySearchInBookKey) {
      return currentWindowSearchKey;
    }
    return settingKey;
  }

  static Set<String> legacyKeysFor(String settingKey) {
    final normalizedKey = canonicalSettingKey(settingKey);
    return Set<String>.from(legacyShortcutAliases[normalizedKey] ?? const []);
  }

  static bool _isCompatibleGroup(Set<String> keys) {
    if (keys.length < 2) return false;

    final normalizedKeys = keys.map(canonicalSettingKey).toSet();
    for (final group in _compatibleShortcutGroups) {
      if (group.containsAll(normalizedKeys)) {
        return true;
      }
    }

    return false;
  }
}
