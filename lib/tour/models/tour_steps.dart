// לתחזוקת הסיור המודרך ראו: docs/guided_tour_developer_guide.md

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/tour/models/tour_step.dart';

class TourSteps {
  static const String statusKey = 'tour_status';
  static const String completed = 'completed';
  static const String skipped = 'skipped';
  static const String completedWithoutLibrary = 'completed_without_library';
  static const String skippedWithoutLibrary = 'skipped_without_library';

  static List<TourStep> build(
      {required bool libraryLoaded, bool isRestart = false}) {
    final shortcuts = _ShortcutText();
    final hiddenTools = _readHiddenBuiltInToolIds();
    final steps = <TourStep>[
      if (isRestart)
        TourStep(
          id: 'restart_welcome',
          title: 'tour.steps.restart_welcome_title'.tr(),
          body: libraryLoaded
              ? 'tour.steps.restart_welcome_body_loaded'.tr()
              : 'tour.steps.restart_welcome_body_empty'.tr(),
          area: TourSpotlightArea.center,
          isDialog: true,
        )
      else
        TourStep(
          id: 'welcome',
          title: 'tour.steps.welcome_title'.tr(),
          body: libraryLoaded
              ? 'tour.steps.welcome_body_loaded'.tr()
              : 'tour.steps.welcome_body_empty'.tr(),
          area: TourSpotlightArea.center,
          isDialog: true,
        ),
      TourStep(
        id: 'navigation',
        title: 'tour.steps.navigation_title'.tr(),
        body: 'tour.steps.navigation_body'
            .tr(namedArgs: {'shortcuts': shortcuts.mainNavigation}),
        area: TourSpotlightArea.navigation,
      ),
    ];

    if (libraryLoaded) {
      steps.addAll([
        TourStep(
          id: 'library',
          title: 'tour.steps.library_title'.tr(),
          body: 'tour.steps.library_body'.tr(),
          area: TourSpotlightArea.fullScreen,
          action: TourStepAction.openLibrary,
        ),
        TourStep(
          id: 'library_search',
          title: 'tour.steps.library_search_title'.tr(),
          body: 'tour.steps.library_search_body'.tr(),
          area: TourSpotlightArea.librarySearch,
          action: TourStepAction.openLibrary,
        ),
        TourStep(
          id: 'categories',
          title: 'tour.steps.categories_title'.tr(),
          body: 'tour.steps.categories_body'.tr(),
          area: TourSpotlightArea.libraryCategories,
          action: TourStepAction.openLibraryHome,
        ),
        TourStep(
          id: 'open_book',
          title: 'tour.steps.open_book_title'.tr(),
          body: 'tour.steps.open_book_body'.tr(),
          area: TourSpotlightArea.bookCard,
          action: TourStepAction.openLibraryBookPreview,
        ),
        TourStep(
          id: 'find_ref',
          title: 'tour.steps.find_ref_title'.tr(),
          body: 'tour.steps.find_ref_body'
              .tr(namedArgs: {'shortcut': shortcuts.findRef}),
          area: TourSpotlightArea.findRef,
          action: TourStepAction.openFindRef,
        ),
        TourStep(
          id: 'reading',
          title: 'tour.steps.reading_title'.tr(),
          body: 'tour.steps.reading_body'
              .tr(namedArgs: {'shortcut': shortcuts.reading}),
          area: TourSpotlightArea.reading,
          action: TourStepAction.openReading,
        ),
        TourStep(
          id: 'tabs',
          title: 'tour.steps.tabs_title'.tr(),
          body: 'tour.steps.tabs_body'.tr(),
          area: TourSpotlightArea.tabs,
          action: TourStepAction.openReading,
        ),
        TourStep(
          id: 'toc',
          title: 'tour.steps.toc_title'.tr(),
          body: 'tour.steps.toc_body'.tr(),
          area: TourSpotlightArea.tableOfContents,
          action: TourStepAction.openReading,
        ),
        TourStep(
          id: 'commentators',
          title: 'tour.steps.commentators_title'.tr(),
          body: 'tour.steps.commentators_body'.tr(),
          area: TourSpotlightArea.commentators,
          action: TourStepAction.openReading,
        ),
        TourStep(
          id: 'bookmark',
          title: 'tour.steps.bookmark_title'.tr(),
          body: 'tour.steps.bookmark_body'.tr(),
          area: TourSpotlightArea.bookmark,
          action: TourStepAction.openReading,
        ),
        TourStep(
          id: 'book_search',
          title: 'tour.steps.book_search_title'.tr(),
          body: 'tour.steps.book_search_body'.tr(),
          area: TourSpotlightArea.bookSearch,
          action: TourStepAction.openReading,
        ),
        TourStep(
          id: 'reading_settings',
          title: 'tour.steps.reading_settings_title'.tr(),
          body: 'tour.steps.reading_settings_body'.tr(),
          area: TourSpotlightArea.readingSettings,
          action: TourStepAction.openReading,
        ),
        TourStep(
          id: 'print',
          title: 'tour.steps.print_title'.tr(),
          body: 'tour.steps.print_body'.tr(),
          area: TourSpotlightArea.print,
          action: TourStepAction.openReading,
        ),
        TourStep(
          id: 'side_by_side',
          title: 'tour.steps.side_by_side_title'.tr(),
          body: 'tour.steps.side_by_side_body'.tr(),
          area: TourSpotlightArea.sideBySide,
          action: TourStepAction.openReading,
        ),
      ]);
    }

    steps.addAll([
      TourStep(
        id: 'advanced_search',
        title: 'tour.steps.advanced_search_title'.tr(),
        body: libraryLoaded
            ? 'tour.steps.advanced_search_body_loaded'
                .tr(namedArgs: {'shortcut': shortcuts.search})
            : 'tour.steps.advanced_search_body_empty'.tr(),
        area: TourSpotlightArea.searchDialog,
        action: TourStepAction.openSearch,
      ),
      TourStep(
        id: 'tools',
        title: 'tour.steps.tools_title'.tr(),
        body: 'tour.steps.tools_body'
            .tr(namedArgs: {'shortcut': shortcuts.tools}),
        area: TourSpotlightArea.tools,
        action: TourStepAction.openTools,
      ),
      if (!hiddenTools.contains('builtin.calendar'))
        TourStep(
          id: 'calendar',
          title: 'tour.steps.calendar_title'.tr(),
          body: 'tour.steps.calendar_body'.tr(),
          area: TourSpotlightArea.toolsTabs,
          action: TourStepAction.openTools,
        ),
      if (!hiddenTools.contains('builtin.gematria'))
        TourStep(
          id: 'gematria',
          title: 'tour.steps.gematria_title'.tr(),
          body: 'tour.steps.gematria_body'.tr(),
          area: TourSpotlightArea.toolsTabs,
          action: TourStepAction.openTools,
        ),
      if (!hiddenTools.contains('builtin.notes'))
        TourStep(
          id: 'notes',
          title: 'tour.steps.notes_title'.tr(),
          body: 'tour.steps.notes_body'.tr(),
          area: TourSpotlightArea.toolsTabs,
          action: TourStepAction.openTools,
        ),
      TourStep(
        id: 'settings',
        title: 'tour.steps.settings_title'.tr(),
        body: 'tour.steps.settings_body'
            .tr(namedArgs: {'shortcut': shortcuts.settings}),
        area: TourSpotlightArea.settings,
        action: TourStepAction.openSettings,
      ),
      TourStep(
        id: 'appearance',
        title: 'tour.steps.appearance_title'.tr(),
        body: 'tour.steps.appearance_body'.tr(),
        area: TourSpotlightArea.designSettings,
        action: TourStepAction.openDesignSettings,
      ),
      TourStep(
        id: 'backup',
        title: 'tour.steps.backup_title'.tr(),
        body: 'tour.steps.backup_body'.tr(),
        area: TourSpotlightArea.backupSettings,
        action: TourStepAction.openSystemSettings,
      ),
      TourStep(
        id: 'shortcuts',
        title: 'tour.steps.shortcuts_title'.tr(),
        body: 'tour.steps.shortcuts_body'
            .tr(namedArgs: {'table': shortcuts.shortcutTable}),
        area: TourSpotlightArea.shortcutsSettings,
        action: TourStepAction.openShortcutsSettings,
      ),
      TourStep(
        id: 'finish',
        title: libraryLoaded
            ? 'tour.steps.finish_title_loaded'.tr()
            : 'tour.steps.finish_title_empty'.tr(),
        body: libraryLoaded
            ? 'tour.steps.finish_body_loaded'.tr()
            : 'tour.steps.finish_body_empty'.tr(),
        area: TourSpotlightArea.center,
        action: TourStepAction.openLibrary,
        isDialog: true,
      ),
    ]);

    if (!libraryLoaded) {
      return [
        steps.first, // welcome / restart_welcome
        TourStep(
          id: 'empty_library',
          title: 'tour.steps.empty_library_title'.tr(),
          body: 'tour.steps.empty_library_body'.tr(),
          area: TourSpotlightArea.emptyLibrary,
          action: TourStepAction.openLibrary,
        ),
        ...steps.skip(1), // navigation, advanced_search, tools, ...
      ];
    }

    return steps;
  }

