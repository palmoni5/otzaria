import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart'
    hide SwitchSettingsTile;
import 'package:otzaria/settings/search/settings_anchor.dart';
import 'package:otzaria/settings/search/settings_search_models.dart';
import 'package:otzaria/settings/widgets/settings_widgets_exports.dart';
import 'package:otzaria/settings/view/settings_screen.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';
import 'package:otzaria/widgets/widgets_exports.dart';

/// טאב הגדרות גימטריה
class GematriaSettingsTab extends StatefulWidget {
  const GematriaSettingsTab({super.key});

  /// פריטי חיפוש בהגדרות. נסרק על-ידי tool/generate_search_index.dart.
  static const List<SettingsSearchEntry> searchEntries = [
    SettingsSearchEntry(
      id: 'tools.gematria.max_results',
      title: 'מספר תוצאות מקסימלי',
      subtitle: 'כמות התוצאות המקסימלית להצגה',
      tab: SettingsTab.tools,
      cardId: 'tools.gematria',
      keywords: ['גימטריה', 'תוצאות', 'מספר', 'מקסימום'],
    ),
    SettingsSearchEntry(
      id: 'tools.gematria.filter_duplicates',
      title: 'סינון כפולים',
      subtitle: 'הסר תוצאות כפולות',
      tab: SettingsTab.tools,
      cardId: 'tools.gematria',
      keywords: ['גימטריה', 'כפולים', 'סינון', 'מופעל', 'לא מופעל'],
    ),
    SettingsSearchEntry(
      id: 'tools.gematria.whole_verse',
      title: 'פסוק שלם',
      subtitle: 'חיפוש רק בפסוקים שלמים',
      tab: SettingsTab.tools,
      cardId: 'tools.gematria',
      keywords: ['גימטריה', 'פסוק', 'מופעל', 'לא מופעל'],
    ),
    SettingsSearchEntry(
      id: 'tools.gematria.torah_only',
      title: 'תורה בלבד',
      subtitle: 'חיפוש רק בחמישה חומשי תורה',
      tab: SettingsTab.tools,
      cardId: 'tools.gematria',
      keywords: ['גימטריה', 'תורה', 'חומש', 'מופעל', 'לא מופעל'],
    ),
    SettingsSearchEntry(
      id: 'tools.gematria.small',
      title: 'גימטריה קטנה',
      subtitle: 'כל אות מחושבת לפי ספרה אחת',
      tab: SettingsTab.tools,
      cardId: 'tools.gematria',
      keywords: ['גימטריה קטנה', 'מקטנת', 'מופעל', 'לא מופעל'],
    ),
    SettingsSearchEntry(
      id: 'tools.gematria.final_letters',
      title: 'אותיות סופיות',
      subtitle: 'מנצפ"ך בערכים שונים',
      tab: SettingsTab.tools,
      cardId: 'tools.gematria',
      keywords: [
        'גימטריה',
        'מנצפך',
        'סופיות',
        'אותיות',
        'מופעל',
        'לא מופעל',
      ],
    ),
    SettingsSearchEntry(
      id: 'tools.gematria.kolel',
      title: 'עם הכולל',
      subtitle: 'הוספת מספר האותיות לסכום',
      tab: SettingsTab.tools,
      cardId: 'tools.gematria',
      keywords: ['גימטריה', 'כולל', 'עם הכולל', 'מופעל', 'לא מופעל'],
    ),
    SettingsSearchEntry(
      id: 'tools.gematria.method',
      title: 'שיטת חישוב גימטריה',
      subtitle: 'שיטת חישוב המשמשת בכלי הגימטריה',
      tab: SettingsTab.tools,
      cardId: 'tools.gematria',
      keywords: [
        'גימטריה',
        'חישוב',
        'קטנה',
        'אותיות סופיות',
        'כולל',
      ],
    ),
  ];

  @override
  State<GematriaSettingsTab> createState() => _GematriaSettingsTabState();
}

