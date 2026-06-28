import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/utils/fluent_icon_resolver.dart';
import 'package:otzaria/settings/engine/settings_engine_exports.dart';
import 'package:otzaria/settings/search/settings_anchor.dart';
import 'package:otzaria/settings/search/settings_search_models.dart';
import 'package:otzaria/settings/view/settings_screen.dart';
import 'package:otzaria/shortcuts/shortcut_helper.dart';
import 'package:otzaria/shortcuts/view/custom_shortcut_dialog.dart';
import 'package:otzaria/shortcuts/view/shortcut_dropdown_tile.dart';
import 'package:otzaria/shortcuts/shortcut_validator.dart';
import 'package:otzaria/widgets/widgets_exports.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/settings/widgets/settings_widgets_exports.dart';
import 'package:otzaria/tour/tour_target_keys.dart';

/// טאב קיצורי מקלדת — מוצג רק בדסקטופ.
class ShortcutsSettingsTab extends StatelessWidget {
  const ShortcutsSettingsTab({super.key});

  /// פריטי חיפוש בהגדרות. נסרק על-ידי tool/generate_search_index.dart.
  static const List<SettingsSearchEntry> searchEntries = [
    SettingsSearchEntry(
      id: 'shortcuts.reset',
      title: 'settings.search.shortcuts_reset_title',
      subtitle: 'settings.search.shortcuts_reset_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_reset_kw'],
    ),
    // ── ניווט כללי ──
    SettingsSearchEntry(
      id: 'shortcuts.nav.library',
      title: 'settings.search.shortcuts_nav_library_title',
      subtitle: 'settings.search.shortcuts_nav_library_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_nav_library_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.nav.find_ref',
      title: 'settings.search.shortcuts_nav_find_ref_title',
      subtitle: 'settings.search.shortcuts_nav_find_ref_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_nav_find_ref_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.nav.reading',
      title: 'settings.search.shortcuts_nav_reading_title',
      subtitle: 'settings.search.shortcuts_nav_reading_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_nav_reading_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.nav.search_window',
      title: 'settings.search.shortcuts_nav_search_window_title',
      subtitle: 'settings.search.shortcuts_nav_search_window_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_nav_search_window_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.nav.settings',
      title: 'settings.search.shortcuts_nav_settings_title',
      subtitle: 'settings.search.shortcuts_nav_settings_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_nav_settings_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.nav.tools',
      title: 'settings.search.shortcuts_nav_tools_title',
      subtitle: 'settings.search.shortcuts_nav_tools_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_nav_tools_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.nav.bookmarks',
      title: 'settings.search.shortcuts_nav_bookmarks_title',
      subtitle: 'settings.search.shortcuts_nav_bookmarks_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_nav_bookmarks_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.nav.history',
      title: 'settings.search.shortcuts_nav_history_title',
      subtitle: 'settings.search.shortcuts_nav_history_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_nav_history_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.nav.workspace',
      title: 'settings.search.shortcuts_nav_workspace_title',
      subtitle: 'settings.search.shortcuts_nav_workspace_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_nav_workspace_kw'],
    ),
    // ── תצוגת ספר ──
    SettingsSearchEntry(
      id: 'shortcuts.book.search_in_book',
      title: 'settings.search.shortcuts_book_search_in_book_title',
      subtitle: 'settings.search.shortcuts_book_search_in_book_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_book_search_in_book_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.print',
      title: 'settings.search.shortcuts_book_print_title',
      subtitle: 'settings.search.shortcuts_book_print_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_book_print_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.bookmark',
      title: 'settings.search.shortcuts_book_bookmark_title',
      subtitle: 'settings.search.shortcuts_book_bookmark_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_book_bookmark_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.note',
      title: 'settings.search.shortcuts_book_note_title',
      subtitle: 'settings.search.shortcuts_book_note_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_book_note_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.close',
      title: 'settings.search.shortcuts_book_close_title',
      subtitle: 'settings.search.shortcuts_book_close_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_book_close_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.close_all',
      title: 'settings.search.shortcuts_book_close_all_title',
      subtitle: 'settings.search.shortcuts_book_close_all_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_book_close_all_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.restore_closed',
      title: 'settings.search.shortcuts_book_restore_closed_title',
      subtitle: 'settings.search.shortcuts_book_restore_closed_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_book_restore_closed_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.toggle_nav_pane',
      title: 'settings.search.shortcuts_book_toggle_nav_pane_title',
      subtitle: 'settings.search.shortcuts_book_toggle_nav_pane_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_book_toggle_nav_pane_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.toggle_commentators_pane',
      title: 'settings.search.shortcuts_book_toggle_commentators_pane_title',
      subtitle: 'settings.search.shortcuts_book_toggle_commentators_pane_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_book_toggle_commentators_pane_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.open_commentators_tab',
      title: 'settings.search.shortcuts_book_open_commentators_tab_title',
      subtitle: 'settings.search.shortcuts_book_open_commentators_tab_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_book_open_commentators_tab_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.toggle_pdf_view',
      title: 'settings.search.shortcuts_book_toggle_pdf_view_title',
      subtitle: 'settings.search.shortcuts_book_toggle_pdf_view_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_book_toggle_pdf_view_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.prev_toc',
      title: 'קיצור לדף/פרק הקודם',
      subtitle: 'מעבר לכותרת הקודמת (דף/פרק) בספר',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['דף', 'פרק', 'ניווט', 'קודם', 'מקלדת'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.next_toc',
      title: 'קיצור לדף/פרק הבא',
      subtitle: 'מעבר לכותרת הבאה (דף/פרק) בספר',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['דף', 'פרק', 'ניווט', 'הבא', 'מקלדת'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.prev_segment',
      title: 'קיצור לקטע הקודם',
      subtitle: 'גלילה לקטע הקודם בספר',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['קטע', 'ניווט', 'קודם', 'גלילה', 'מקלדת'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.book.next_segment',
      title: 'קיצור לקטע הבא',
      subtitle: 'גלילה לקטע הבא בספר',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['קטע', 'ניווט', 'הבא', 'גלילה', 'מקלדת'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.calendar.toggle_times',
      title: 'settings.search.shortcuts_calendar_toggle_times_title',
      subtitle: 'settings.search.shortcuts_calendar_toggle_times_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_calendar_toggle_times_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.calendar.toggle_events',
      title: 'settings.search.shortcuts_calendar_toggle_events_title',
      subtitle: 'settings.search.shortcuts_calendar_toggle_events_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_calendar_toggle_events_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.calendar.today',
      title: 'settings.search.shortcuts_calendar_today_title',
      subtitle: 'settings.search.shortcuts_calendar_today_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_calendar_today_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.calendar.create_event',
      title: 'settings.search.shortcuts_calendar_create_event_title',
      subtitle: 'settings.search.shortcuts_calendar_create_event_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_calendar_create_event_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.calendar.toggle_view',
      title: 'settings.search.shortcuts_calendar_toggle_view_title',
      subtitle: 'settings.search.shortcuts_calendar_toggle_view_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_calendar_toggle_view_kw'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.shamor_zachor.cycle_filter',
      title: 'settings.search.shortcuts_shamor_zachor_cycle_filter_title',
      subtitle: 'settings.search.shortcuts_shamor_zachor_cycle_filter_sub',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['settings.search.shortcuts_shamor_zachor_cycle_filter_kw'],
    ),
    // ── פתיחת כלים ──
    SettingsSearchEntry(
      id: 'shortcuts.open_tool.calendar',
      title: 'קיצור לפתיחת לוח שנה',
      subtitle: 'פתיחה מהירה של כלי לוח השנה',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['לוח שנה', 'כלים', 'פתיחה', 'מקלדת'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.open_tool.shamor_zachor',
      title: 'קיצור לפתיחת שמור וזכור',
      subtitle: 'פתיחה מהירה של כלי שמור וזכור',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['שמור וזכור', 'כלים', 'פתיחה', 'מקלדת'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.open_tool.measurements',
      title: 'קיצור לפתיחת מדות ושיעורים',
      subtitle: 'פתיחה מהירה של כלי מדות ושיעורים',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['מדות', 'שיעורים', 'כלים', 'פתיחה', 'מקלדת'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.open_tool.notes',
      title: 'קיצור לפתיחת הערות אישיות',
      subtitle: 'פתיחה מהירה של כלי ההערות האישיות',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['הערות', 'אישיות', 'כלים', 'פתיחה', 'מקלדת'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.open_tool.gematria',
      title: 'קיצור לפתיחת גימטריה',
      subtitle: 'פתיחה מהירה של כלי הגימטריה',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['גימטריה', 'כלים', 'פתיחה', 'מקלדת'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.open_tool.aramaic_dictionary',
      title: 'קיצור לפתיחת מילון ארמי-עברי',
      subtitle: 'פתיחה מהירה של המילון הארמי-עברי',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['מילון', 'ארמי', 'עברי', 'כלים', 'פתיחה', 'מקלדת'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.open_tool.acronyms_dictionary',
      title: 'קיצור לפתיחת ראשי תיבות',
      subtitle: 'פתיחה מהירה של מילון ראשי התיבות',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['ראשי תיבות', 'מילון', 'כלים', 'פתיחה', 'מקלדת'],
    ),
    // ── העתקת קישורים ──
    SettingsSearchEntry(
      id: 'shortcuts.copy_link.book',
      title: 'קיצור להעתקת קישור ישיר לספר',
      subtitle: 'העתקת קישור ישיר לספר המוצג',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['קישור', 'העתק', 'ספר', 'deep link', 'מקלדת'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.copy_link.section',
      title: 'קיצור להעתקת קישור למקטע / לעמוד',
      subtitle: 'בטקסט — קישור למקטע הנוכחי; ב-PDF — קישור לעמוד הנוכחי',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['קישור', 'העתק', 'מקטע', 'עמוד', 'מקלדת'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.copy_link.section_mark',
      title: 'קיצור להעתקת קישור עם הדגשת המקטע',
      subtitle: 'קישור שמדגיש את המקטע הנוכחי בעת הפתיחה',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['קישור', 'העתק', 'הדגשה', 'מקטע', 'מקלדת'],
    ),
    SettingsSearchEntry(
      id: 'shortcuts.copy_link.text_mark',
      title: 'קיצור להעתקת קישור עם הדגשת הטקסט',
      subtitle: 'קישור שמדגיש את הטקסט המסומן בעת הפתיחה',
      tab: SettingsTab.shortcuts,
      cardId: 'shortcuts.main',
      keywords: ['קישור', 'העתק', 'הדגשה', 'טקסט', 'מקלדת'],
    ),
  ];

  /// אוסף הקיצורים הזמינים לבחירה ב-dropdown. התווית נגזרת דינמית כדי
  /// ש-Mac יציג `⌘` במקום `CTRL`. הערך (המפתח) נשאר קנוני (`ctrl+X`).
  static final Map<String, String> _shortcutsList = _buildShortcutsList();

  static Map<String, String> _buildShortcutsList() {
    const List<String> keys = [
      'ctrl+a',
      'ctrl+b',
      'ctrl+c',
      'ctrl+d',
      'ctrl+e',
      'ctrl+f',
      'ctrl+g',
      'ctrl+h',
      'ctrl+i',
      'ctrl+j',
      'ctrl+k',
      'ctrl+l',
      'ctrl+m',
      'ctrl+n',
      'ctrl+o',
      'ctrl+p',
      'ctrl+q',
      'ctrl+r',
      'ctrl+s',
      'ctrl+t',
      'ctrl+u',
      'ctrl+v',
      'ctrl+w',
      'ctrl+x',
      'ctrl+y',
      'ctrl+z',
      'ctrl+0',
      'ctrl+1',
      'ctrl+2',
      'ctrl+3',
      'ctrl+4',
      'ctrl+5',
      'ctrl+6',
      'ctrl+7',
      'ctrl+8',
      'ctrl+9',
      'ctrl+comma',
      'ctrl+shift+b',
      'ctrl+shift+c',
      'ctrl+shift+e',
      'ctrl+shift+f',
      'ctrl+shift+l',
      'ctrl+shift+n',
      'ctrl+shift+p',
      'ctrl+shift+t',
      'ctrl+shift+w',
    ];
    return {
      for (final k in keys) k: ShortcutHelper.formatShortcutForDisplay(k)
    };
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid || Platform.isIOS) {
      return Center(child: Text('settings.shortcuts.desktop_only'.tr()));
    }

    return SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.all(16.0),
      child: ToolPanelWrapper(
        key: tourShortcutsSettingsTargetKey,
        // עוטף ב-BlocBuilder כדי לרענן את רשימת הטיילים והכרטיס "הוסף קיצור"
        // מיד עם שינוי הקיצורים (פעולה זמינה -> מוגדרת ולהיפך).
        child: BlocBuilder<SettingsBloc, SettingsState>(
          buildWhen: (previous, current) =>
              previous.shortcuts != current.shortcuts,
          builder: (context, _) => _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final unconfiguredKeys = ShortcutValidator.shortcutKeys
        .where((k) => (ShortcutValidator.getShortcutValue(k) ?? '').isEmpty)
        .toList();

    // קיצורי "פתיחת כלים" הם ללא ברירת מחדל, ולכן הכרטיס מוצג רק אם המשתמש
    // הגדיר קיצור לפחות לכלי אחד.
    final openToolTiles = _onlyConfigured([
      _ShortcutTile(
        settingKey: 'key-shortcut-open-tool-calendar',
        label: 'פתיחת לוח שנה',
        icon: FluentIcons.calendar_24_regular,
        allShortcuts: _shortcutsList,
      ),
      _ShortcutTile(
        settingKey: 'key-shortcut-open-tool-shamor-zachor',
        label: 'פתיחת שמור וזכור',
        icon: FluentIcons.checkmark_circle_24_regular,
        allShortcuts: _shortcutsList,
      ),
      _ShortcutTile(
        settingKey: 'key-shortcut-open-tool-measurements',
        label: 'פתיחת מדות ושיעורים',
        icon: FluentIcons.ruler_24_regular,
        allShortcuts: _shortcutsList,
      ),
      _ShortcutTile(
        settingKey: 'key-shortcut-open-tool-notes',
        label: 'פתיחת הערות אישיות',
        icon: FluentIcons.note_24_regular,
        allShortcuts: _shortcutsList,
      ),
      _ShortcutTile(
        settingKey: 'key-shortcut-open-tool-gematria',
        label: 'פתיחת גימטריה',
        icon: FluentIcons.calculator_24_regular,
        allShortcuts: _shortcutsList,
      ),
      _ShortcutTile(
        settingKey: 'key-shortcut-open-tool-aramaic-dictionary',
        label: 'פתיחת מילון ארמי-עברי',
        icon: FluentIcons.translate_24_regular,
        allShortcuts: _shortcutsList,
      ),
      _ShortcutTile(
        settingKey: 'key-shortcut-open-tool-acronyms-dictionary',
        label: 'פתיחת ראשי תיבות',
        icon: FluentIcons.text_quote_24_regular,
        allShortcuts: _shortcutsList,
      ),
    ]);

    // קיצורי "פתיחת תוסף" אופציונליים, לכל תוסף מותקן פעיל. כמו פתיחת כלים,
    // הכרטיס מוצג רק אם הוגדר קיצור לתוסף אחד לפחות.
    final pluginState = context.watch<PluginSystemBloc>().state;
    final enabledPlugins = pluginState is PluginSystemLoaded
        ? pluginState.plugins.where((p) => p.enabled).toList()
        : const <InstalledPlugin>[];
    final openPluginTiles = _onlyConfigured([
      for (final plugin in enabledPlugins)
        _ShortcutTile(
          settingKey: ShortcutValidator.openPluginShortcutKey(plugin.pluginId),
          label: 'פתיחת ${plugin.name}',
          icon: fluentIconFromName(plugin.manifest.toolTabIconName) ??
              FluentIcons.puzzle_piece_24_regular,
          allShortcuts: _shortcutsList,
        ),
    ]);

    // קיצורי "העתקת קישור" אופציונליים, ללא ברירת מחדל. כמו פתיחת כלים,
    // הכרטיס מוצג רק אם הוגדר קיצור לפעולה אחת לפחות.
    final copyLinkTiles = _onlyConfigured([
      _ShortcutTile(
        settingKey: ShortcutValidator.copyBookLinkKey,
        label: 'העתק קישור ישיר לספר',
        icon: FluentIcons.link_24_regular,
        allShortcuts: _shortcutsList,
      ),
      _ShortcutTile(
        settingKey: ShortcutValidator.copySectionLinkKey,
        label: 'העתק קישור למקטע / לעמוד',
        subtitle: 'בטקסט — מקטע; ב-PDF — עמוד',
        icon: FluentIcons.link_multiple_24_regular,
        allShortcuts: _shortcutsList,
      ),
      _ShortcutTile(
        settingKey: ShortcutValidator.copySectionMarkLinkKey,
        label: 'העתק קישור עם הדגשת המקטע',
        icon: FluentIcons.document_one_page_24_regular,
        allShortcuts: _shortcutsList,
      ),
      _ShortcutTile(
        settingKey: ShortcutValidator.copyTextMarkLinkKey,
        label: 'העתק קישור עם הדגשת הטקסט',
        icon: FluentIcons.highlight_24_regular,
        allShortcuts: _shortcutsList,
      ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── כללי (איפוס) ──────────────────────────────────────────────
        SettingsAnchor(
          cardId: 'shortcuts.main',
          child: SettingsCard(
            title: 'settings.shortcuts.general_section'.tr(),
            children: [
              SettingsActionTile.text(
                icon: FluentIcons.arrow_reset_24_regular,
                title: 'settings.shortcuts.reset_title'.tr(),
                subtitle: 'settings.shortcuts.reset_subtitle'.tr(),
                actions: [
                  NeutralActionButton(
                    text: 'settings.shortcuts.reset_button'.tr(),
                    onPressed: () => _resetShortcuts(context),
                  ),
                ],
              ),
            ],
          ),
        ),

        kSettingsCardSpacing,

        // ── ניווט כללי ────────────────────────────────────────────────
        SettingsCard(
          title: 'settings.shortcuts.general_navigation'.tr(),
          children: _onlyConfigured([
            _ShortcutTile(
              settingKey: 'key-shortcut-open-library-browser',
              label: 'settings.shortcuts.library'.tr(),
              icon: FluentIcons.library_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-open-find-ref',
              label: 'settings.shortcuts.find_ref'.tr(),
              icon: FluentIcons.book_search_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-open-reading-screen',
              label: 'settings.shortcuts.reading_screen'.tr(),
              icon: FluentIcons.book_open_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-open-new-search',
              label: 'settings.shortcuts.new_search'.tr(),
              icon: FluentIcons.search_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-open-settings',
              label: 'settings.shortcuts.settings'.tr(),
              icon: FluentIcons.settings_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-open-more',
              label: 'settings.shortcuts.tools'.tr(),
              icon: FluentIcons.apps_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-open-bookmarks',
              label: 'settings.shortcuts.bookmarks'.tr(),
              icon: FluentIcons.bookmark_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-open-history',
              label: 'settings.shortcuts.history'.tr(),
              icon: FluentIcons.history_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-switch-workspace',
              label: 'settings.shortcuts.switch_workspace'.tr(),
              icon: FluentIcons.grid_24_regular,
              allShortcuts: _shortcutsList,
            ),
          ]),
        ),

        kSettingsCardSpacing,

        // ── תצוגת ספר ─────────────────────────────────────────────────
        SettingsCard(
          title: 'settings.shortcuts.book_view'.tr(),
          children: _onlyConfigured([
            _ShortcutTile(
              settingKey: ShortcutValidator.currentWindowSearchKey,
              label: 'settings.shortcuts.current_window_search'.tr(),
              subtitle:
                  'settings.shortcuts.current_window_search_subtitle'.tr(),
              icon: FluentIcons.search_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-print',
              label: 'settings.shortcuts.print'.tr(),
              icon: FluentIcons.print_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-add-bookmark',
              label: 'settings.shortcuts.add_bookmark'.tr(),
              icon: FluentIcons.bookmark_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-add-note',
              label: 'settings.shortcuts.add_note'.tr(),
              icon: FluentIcons.note_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-close-tab',
              label: 'settings.shortcuts.close_tab'.tr(),
              icon: FluentIcons.dismiss_circle_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-close-all-tabs',
              label: 'settings.shortcuts.close_all_tabs'.tr(),
              icon: FluentIcons.dismiss_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-restore-closed-tab',
              label: 'settings.shortcuts.restore_closed_tab'.tr(),
              icon: FluentIcons.arrow_undo_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-toggle-nav-pane',
              label: 'settings.shortcuts.toggle_nav_pane'.tr(),
              icon: FluentIcons.panel_left_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-toggle-commentators-pane',
              label: 'settings.shortcuts.toggle_commentators_pane'.tr(),
              icon: FluentIcons.book_open_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-toggle-pdf-view',
              label: 'settings.shortcuts.toggle_pdf_view'.tr(),
              icon: FluentIcons.document_pdf_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-open-commentators-tab',
              label: 'settings.shortcuts.open_commentators_tab'.tr(),
              icon: FluentIcons.open_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-prev-toc',
              label: 'הדף/פרק הקודם',
              icon: FluentIcons.arrow_previous_24_filled,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-next-toc',
              label: 'הדף/פרק הבא',
              icon: FluentIcons.arrow_next_24_filled,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-prev-segment',
              label: 'הקטע הקודם',
              icon: FluentIcons.chevron_up_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-next-segment',
              label: 'הקטע הבא',
              icon: FluentIcons.chevron_down_24_regular,
              allShortcuts: _shortcutsList,
            ),
          ]),
        ),

        kSettingsCardSpacing,

        // ── לוח שנה ושמור וזכור ───────────────────────────────────────
        SettingsCard(
          title: 'settings.shortcuts.calendar_section'.tr(),
          children: _onlyConfigured([
            _ShortcutTile(
              settingKey: 'key-shortcut-calendar-toggle-times',
              label: 'settings.shortcuts.calendar_toggle_times'.tr(),
              icon: FluentIcons.clock_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-calendar-toggle-events',
              label: 'settings.shortcuts.calendar_toggle_events'.tr(),
              icon: FluentIcons.calendar_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-calendar-today',
              label: 'settings.shortcuts.calendar_today'.tr(),
              icon: FluentIcons.calendar_today_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-calendar-create-event',
              label: 'settings.shortcuts.calendar_create_event'.tr(),
              icon: FluentIcons.calendar_add_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-calendar-toggle-view',
              label: 'settings.shortcuts.calendar_toggle_view'.tr(),
              icon: FluentIcons.calendar_multiple_24_regular,
              allShortcuts: _shortcutsList,
            ),
            _ShortcutTile(
              settingKey: 'key-shortcut-shamor-zachor-cycle-filter',
              label: 'settings.shortcuts.shamor_zachor_cycle_filter'.tr(),
              icon: FluentIcons.filter_24_regular,
              allShortcuts: _shortcutsList,
            ),
          ]),
        ),

        // ── פתיחת כלים (אופציונלי) — מוצג רק כשהוגדר קיצור לכלי אחד לפחות ──
        if (openToolTiles.isNotEmpty) ...[
          kSettingsCardSpacing,
          SettingsCard(
            title: 'פתיחת כלים',
            subtitle: 'קיצורים לפתיחה מהירה של כלי מתוך מסך הכלים',
            children: openToolTiles,
          ),
        ],

        // ── פתיחת תוספים (אופציונלי) — מוצג רק כשהוגדר קיצור לתוסף אחד לפחות ──
        if (openPluginTiles.isNotEmpty) ...[
          kSettingsCardSpacing,
          SettingsCard(
            title: 'פתיחת תוספים',
            subtitle: 'קיצורים לפתיחה מהירה של תוסף מותקן',
            children: openPluginTiles,
          ),
        ],

        // ── העתקת קישורים (אופציונלי) — מוצג רק כשהוגדר קיצור אחד לפחות ──
        if (copyLinkTiles.isNotEmpty) ...[
          kSettingsCardSpacing,
          SettingsCard(
            title: 'העתקת קישורים',
            subtitle: 'קיצורים להעתקת קישור ישיר לספר, למקטע/לעמוד ולהדגשות',
            children: copyLinkTiles,
          ),
        ],

        // ── פעולות זמינות להגדרת קיצור ────────────────────────────────
        if (unconfiguredKeys.isNotEmpty) ...[
          kSettingsCardSpacing,
          SettingsCard(
            title: 'settings.shortcuts.available_section'.tr(),
            subtitle: 'settings.shortcuts.available_subtitle'.tr(),
            children: [
              SettingsActionTile.text(
                icon: FluentIcons.add_24_regular,
                title: 'settings.shortcuts.available_add_title'.tr(),
                subtitle: 'settings.shortcuts.available_count'.tr(
                    namedArgs: {'count': unconfiguredKeys.length.toString()}),
                actions: [
                  RecommendedActionButton(
                    text: 'settings.shortcuts.available_add_button'.tr(),
                    onPressed: () => _addShortcut(context, unconfiguredKeys),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// משאיר רק טיילים של קיצורים שכבר הוגדר להם ערך לא-ריק.
  /// קיצורים ללא ערך מוצגים תחת "פעולות זמינות לקיצור".
  List<Widget> _onlyConfigured(List<Widget> tiles) {
    return tiles.where((tile) {
      if (tile is _ShortcutTile) {
        final value = ShortcutValidator.getShortcutValue(tile.settingKey) ?? '';
        return value.isNotEmpty;
      }
      return true;
    }).toList();
  }

  Future<void> _addShortcut(
      BuildContext context, List<String> unconfiguredKeys) async {
    final settingsBloc = context.read<SettingsBloc>();

    final selectedKey = await showDialog<String>(
      context: context,
      builder: (_) => _PickActionDialog(actionKeys: unconfiguredKeys),
    );
    if (selectedKey == null || !context.mounted) return;

    final shortcut = await showDialog<String>(
      context: context,
      builder: (_) => CustomShortcutDialog(
        actionName: ShortcutValidator.shortcutNames[selectedKey],
      ),
    );
    if (shortcut == null || shortcut.isEmpty) return;

    // חישוב קונפליקטים *לפני* שליחת UpdateShortcut: הוא אסינכרוני (ה-bloc
    // עושה await על repository.updateShortcut), ולכן checkConflicts שירוץ
    // אחריו עלול לקרוא ערכים ישנים מ-Settings ולפספס כפילות.
    final conflictingNames = <String>[];
    for (final key in ShortcutValidator.shortcutKeys) {
      if (key == selectedKey) continue;
      if (ShortcutValidator.canShareShortcut(selectedKey, key)) continue;
      final existingValue = ShortcutValidator.getShortcutValue(key) ?? '';
      if (existingValue == shortcut) {
        conflictingNames.add(ShortcutValidator.shortcutNames[key] ?? key);
      }
    }

    if (conflictingNames.isNotEmpty) {
      UiSnack.showError(
        'settings.shortcuts.conflict_in_use'
            .tr(namedArgs: {'names': conflictingNames.join(', ')}),
      );
      return;
    }

    settingsBloc.add(UpdateShortcut(selectedKey, shortcut));
  }

  Future<void> _resetShortcuts(BuildContext context) async {
    final confirmed = await showWarningDialog(
      context: context,
      title: 'settings.shortcuts.reset_confirm_title'.tr(),
      content: 'settings.shortcuts.reset_confirm_content'.tr(),
      subtitle: 'settings.shortcuts.reset_confirm_subtitle'.tr(),
    );
    if (confirmed == true && context.mounted) {
      context.read<SettingsBloc>().add(ResetShortcuts());
      UiSnack.showSuccess('settings.shortcuts.reset_success'.tr());
    }
  }
}

// ── _ShortcutTile ─────────────────────────────────────────────────────────────
// פה מחקנו את כל עטיפות ה-Theme המסורבלות
class _ShortcutTile extends StatelessWidget {
  final String settingKey;
  final String label;
  final String? subtitle;
  final IconData icon;
  final Map<String, String> allShortcuts;

  const _ShortcutTile({
    required this.settingKey,
    required this.label,
    this.subtitle,
    required this.icon,
    required this.allShortcuts,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: DefaultTextStyle.of(context).style.merge(kSettingsTitleStyle),
      child: ShortcutDropDownTile(
        settingKey: settingKey,
        title: label,
        subtitle: subtitle,
        selected: ShortcutValidator.defaultShortcuts[settingKey] ?? '',
        allShortcuts: allShortcuts,
        leading: Icon(icon),
      ),
    );
  }
}

// ── _PickActionDialog ────────────────────────────────────────────────────────
/// דיאלוג לבחירת פעולה מתוך רשימת הפעולות הזמינות להגדרת קיצור.
/// מחזיר את ה-`settingKey` שנבחר ([ShortcutValidator.shortcutKeys]),
/// או null אם בוטל.
///
/// הקומפוננטות הקנוניות ב-`app_dialogs.dart` (SingleActionDialog וכו') בנויות
/// סביב כפתור confirm/cancel — לא מתאימות ל-picker שבו כל פריט הוא הפעולה
/// עצמה. במקום זאת אנחנו מיישרים קו עם אותו AlertDialog + צבעי המשטח
/// (`surfaceContainerHigh`) ואותם סגנונות לכפתורי הביטול (FilledButton.tonal).
class _PickActionDialog extends StatelessWidget {
  final List<String> actionKeys;

  const _PickActionDialog({required this.actionKeys});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      title: Text(
        'settings.shortcuts.pick_action_title'.tr(),
      ),
      content: SizedBox(
        width: 420,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: actionKeys.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final key = actionKeys[i];
            final name = ShortcutValidator.shortcutNames[key] ?? key;
            return ListTile(
              title: Text(name),
              trailing: const Icon(FluentIcons.chevron_right_24_regular),
              onTap: () => Navigator.of(context).pop(key),
            );
          },
        ),
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: cs.secondaryContainer,
            foregroundColor: cs.onSecondaryContainer,
          ),
          child: Text('common.cancel'.tr()),
        ),
      ],
    );
  }
}