  static Set<String> _readHiddenBuiltInToolIds() {
    final raw = Settings.getValue<String>('key-hidden-builtin-tool-ids') ?? '';
    if (raw.isEmpty) return const <String>{};
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }
}

class _ShortcutText {
  String get mainNavigation => [
        '${'tour.steps.shortcut_label_library'.tr()} '
            '${_read('key-shortcut-open-library-browser', 'ctrl+l')}',
        '${'tour.steps.shortcut_label_find_ref'.tr()} '
            '${_read('key-shortcut-open-find-ref', 'ctrl+o')}',
        '${'tour.steps.shortcut_label_reading'.tr()} '
            '${_read('key-shortcut-open-reading-screen', 'ctrl+r')}',
        '${'tour.steps.shortcut_label_search'.tr()} '
            '${_read('key-shortcut-open-new-search', 'ctrl+shift+f')}',
        '${'tour.steps.shortcut_label_tools'.tr()} '
            '${_read('key-shortcut-open-more', 'ctrl+m')}',
        '${'tour.steps.shortcut_label_settings'.tr()} '
            '${_read('key-shortcut-open-settings', 'ctrl+comma')}',
      ].join(' · ');

  String get findRef => _read('key-shortcut-open-find-ref', 'ctrl+o');
  String get reading => _read('key-shortcut-open-reading-screen', 'ctrl+r');
  String get search => _read('key-shortcut-open-new-search', 'ctrl+shift+f');
  String get tools => _read('key-shortcut-open-more', 'ctrl+m');
  String get settings => _read('key-shortcut-open-settings', 'ctrl+comma');

