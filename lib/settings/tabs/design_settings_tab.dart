import 'dart:io';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart'
    hide SwitchSettingsTile;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import 'package:otzaria/settings/dialogs/settings_dialogs_exports.dart';
import 'package:otzaria/settings/engine/settings_engine_exports.dart';
import 'package:otzaria/settings/search/settings_anchor.dart';
import 'package:otzaria/settings/search/settings_search_models.dart';
import 'package:otzaria/settings/services/per_book_settings_service.dart';
import 'package:otzaria/settings/widgets/settings_widgets_exports.dart';
import 'package:otzaria/settings/view/settings_screen.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/misc/rtl_icon.dart';
import 'package:otzaria/widgets/widgets_exports.dart';

enum _SidebarMode { pinned, openOnBook, closed }

enum _ThemeMode { light, system, dark }

/// טאב הגדרות עיצוב
class DesignSettingsTab extends StatelessWidget {
  const DesignSettingsTab({super.key});

  /// פריטים בעלי הגדרות לחיפוש בהגדרות. נסרק על-ידי
  /// tool/generate_search_index.dart בעת בנייה ומשולב באינדקס המאוחד.
  static const List<SettingsSearchEntry> searchEntries = [
    SettingsSearchEntry(
      id: 'design.display.fullscreen',
      title: 'מסך מלא',
      subtitle: 'החלף מצב מסך מלא',
      tab: SettingsTab.design,
      cardId: 'design.display',
      keywords: ['מסך מלא', 'fullscreen', 'מופעל', 'לא מופעל'],
    ),
    SettingsSearchEntry(
      id: 'design.theme.follow_system',
      title: 'מעקב אחר צבע המערכת',
      subtitle: 'התאמת ערכת הנושא לצבע מערכת ההפעלה',
      tab: SettingsTab.design,
      cardId: 'design.theme',
      keywords: ['ערכת נושא', 'מערכת', 'מופעל', 'לא מופעל'],
    ),
    SettingsSearchEntry(
      id: 'design.theme.dark_mode',
      title: 'מצב כהה',
      subtitle: 'מעבר בין מצב בהיר למצב כהה',
      tab: SettingsTab.design,
      cardId: 'design.theme',
      keywords: [
        'ערכת נושא',
        'בהיר',
        'אפל',
        'dark mode',
        'מופעל',
        'לא מופעל',
      ],
    ),
    SettingsSearchEntry(
      id: 'design.theme.seed_color',
      title: 'צבע בסיס',
      subtitle: 'צבע ראשי של ערכת הנושא',
      tab: SettingsTab.design,
      cardId: 'design.theme',
      keywords: ['צבע', 'ערכת נושא'],
    ),
    SettingsSearchEntry(
      id: 'design.pdf.book_view',
      title: 'תצוגת ספר בPDF',
      subtitle: 'פתיחת ספרי PDF בתצוגת ספר או רגילה',
      tab: SettingsTab.design,
      cardId: 'design.pdf',
      keywords: ['pdf', 'תצוגה', 'תצוגת ספר', 'רגילה', 'מופעל', 'לא מופעל'],
    ),
    SettingsSearchEntry(
      id: 'design.tabs.compact',
      title: 'תפריטים קומפקטיים',
      subtitle: 'צפיפות תפריטים בסגנון Chrome',
      tab: SettingsTab.design,
      cardId: 'design.tabs',
      keywords: [
        'קומפקטי',
        'צפוף',
        'chrome',
        'נוח',
        'מרווח',
        'מופעל',
        'לא מופעל',
      ],
    ),
    SettingsSearchEntry(
      id: 'design.layout.sidebar_mode',
      title: 'חלונית ניווט בין כותרות',
      subtitle: 'הצגה / אוטומטי / הסתרה של חלונית הניווט',
      tab: SettingsTab.design,
      cardId: 'design.layout',
      keywords: [
        'סייד-בר',
        'תפריט',
        'הצגה',
        'אוטומטי',
        'הסתרה',
        'קבוע',
        'גלילה',
      ],
    ),
    SettingsSearchEntry(
      id: 'design.layout.notes_collapsed',
      title: 'פתיחת הערות אישיות במצב סגור',
      subtitle: 'תצוגת רשימות הערות בפתיחה',
      tab: SettingsTab.design,
      cardId: 'design.layout',
      keywords: [
        'הערות',
        'אישיות',
        'סגורות',
        'פתוחות',
        'מופעל',
        'לא מופעל',
      ],
    ),
    SettingsSearchEntry(
      id: 'design.layout.split_view',
      title: 'הצגת המפרשים בחלונית בצד',
      subtitle: 'מפרשים בחלונית מפוצלת או בתוך הטקסט',
      tab: SettingsTab.design,
      cardId: 'design.layout',
      keywords: [
        'מפרשים',
        'מפוצל',
        'מפוצלת',
        'בתוך הטקסט',
        'מופעל',
        'לא מופעל',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return SingleChildScrollView(
          primary: true,
          padding: const EdgeInsets.all(16.0),
          child: ToolPanelWrapper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // מסך מלא (רק בדסקטופ)
                if (!(Platform.isAndroid || Platform.isIOS))
                  SettingsAnchor(
                    cardId: 'design.display',
                    child: SettingsCard(
                      title: 'settings.design.display_section'.tr(),
                      children: [
                        SwitchSettingsTile.text(
                          icon: state.isFullscreen
                              ? FluentIcons.full_screen_minimize_24_regular
                              : FluentIcons.full_screen_maximize_24_regular,
                          title: 'settings.design.fullscreen'.tr(),
                          subtitle: 'settings.design.fullscreen_subtitle'.tr(),
                          value: state.isFullscreen,
                          onChanged: (value) async {
                            context
                                .read<SettingsBloc>()
                                .add(UpdateIsFullscreen(value));
                            await windowManager.setFullScreen(value);
                          },
                        ),
                      ],
                    ),
                  ),

                if (!(Platform.isAndroid || Platform.isIOS))
                  kSettingsCardSpacing,

                // מצב כהה וצבע בסיס
                SettingsAnchor(
                  cardId: 'design.theme',
                  child: SettingsCard(
                    title: 'settings.design.theme_section'.tr(),
                    children: [
                      SegmentedSettingsTile<_ThemeMode>(
                        icon: const RtlIcon(
                            FluentIcons.weather_sunny_24_regular),
                        title: 'settings.design.theme_mode_title'.tr(),
                        subtitle: state.followSystemTheme
                            ? 'settings.design.theme_mode_system_subtitle'.tr()
                            : state.isDarkMode
                                ? 'settings.design.theme_mode_dark_subtitle'.tr()
                                : 'settings.design.theme_mode_light_subtitle'
                                    .tr(),
                        options: [
                          SegmentOption(
                              value: _ThemeMode.light,
                              label: 'settings.design.theme_mode_light'.tr()),
                          SegmentOption(
                              value: _ThemeMode.system,
                              label: 'settings.design.theme_mode_system'.tr()),
                          SegmentOption(
                              value: _ThemeMode.dark,
                              label: 'settings.design.theme_mode_dark'.tr()),
                        ],
                        currentValue: state.followSystemTheme
                            ? _ThemeMode.system
                            : state.isDarkMode
                                ? _ThemeMode.dark
                                : _ThemeMode.light,
                        onChanged: (mode) {
                          if (mode == _ThemeMode.system) {
                            context
                                .read<SettingsBloc>()
                                .add(UpdateFollowSystemTheme(true));
                          } else {
                            context
                                .read<SettingsBloc>()
                                .add(UpdateFollowSystemTheme(false));
                            context
                                .read<SettingsBloc>()
                                .add(UpdateDarkMode(mode == _ThemeMode.dark));
                          }
                        },
                      ),
                      ColorPickerTile(
                        key: ValueKey(
                            'color-picker-${Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light'}'),
                        currentColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? state.darkSeedColor
                                : state.seedColor,
                        defaultColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? AppSeedColors.defaultDark
                                : AppSeedColors.defaultLight,
                        onChanged: (color) {
                          if (Theme.of(context).brightness == Brightness.dark) {
                            context
                                .read<SettingsBloc>()
                                .add(UpdateDarkSeedColor(color));
                          } else {
                            context
                                .read<SettingsBloc>()
                                .add(UpdateSeedColor(color));
                          }
                        },
                      ),
                    ],
                  ),
                ),

                kSettingsCardSpacing,

                SettingsAnchor(
                  cardId: 'design.pdf',
                  child: SettingsCard(
                    title: 'settings.design.pdf_section'.tr(),
                    children: [
                      SwitchSettingsTile.text(
                        icon: FluentIcons.book_open_24_regular,
                        title: 'settings.design.pdf_book_view'.tr(),
                        subtitle: state.enablePerBookSettings
                            ? state.pdfBookViewByDefault
                                ? 'settings.design.pdf_book_view_only_book'.tr()
                                : 'settings.design.pdf_book_view_only_normal'
                                    .tr()
                            : state.pdfBookViewByDefault
                                ? 'settings.design.pdf_book_view_all_book'.tr()
                                : 'settings.design.pdf_book_view_all_normal'
                                    .tr(),
                        value: state.pdfBookViewByDefault,
                        onChanged: (value) {
                          context
                              .read<SettingsBloc>()
                              .add(UpdatePdfBookViewByDefault(value));
                        },
                      ),
                    ],
                  ),
                ),

                kSettingsCardSpacing,

                // הגדרות טאבים
                SettingsAnchor(
                  cardId: 'design.tabs',
                  child: SettingsCard(
                    title: 'settings.design.interface_section'.tr(),
                    children: [
                      if (!(Platform.isAndroid || Platform.isIOS))
                        SegmentedSettingsTile<bool>(
                          icon: const RtlIcon(
                              FluentIcons.column_triple_24_regular),
                          title: 'settings.design.interface_density'.tr(),
                          subtitle: state.compactMenuMode
                              ? 'settings.design.interface_density_compact'.tr()
                              : 'settings.design.interface_density_wide'.tr(),
                          options: [
                            SegmentOption(
                                value: false,
                                label: 'settings.design.density_wide'.tr()),
                            SegmentOption(
                                value: true,
                                label: 'settings.design.density_compact'.tr()),
                          ],
                          currentValue: state.compactMenuMode,
                          onChanged: (value) {
                            context
                                .read<SettingsBloc>()
                                .add(UpdateCompactMenuMode(value));
                          },
                        ),
                    ],
                  ),
                ),

                kSettingsCardSpacing,

                // התנהגות סרגל צד
                SettingsAnchor(
                  cardId: 'design.layout',
                  child: SettingsCard(
                    title: 'settings.design.sidebar_section'.tr(),
                    children: [
                      SegmentedSettingsTile<_SidebarMode>(
                        title: 'settings.design.sidebar_nav'.tr(),
                        subtitle: state.pinSidebar
                            ? 'settings.design.sidebar_pinned_subtitle'.tr()
                            : state.defaultSidebarOpen
                                ? 'settings.design.sidebar_open_on_book_subtitle'
                                    .tr()
                                : 'settings.design.sidebar_closed_subtitle'
                                    .tr(),
                        icon: const RtlIcon(
                            FluentIcons.panel_left_24_regular),
                        options: [
                          SegmentOption(
                              value: _SidebarMode.pinned,
                              label: 'settings.design.sidebar_show'.tr()),
                          SegmentOption(
                              value: _SidebarMode.openOnBook,
                              label: 'settings.design.sidebar_auto'.tr()),
                          SegmentOption(
                              value: _SidebarMode.closed,
                              label: 'settings.design.sidebar_hide'.tr()),
                        ],
                        currentValue: state.pinSidebar
                            ? _SidebarMode.pinned
                            : state.defaultSidebarOpen
                                ? _SidebarMode.openOnBook
                                : _SidebarMode.closed,
                        onChanged: (mode) {
                          if (mode == _SidebarMode.pinned) {
                            context
                                .read<SettingsBloc>()
                                .add(UpdatePinSidebar(true));
                            context
                                .read<SettingsBloc>()
                                .add(const UpdateDefaultSidebarOpen(true));
                          } else if (mode == _SidebarMode.openOnBook) {
                            context
                                .read<SettingsBloc>()
                                .add(UpdatePinSidebar(false));
                            context
                                .read<SettingsBloc>()
                                .add(const UpdateDefaultSidebarOpen(true));
                          } else {
                            context
                                .read<SettingsBloc>()
                                .add(UpdatePinSidebar(false));
                            context
                                .read<SettingsBloc>()
                                .add(const UpdateDefaultSidebarOpen(false));
                          }
                        },
                      ),
                      SwitchSettingsTile.text(
                        title:
                            'settings.design.personal_notes_collapsed'.tr(),
                        subtitle: state.personalNotesCollapsedByDefault
                            ? 'settings.design.personal_notes_collapsed_on'.tr()
                            : 'settings.design.personal_notes_collapsed_off'
                                .tr(),
                        value: state.personalNotesCollapsedByDefault,
                        onChanged: (value) {
                          context.read<SettingsBloc>().add(
                              UpdatePersonalNotesCollapsedByDefault(value));
                        },
                      ),
                      StatefulBuilder(
                        builder: (context, setState) {
                          final splitedView =
                              Settings.getValue<bool>('key-splited-view') ??
                                  true;
                          return SwitchSettingsTile.text(
                            title: 'settings.design.split_view'.tr(),
                            subtitle: splitedView
                                ? 'settings.design.split_view_on'.tr()
                                : 'settings.design.split_view_off'.tr(),
                            value: splitedView,
                            onChanged: (value) {
                              setState(() {
                                Settings.setValue<bool>(
                                    'key-splited-view', value);
                                final settingsBloc =
                                    context.read<SettingsBloc>();
                                PerBookSettings.cleanupRedundantSettings(
                                  defaultFontSize: settingsBloc.state.fontSize,
                                  defaultRemoveNikud:
                                      settingsBloc.state.defaultRemoveNikud,
                                  defaultShowSplitView: value,
                                );
                              });
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
