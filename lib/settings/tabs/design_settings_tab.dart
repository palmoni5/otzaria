import 'dart:io';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart'
    hide SwitchSettingsTile;
import 'package:flutter_bloc/flutter_bloc.dart';
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
      id: 'design.theme.follow_system',
      title: 'settings.design.follow_system_color',
      subtitle: 'settings.search.design_theme_follow_system_sub',
      tab: SettingsTab.design,
      cardId: 'design.theme',
      keywords: ['settings.search.design_theme_follow_system_kw'],
    ),
    SettingsSearchEntry(
      id: 'design.theme.dark_mode',
      title: 'settings.design.dark_mode',
      subtitle: 'settings.search.design_theme_dark_mode_sub',
      tab: SettingsTab.design,
      cardId: 'design.theme',
      keywords: ['settings.search.design_theme_dark_mode_kw'],
    ),
    SettingsSearchEntry(
      id: 'design.theme.seed_color',
      title: 'settings.design.base_color',
      subtitle: 'settings.search.design_theme_seed_color_sub',
      tab: SettingsTab.design,
      cardId: 'design.theme',
      keywords: ['settings.search.design_theme_seed_color_kw'],
    ),
    SettingsSearchEntry(
      id: 'design.pdf.book_view',
      title: 'settings.design.pdf_book_view',
      subtitle: 'settings.search.design_pdf_book_view_sub',
      tab: SettingsTab.design,
      cardId: 'design.pdf',
      keywords: ['settings.search.design_pdf_book_view_kw'],
    ),
    SettingsSearchEntry(
      id: 'design.tabs.compact',
      title: 'settings.design.compact_menus',
      subtitle: 'settings.search.design_tabs_compact_sub',
      tab: SettingsTab.design,
      cardId: 'design.tabs',
      keywords: ['settings.search.design_tabs_compact_kw'],
    ),
    SettingsSearchEntry(
      id: 'design.layout.sidebar_mode',
      title: 'settings.design.sidebar_nav',
      subtitle: 'settings.search.design_layout_sidebar_mode_sub',
      tab: SettingsTab.design,
      cardId: 'design.layout',
      keywords: ['settings.search.design_layout_sidebar_mode_kw'],
    ),
    SettingsSearchEntry(
      id: 'design.layout.commentary_open',
      title: 'settings.design.commentary_open_on_book',
      subtitle: 'settings.search.design_layout_commentary_open_sub',
      tab: SettingsTab.design,
      cardId: 'design.layout',
      keywords: ['settings.search.design_layout_commentary_open_kw'],
    ),
    SettingsSearchEntry(
      id: 'design.layout.notes_collapsed',
      title: 'settings.design.personal_notes_collapsed',
      subtitle: 'settings.search.design_layout_notes_collapsed_sub',
      tab: SettingsTab.design,
      cardId: 'design.layout',
      keywords: ['settings.search.design_layout_notes_collapsed_kw'],
    ),
    SettingsSearchEntry(
      id: 'design.layout.split_view',
      title: 'settings.design.split_view',
      subtitle: 'settings.search.design_layout_split_view_sub',
      tab: SettingsTab.design,
      cardId: 'design.layout',
      keywords: ['settings.search.design_layout_split_view_kw'],
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
                        icon: FluentIcons.panel_right_24_regular,
                        title: 'settings.design.commentary_open_on_book'.tr(),
                        subtitle: state.defaultCommentaryOpen
                            ? 'settings.design.commentary_open_on_book_on'.tr()
                            : 'settings.design.commentary_open_on_book_off'
                                .tr(),
                        value: state.defaultCommentaryOpen,
                        onChanged: (value) {
                          context
                              .read<SettingsBloc>()
                              .add(UpdateDefaultCommentaryOpen(value));
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