  String get shortcutTable => [
        'tour.steps.shortcut_table_library'.tr(namedArgs: {
          'shortcut': _read('key-shortcut-open-library-browser', 'ctrl+l')
        }),
        'tour.steps.shortcut_table_find_ref'.tr(namedArgs: {
          'shortcut': _read('key-shortcut-open-find-ref', 'ctrl+o')
        }),
        'tour.steps.shortcut_table_reading'.tr(namedArgs: {
          'shortcut': _read('key-shortcut-open-reading-screen', 'ctrl+r')
        }),
        'tour.steps.shortcut_table_search'.tr(namedArgs: {
          'shortcut': _read('key-shortcut-open-new-search', 'ctrl+shift+f')
        }),
        'tour.steps.shortcut_table_next_tab'.tr(
            namedArgs: {'shortcut': _read('key-shortcut-next-tab', 'ctrl+tab')}),
        'tour.steps.shortcut_table_close_tab'.tr(
            namedArgs: {'shortcut': _read('key-shortcut-close-tab', 'ctrl+w')}),
      ].join('\n');

  String _read(String key, String defaultValue) {
    final value = Settings.getValue<String>(key) ?? defaultValue;
    return _format(value);
  }

  String _format(String shortcut) {
    return shortcut
        .split('+')
        .map((part) {
          if (part == 'ctrl') return 'Ctrl';
          if (part == 'shift') return 'Shift';
          if (part == 'alt') return 'Alt';
          if (part == 'comma') return ',';
          if (part == 'tab') return 'Tab';
          return part.isEmpty
              ? part
              : part[0].toUpperCase() + part.substring(1);
        })
        .join('+')
        .replaceAll('Ctrl+,', 'Ctrl+,');
  }
}
