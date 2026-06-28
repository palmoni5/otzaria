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

  /// קיצורי "פתיחת כלי" אופציונליים (deep-link `otzaria://open/tool/<id>`).
  /// כל מפתח חייב להופיע גם ב-[shortcutKeys], [defaultShortcuts] (ריק), [shortcutNames].
  static const Map<String, String> openToolShortcutKeys = {
    'key-shortcut-open-tool-calendar': 'builtin.calendar',
    'key-shortcut-open-tool-shamor-zachor': 'builtin.shamor_zachor',
    'key-shortcut-open-tool-measurements': 'builtin.measurements',
    'key-shortcut-open-tool-notes': 'builtin.notes',
    'key-shortcut-open-tool-gematria': 'builtin.gematria',
    'key-shortcut-open-tool-aramaic-dictionary': 'builtin.aramaic_dictionary',
    'key-shortcut-open-tool-acronyms-dictionary': 'builtin.acronyms_dictionary',
  };

  /// קיצורי "העתק קישור" אופציונליים. הקיצור פועל לפי הטאב הפעיל: קישור למקטע
  /// בספר טקסט, וקישור לעמוד ב-PDF — שניהם תחת אותו מפתח. שני האחרונים רלוונטיים
  /// לספר טקסט בלבד (PDF אינו תומך בהדגשת מקטע/טקסט).
  static const String copyBookLinkKey = 'key-shortcut-copy-book-link';
  static const String copySectionLinkKey = 'key-shortcut-copy-section-link';
  static const String copySectionMarkLinkKey =
      'key-shortcut-copy-section-mark-link';
  static const String copyTextMarkLinkKey = 'key-shortcut-copy-text-mark-link';

  static const List<String> copyLinkShortcutKeys = [
    copyBookLinkKey,
    copySectionLinkKey,
    copySectionMarkLinkKey,
    copyTextMarkLinkKey,
  ];

  static const String _openPluginKeyPrefix = 'key-shortcut-open-plugin-';

  /// מפתח הגדרת הקיצור לפתיחת תוסף לפי מזההו (deep-link
  /// `otzaria://open/plugin/<id>`). אופציונלי, ללא ברירת מחדל.
  static String openPluginShortcutKey(String pluginId) =>
      '$_openPluginKeyPrefix$pluginId';

  /// קיצורי "פתיחת תוסף" נרשמים דינמית לפי התוספים המותקנים הפעילים (מפתח →
  /// שם תצוגה), כדי שזיהוי הקונפליקטים והתצוגה יכירו בהם. נדחף מ-PluginSystemBloc.
  static Map<String, String> _pluginShortcutNames = const {};

  static void registerPluginShortcutKeys(Map<String, String> keyToName) {
    _pluginShortcutNames = Map.unmodifiable(keyToName);
  }

  /// המפתחות של קיצורי "פתיחת תוסף" הרשומים כעת (תוספים פעילים בלבד).
  static Iterable<String> get pluginShortcutKeys => _pluginShortcutNames.keys;

  /// מחלץ את מזהה התוסף ממפתח קיצור "פתיחת תוסף".
  static String pluginIdFromShortcutKey(String key) =>
      key.substring(_openPluginKeyPrefix.length);

  /// List of all shortcut setting keys (סטטיים + מפתחות תוספים רשומים)
  static List<String> get shortcutKeys =>
      [..._baseShortcutKeys, ..._pluginShortcutNames.keys];

  static const List<String> _baseShortcutKeys = [
    'key-shortcut-open-library-browser',
    currentWindowSearchKey,
    'key-shortcut-open-find-ref',
    'key-shortcut-close-tab',
    'key-shortcut-close-all-tabs',
    'key-shortcut-restore-closed-tab',
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
    'key-shortcut-prev-segment',
    'key-shortcut-next-segment',
    'key-shortcut-prev-toc',
    'key-shortcut-next-toc',
    // פתיחת כלים — אופציונלי, ללא ברירת מחדל (ראה openToolShortcutKeys).
    'key-shortcut-open-tool-calendar',
    'key-shortcut-open-tool-shamor-zachor',
    'key-shortcut-open-tool-measurements',
    'key-shortcut-open-tool-notes',
    'key-shortcut-open-tool-gematria',
    'key-shortcut-open-tool-aramaic-dictionary',
    'key-shortcut-open-tool-acronyms-dictionary',
    // העתקת קישורים — אופציונלי, ללא ברירת מחדל (ראה copyLinkShortcutKeys).
    copyBookLinkKey,
    copySectionLinkKey,
    copySectionMarkLinkKey,
    copyTextMarkLinkKey,
  ];

  /// Default values for shortcuts
  static const Map<String, String> defaultShortcuts = {
    'key-shortcut-open-library-browser': 'ctrl+l',
    currentWindowSearchKey: 'ctrl+f',
    'key-shortcut-open-find-ref': 'ctrl+o',
    'key-shortcut-close-tab': 'ctrl+w',
    'key-shortcut-close-all-tabs': 'ctrl+shift+w',
    'key-shortcut-restore-closed-tab': 'ctrl+shift+t',
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
    'key-shortcut-calendar-toggle-times': 'ctrl+t',
    'key-shortcut-calendar-toggle-events': 'ctrl+e',
    'key-shortcut-calendar-today': 'ctrl+d',
    'key-shortcut-calendar-create-event': 'ctrl+shift+n',
    'key-shortcut-calendar-toggle-view': 'ctrl+shift+e',
    'key-shortcut-shamor-zachor-cycle-filter': 'ctrl+s',
    'key-shortcut-toggle-nav-pane': 'ctrl+shift+l',
    'key-shortcut-toggle-commentators-pane': 'ctrl+shift+c',
    'key-shortcut-open-commentators-tab': '',
    'key-shortcut-prev-segment': 'alt+arrowup',
    'key-shortcut-next-segment': 'alt+arrowdown',
    'key-shortcut-prev-toc': 'alt+pageup',
    'key-shortcut-next-toc': 'alt+pagedown',
    'key-shortcut-open-tool-calendar': '',
    'key-shortcut-open-tool-shamor-zachor': '',
    'key-shortcut-open-tool-measurements': '',
    'key-shortcut-open-tool-notes': '',
    'key-shortcut-open-tool-gematria': '',
    'key-shortcut-open-tool-aramaic-dictionary': '',
    'key-shortcut-open-tool-acronyms-dictionary': '',
    copyBookLinkKey: '',
    copySectionLinkKey: '',
    copySectionMarkLinkKey: '',
    copyTextMarkLinkKey: '',
  };

  /// Shortcut names for display (translated at access time + שמות תוספים רשומים)
  static Map<String, String> get shortcutNames =>
      {..._baseShortcutNames, ..._pluginShortcutNames};

  static Map<String, String> get _baseShortcutNames => {
        'key-shortcut-open-library-browser': 'settings.shortcuts.library'.tr(),
        currentWindowSearchKey:
            'settings.shortcuts.current_window_search'.tr(),
        'key-shortcut-open-find-ref': 'settings.shortcuts.find_ref'.tr(),
        'key-shortcut-close-tab': 'settings.shortcuts.close_tab'.tr(),
        'key-shortcut-close-all-tabs':
            'settings.shortcuts.close_all_tabs'.tr(),
        'key-shortcut-restore-closed-tab':
            'settings.shortcuts.restore_closed_tab'.tr(),
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
        'key-shortcut-prev-segment': 'settings.shortcuts.prev_segment'.tr(),
        'key-shortcut-next-segment': 'settings.shortcuts.next_segment'.tr(),
        'key-shortcut-prev-toc': 'settings.shortcuts.prev_toc'.tr(),
        'key-shortcut-next-toc': 'settings.shortcuts.next_toc'.tr(),
        'key-shortcut-open-tool-calendar':
            'settings.shortcuts.open_tool_calendar'.tr(),
        'key-shortcut-open-tool-shamor-zachor':
            'settings.shortcuts.open_tool_shamor_zachor'.tr(),
        'key-shortcut-open-tool-measurements':
            'settings.shortcuts.open_tool_measurements'.tr(),
        'key-shortcut-open-tool-notes':
            'settings.shortcuts.open_tool_notes'.tr(),
        'key-shortcut-open-tool-gematria':
            'settings.shortcuts.open_tool_gematria'.tr(),
        'key-shortcut-open-tool-aramaic-dictionary':
            'settings.shortcuts.open_tool_aramaic_dictionary'.tr(),
        'key-shortcut-open-tool-acronyms-dictionary':
            'settings.shortcuts.open_tool_acronyms_dictionary'.tr(),
        copyBookLinkKey: 'settings.shortcuts.copy_book_link'.tr(),
        copySectionLinkKey: 'settings.shortcuts.copy_section_link'.tr(),
        copySectionMarkLinkKey:
            'settings.shortcuts.copy_section_mark_link'.tr(),
        copyTextMarkLinkKey: 'settings.shortcuts.copy_text_mark_link'.tr(),
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
