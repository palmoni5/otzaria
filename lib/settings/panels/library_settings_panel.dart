import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/external_catalog/view/external_catalog_settings_helper.dart';
import 'package:otzaria/settings/engine/settings_engine_exports.dart';
import 'package:otzaria/settings/search/settings_search_models.dart';
import 'package:otzaria/settings/widgets/settings_widgets_exports.dart';
import 'package:otzaria/settings/view/settings_screen.dart';
import 'package:otzaria/widgets/widgets_exports.dart';

/// פאנל הגדרות תצוגת ספרייה
class LibrarySettingsPanel extends StatelessWidget {
  /// ווידג'ט להצגת מיקום ספרי היברובוקס (מועבר מהטאב הראשי כדי לתמוך בבחירת תיקייה)
  final Widget? hebrewBooksPathWidget;

  const LibrarySettingsPanel({super.key, this.hebrewBooksPathWidget});

  /// פריטי חיפוש בהגדרות. נסרק על-ידי tool/generate_search_index.dart.
  static const List<SettingsSearchEntry> searchEntries = [
    SettingsSearchEntry(
      id: 'library.display.view_type',
      title: 'settings.search.library_display_view_type_title',
      subtitle: 'settings.search.library_display_view_type_sub',
      tab: SettingsTab.library,
      cardId: 'library.display',
      keywords: ['settings.search.library_display_view_type_kw'],
    ),
    SettingsSearchEntry(
      id: 'library.display.preview',
      title: 'settings.search.library_display_preview_title',
      subtitle: 'settings.search.library_display_preview_sub',
      tab: SettingsTab.library,
      cardId: 'library.display',
      keywords: ['settings.search.library_display_preview_kw'],
    ),
    SettingsSearchEntry(
      id: 'library.external.show',
      title: 'settings.search.library_external_show_title',
      subtitle: 'settings.search.library_external_show_sub',
      tab: SettingsTab.library,
      cardId: 'library.display',
      keywords: ['settings.search.library_external_show_kw'],
    ),
    SettingsSearchEntry(
      id: 'library.external.otzar',
      title: 'settings.search.library_external_otzar_title',
      subtitle: 'settings.search.library_external_otzar_sub',
      tab: SettingsTab.library,
      cardId: 'library.display',
      keywords: ['settings.search.library_external_otzar_kw'],
    ),
    SettingsSearchEntry(
      id: 'library.external.hebrewbooks',
      title: 'settings.search.library_external_hebrewbooks_title',
      subtitle: 'settings.search.library_external_hebrewbooks_sub',
      tab: SettingsTab.library,
      cardId: 'library.display',
      keywords: ['settings.search.library_external_hebrewbooks_kw'],
    ),
    SettingsSearchEntry(
      id: 'library.external.auto_sync',
      title: 'settings.search.library_external_auto_sync_title',
      subtitle: 'settings.search.library_external_auto_sync_sub',
      tab: SettingsTab.library,
      cardId: 'library.display',
      keywords: ['settings.search.library_external_auto_sync_kw'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // הגדרות תצוגה
            SettingsCard(
              title: 'settings.library.view_section'.tr(),
              children: [
                SegmentedSettingsTile<String>(
                  icon: const Icon(FluentIcons.grid_24_regular),
                  title: 'settings.library.view_mode_title'.tr(),
                  subtitle: state.libraryViewMode == 'list'
                      ? 'settings.library.view_mode_list_subtitle'.tr()
                      : 'settings.library.view_mode_grid_subtitle'.tr(),
                  options: [
                    SegmentOption(
                      value: 'grid',
                      label: 'settings.library.view_grid'.tr(),
                      icon: FluentIcons.grid_24_regular,
                    ),
                    SegmentOption(
                      value: 'list',
                      label: 'settings.library.view_list'.tr(),
                      icon: FluentIcons.list_24_regular,
                    ),
                  ],
                  currentValue: state.libraryViewMode,
                  onChanged: (value) {
                    context
                        .read<SettingsBloc>()
                        .add(UpdateLibraryViewMode(value));
                  },
                ),
                SwitchSettingsTile.text(
                  icon: FluentIcons.eye_24_regular,
                  title: 'settings.library.show_preview_title'.tr(),
                  subtitle: state.libraryShowPreview
                      ? 'settings.library.show_preview_on'.tr()
                      : 'settings.library.show_preview_off'.tr(),
                  value: state.libraryShowPreview,
                  onChanged: (value) {
                    context
                        .read<SettingsBloc>()
                        .add(UpdateLibraryShowPreview(value));
                  },
                ),
              ],
            ),

            kSettingsCardSpacing,

            // ספרים נוספים (משלב מיקום היברובוקס וספרים חיצוניים)
            SettingsCard(
              title: 'settings.library.additional_section'.tr(),
              children: [
                // מיקום היברובוקס (יוצג ראשון במידה והועבר לו ווידג'ט - דסקטופ בלבד)
                if (hebrewBooksPathWidget != null) hebrewBooksPathWidget!,

                SwitchSettingsTile.text(
                  icon: FluentIcons.globe_24_regular,
                  title: 'settings.library.external_books_title'.tr(),
                  subtitle: state.showExternalBooks
                      ? 'settings.library.external_books_on'.tr()
                      : 'settings.library.external_books_off'.tr(),
                  value: state.showExternalBooks,
                  onChanged: (value) async {
                    await ExternalCatalogSettingsHelper.updateExternalBooks(
                      context,
                      value,
                    );
                  },
                ),
                if (state.showExternalBooks) ...[
                  SwitchSettingsTile.text(
                    icon: FluentIcons.library_24_regular,
                    title: 'settings.library.otzar_title'.tr(),
                    subtitle: 'settings.library.otzar_subtitle'.tr(),
                    value: state.showOtzarHachochma,
                    onChanged: (value) async {
                      await ExternalCatalogSettingsHelper.updateOtzarBooks(
                        context,
                        value,
                      );
                    },
                  ),
                  SwitchSettingsTile.text(
                    icon: FluentIcons.book_open_24_regular,
                    title: 'settings.library.hebrew_books_external_title'.tr(),
                    subtitle:
                        'settings.library.hebrew_books_external_subtitle'.tr(),
                    value: state.showHebrewBooks,
                    onChanged: (value) async {
                      await ExternalCatalogSettingsHelper.updateHebrewBooks(
                        context,
                        value,
                      );
                    },
                  ),
                  SwitchSettingsTile.text(
                    icon: FluentIcons.arrow_sync_24_regular,
                    title: 'settings.library.auto_sync_title'.tr(),
                    subtitle: 'settings.library.auto_sync_subtitle'.tr(),
                    value: state.autoSyncCatalogs,
                    onChanged: (value) {
                      context
                          .read<SettingsBloc>()
                          .add(UpdateAutoSyncCatalogs(value));
                    },
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}