class _GematriaSettingsTabState extends State<GematriaSettingsTab> {
  late int maxResults;
  late bool filterDuplicates;
  late bool wholeVerseOnly;
  late bool torahOnly;
  late bool useSmallGematria;
  late bool useFinalLetters;
  late bool useWithKolel;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    maxResults = Settings.getValue<int>('key-gematria-max-results') ?? 100;
    filterDuplicates =
        Settings.getValue<bool>('key-gematria-filter-duplicates') ?? false;
    wholeVerseOnly =
        Settings.getValue<bool>('key-gematria-whole-verse-only') ?? false;
    torahOnly = Settings.getValue<bool>('key-gematria-torah-only') ?? false;
    useSmallGematria =
        Settings.getValue<bool>('key-gematria-use-small') ?? false;
    useFinalLetters =
        Settings.getValue<bool>('key-gematria-use-final-letters') ?? false;
    useWithKolel =
        Settings.getValue<bool>('key-gematria-use-with-kolel') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsAnchor(
          cardId: 'tools.gematria',
          child: SettingsCard(
            title: 'settings.gematria.search_section'.tr(),
            children: [
              DropdownSettingsTile<int>(
                icon: const Icon(FluentIcons.number_row_24_regular),
                title: 'settings.gematria.max_results_title'.tr(),
                subtitle: 'settings.gematria.max_results_subtitle'.tr(),
                value: maxResults,
                minFieldWidth: 120,
                maxFieldWidth: 160,
                entries: [50, 100, 200, 500, 1000]
                    .map((value) => AppMenuEntry(value: value, label: '$value'))
                    .toList(),
                onSelected: (value) {
                  if (value != null) {
                    setState(() => maxResults = value);
                    Settings.setValue<int>('key-gematria-max-results', value);
                  }
                },
              ),
              SwitchSettingsTile.text(
                icon: FluentIcons.filter_24_regular,
                title: 'settings.gematria.filter_duplicates_title'.tr(),
                subtitle: filterDuplicates
                    ? 'settings.gematria.filter_duplicates_on'.tr()
                    : 'settings.gematria.filter_duplicates_off'.tr(),
                value: filterDuplicates,
                onChanged: (value) {
                  setState(() => filterDuplicates = value);
                  Settings.setValue<bool>(
                      'key-gematria-filter-duplicates', filterDuplicates);
                },
              ),
              SwitchSettingsTile.text(
                icon: FluentIcons.text_word_count_24_regular,
                title: 'settings.gematria.whole_verse_title'.tr(),
                subtitle: wholeVerseOnly
                    ? 'settings.gematria.whole_verse_on'.tr()
                    : 'settings.gematria.whole_verse_off'.tr(),
                value: wholeVerseOnly,
                onChanged: (value) {
                  setState(() => wholeVerseOnly = value);
                  Settings.setValue<bool>(
                      'key-gematria-whole-verse-only', wholeVerseOnly);
                },
              ),
              SwitchSettingsTile.text(
                icon: FluentIcons.book_24_regular,
                title: 'settings.gematria.torah_only_title'.tr(),
                subtitle: torahOnly
                    ? 'settings.gematria.torah_only_on'.tr()
                    : 'settings.gematria.torah_only_off'.tr(),
                value: torahOnly,
                onChanged: (value) {
                  setState(() => torahOnly = value);
                  Settings.setValue<bool>('key-gematria-torah-only', torahOnly);
                },
              ),
            ],
          ),
        ),
        kSettingsCardSpacing,
        SettingsCard(
          title: 'settings.gematria.method_section'.tr(),
          children: [
            SwitchSettingsTile.text(
              icon: FluentIcons.number_symbol_24_regular,
              title: 'settings.gematria.small_title'.tr(),
              subtitle: 'settings.gematria.small_subtitle'.tr(),
              value: useSmallGematria,
              onChanged: (value) {
                setState(() {
                  useSmallGematria = value;
                  if (useSmallGematria) {
                    useFinalLetters = false;
                    Settings.setValue<bool>(
                        'key-gematria-use-final-letters', false);
                  }
                });
                Settings.setValue<bool>(
                    'key-gematria-use-small', useSmallGematria);
              },
            ),
            SwitchSettingsTile.text(
              icon: FluentIcons.text_font_24_regular,
              title: 'settings.gematria.final_letters_title'.tr(),
              subtitle: 'settings.gematria.final_letters_subtitle'.tr(),
              value: useFinalLetters,
              onChanged: (value) {
                setState(() {
                  useFinalLetters = value;
                  if (useFinalLetters) {
                    useSmallGematria = false;
                    Settings.setValue<bool>('key-gematria-use-small', false);
                  }
                });
                Settings.setValue<bool>(
                    'key-gematria-use-final-letters', useFinalLetters);
              },
            ),
            SwitchSettingsTile.text(
              icon: FluentIcons.add_circle_24_regular,
              title: 'settings.gematria.kolel_title'.tr(),
              subtitle: 'settings.gematria.kolel_subtitle'.tr(),
              value: useWithKolel,
              onChanged: (value) {
                setState(() => useWithKolel = value);
                Settings.setValue<bool>(
                    'key-gematria-use-with-kolel', useWithKolel);
              },
            ),
          ],
        ),
      ],
    );
  }
}
